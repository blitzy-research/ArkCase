package com.armedia.acm.userinterface.angular;

/*-
 * #%L
 * ACM User Interface: ArkCase Angular Starter
 * %%
 * Copyright (C) 2014 - 2018 ArkCase LLC
 * %%
 * This file is part of the ArkCase software.
 *
 * If the software was purchased under a paid ArkCase license, the terms of
 * the paid license agreement will prevail.  Otherwise, the software is
 * provided under the following open source license terms:
 *
 * ArkCase is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * ArkCase is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with ArkCase. If not, see <http://www.gnu.org/licenses/>.
 * #L%
 */

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.PumpStreamHandler;
import org.junit.Assume;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.attribute.PosixFilePermission;
import java.util.Map;
import java.util.Set;

/**
 * Coverage for the filesystem and launcher trust boundary of the startup frontend build.
 * <p>
 * The staging folder is configured, long lived and shared with everything else running as the server user, and the
 * assembly writes into it from resource names carried in the WAR and in extension jars. Each test here pins one of the
 * properties that makes that safe: the folder is validated rather than assumed, nothing that changes what an install
 * does survives in it, a resource name cannot make a copy land outside the folder, a planted symbolic link cannot
 * redirect a write, and an install is refused outright unless the runtime is the major version the committed lockfile
 * was produced with.
 */
public class AngularResourceCopierSafetyTest
{
    @Rule
    public TemporaryFolder temporaryFolder = new TemporaryFolder();

    private AngularResourceCopier copier;

    @Before
    public void setUp()
    {
        copier = new AngularResourceCopier();
    }

    @Test
    public void createsTheStagingFolderWhenItIsMissing() throws Exception
    {
        File staging = new File(temporaryFolder.getRoot(), "nested/staging");
        copier.setTempFolderPath(staging.getPath());

        File created = copier.cleanAndCreateResourceTempFolder();

        assertTrue("the staging folder must be created", created.isDirectory());
        assertEquals(staging.getCanonicalPath(), created.getCanonicalPath());
    }

    @Test
    public void createsTheStagingFolderOwnerOnly() throws Exception
    {
        Assume.assumeTrue("permissions are only asserted where the file system expresses them",
                Files.getFileStore(temporaryFolder.getRoot().toPath()).supportsFileAttributeView("posix"));

        File staging = new File(temporaryFolder.getRoot(), "owner-only-staging");
        copier.setTempFolderPath(staging.getPath());

        Set<PosixFilePermission> permissions = Files
                .getPosixFilePermissions(copier.cleanAndCreateResourceTempFolder().toPath());

        assertFalse("the staging folder must not be group readable", permissions.contains(PosixFilePermission.GROUP_READ));
        assertFalse("the staging folder must not be group writable",
                permissions.contains(PosixFilePermission.GROUP_WRITE));
        assertFalse("the staging folder must not be world readable",
                permissions.contains(PosixFilePermission.OTHERS_READ));
        assertFalse("the staging folder must not be world writable",
                permissions.contains(PosixFilePermission.OTHERS_WRITE));
    }

    /**
     * A staging folder that has been replaced by a symbolic link must be refused, because following it would place the
     * whole assembly - and every file the deployment then serves - somewhere the operator did not configure.
     */
    @Test
    public void refusesAStagingFolderThatIsASymbolicLink() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        File elsewhere = temporaryFolder.newFolder("elsewhere");
        Path link = temporaryFolder.getRoot().toPath().resolve("redirected-staging");
        Files.createSymbolicLink(link, elsewhere.toPath());

        copier.setTempFolderPath(link.toString());

        try
        {
            copier.cleanAndCreateResourceTempFolder();
            fail("a staging folder that is a symbolic link must be refused");
        }
        catch (IOException expected)
        {
            assertTrue("the message must say why", expected.getMessage().contains("symbolic link"));
        }
    }

    /**
     * An intermediate folder inside the tree that has been replaced by a symbolic link pointing outside it must not be
     * able to carry a copy out of the tree. This is the case the containment check exists for, and it is checked on
     * canonical paths precisely so that it sees through the link rather than around it.
     */
    @Test
    public void refusesACopyThroughAnIntermediateSymbolicLinkThatLeavesTheTree() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        File source = temporaryFolder.newFolder("intermediate-source");
        File target = temporaryFolder.newFolder("intermediate-target");
        File elsewhere = temporaryFolder.newFolder("intermediate-elsewhere");

        write(new File(source, "assets/app.js"), "// content\n");
        Files.createSymbolicLink(new File(target, "assets").toPath(), elsewhere.toPath());

        try
        {
            copier.copyWebappFile(source, target, "assets/app.js");
            fail("a copy that leaves the tree through a symbolic link must be refused");
        }
        catch (IOException expected)
        {
            assertTrue("the message must say why", expected.getMessage().contains("resolves outside"));
            assertFalse("nothing may have been written outside the tree", new File(elsewhere, "app.js").exists());
        }
    }

    /**
     * A folder created explicitly must be a real directory afterwards, and creating it must not have followed a
     * symbolic link standing where that folder should be.
     */
    @Test
    public void refusesToCreateAFolderThatIsAlreadyASymbolicLink() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        File root = temporaryFolder.newFolder("create-root");
        File elsewhere = temporaryFolder.newFolder("create-elsewhere");
        Files.createSymbolicLink(new File(root, "dist").toPath(), elsewhere.toPath());

        try
        {
            copier.createFolderStructure(new File(root, "dist"));
            fail("a folder that is a symbolic link must be refused");
        }
        catch (IOException expected)
        {
            assertTrue("the message must say why", expected.getMessage().contains("symbolic link"));
        }
    }

    /**
     * A staging folder reached through a symbolic link an operator placed deliberately - an ArkCase home on another
     * volume, for instance - must still work. Refusing that would break a valid deployment for no gain, because
     * containment is proven against canonical paths and every write refuses to follow a link.
     */
    @Test
    public void acceptsAStagingFolderBelowASymbolicallyLinkedAncestor() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        File elsewhere = temporaryFolder.newFolder("linked-home");
        Path link = temporaryFolder.getRoot().toPath().resolve("home-link");
        Files.createSymbolicLink(link, elsewhere.toPath());

        copier.setTempFolderPath(link.resolve("arkcase/tmp").toString());

        File created = copier.cleanAndCreateResourceTempFolder();

        assertTrue("the staging folder must be created below the linked ancestor", created.isDirectory());
        assertEquals(new File(elsewhere, "arkcase/tmp").getCanonicalPath(), created.getCanonicalPath());
    }

    @Test
    public void removesPackageManagerConfigurationFromTheStagingFolder() throws Exception
    {
        File staging = temporaryFolder.newFolder("staging-with-config");
        write(new File(staging, ".npmrc"), "registry=https://example.invalid/\n");
        write(new File(staging, "npm-shrinkwrap.json"), "{}\n");
        write(new File(staging, ".yarnrc"), "registry \"https://example.invalid/\"\n");
        write(new File(staging, "package.json"), "{}\n");

        copier.setTempFolderPath(staging.getPath());
        copier.cleanAndCreateResourceTempFolder();

        assertFalse("an npm run-control file must not survive", new File(staging, ".npmrc").exists());
        assertFalse("a shrinkwrap must not survive, it would take precedence over the lockfile",
                new File(staging, "npm-shrinkwrap.json").exists());
        assertFalse("a yarn run-control file must not survive", new File(staging, ".yarnrc").exists());
        assertTrue("the application's own manifest must be left alone", new File(staging, "package.json").exists());
    }

    /**
     * A resource name carried in a WAR or an extension jar is external input. One that walks upwards must not be able
     * to place a copy outside the staging folder.
     */
    @Test
    public void refusesAResourceThatResolvesOutsideTheStagingFolder() throws Exception
    {
        File staging = temporaryFolder.newFolder("contained-staging");
        copier.setTempFolderPath(staging.getPath());

        try
        {
            copier.copyWebappFile(staging, staging, "../escaped.txt");
            fail("a target that resolves outside the folder must be refused");
        }
        catch (IOException expected)
        {
            assertTrue("the message must say why", expected.getMessage().contains("resolves outside"));
        }
    }

    /**
     * A symbolic link planted in the staging folder between two assemblies must not be able to redirect a write onto
     * the file it points at.
     */
    @Test
    public void refusesToWriteThroughASymbolicLink() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        File source = temporaryFolder.newFolder("link-source");
        File target = temporaryFolder.newFolder("link-target");
        write(new File(source, "config.js"), "// the real content\n");

        File sensitive = new File(temporaryFolder.getRoot(), "sensitive.txt");
        write(sensitive, "must not be overwritten\n");
        Files.createSymbolicLink(new File(target, "config.js").toPath(), sensitive.toPath());

        try
        {
            copier.copyWebappFile(source, target, "config.js");
            fail("writing through a symbolic link must be refused");
        }
        catch (IOException expected)
        {
            assertEquals("the linked file must be untouched", "must not be overwritten\n", read(sensitive));
        }
    }

    @Test
    public void refusesToRunTheBuildOnTheWrongNodeMajorVersion() throws Exception
    {
        Assume.assumeTrue("an executable stub launcher is required for this assertion", symbolicLinksSupported());

        copier.setNodeExecutablePath(stubLauncher("node", "v18.20.4").getPath());
        copier.setNpmExecutablePath(stubLauncher("npm", "10.8.2").getPath());

        try
        {
            copier.verifyFrontEndRuntime();
            fail("the wrong Node.js major version must be refused");
        }
        catch (IOException expected)
        {
            assertTrue("the message must name the required major version", expected.getMessage().contains("node 20"));
        }
    }

    @Test
    public void refusesToRunTheBuildOnTheWrongNpmMajorVersion() throws Exception
    {
        Assume.assumeTrue("an executable stub launcher is required for this assertion", symbolicLinksSupported());

        copier.setNodeExecutablePath(stubLauncher("node", "v20.20.2").getPath());
        copier.setNpmExecutablePath(stubLauncher("npm", "9.9.4").getPath());

        try
        {
            copier.verifyFrontEndRuntime();
            fail("the wrong npm major version must be refused");
        }
        catch (IOException expected)
        {
            assertTrue("the message must name the required major version", expected.getMessage().contains("npm 10"));
        }
    }

    @Test
    public void acceptsTheRequiredMajorVersions() throws Exception
    {
        Assume.assumeTrue("an executable stub launcher is required for this assertion", symbolicLinksSupported());

        copier.setNodeExecutablePath(stubLauncher("node", "v20.20.2").getPath());
        copier.setNpmExecutablePath(stubLauncher("npm", "10.8.2").getPath());

        copier.verifyFrontEndRuntime();
    }

    /**
     * Resolving the launchers to absolute files does not by itself decide which Node.js executes them, because npm and
     * Grunt are Node.js scripts started through the interpreter named on their first line, and that name is resolved
     * against the child process path. The environment handed to the build tools must therefore carry the verified
     * launcher's own directory first, or the runtime that was checked is not the runtime that runs.
     */
    @Test
    public void putsTheVerifiedInterpreterFirstOnThePathOfTheBuildTools() throws Exception
    {
        Assume.assumeTrue("an executable stub launcher is required for this assertion", symbolicLinksSupported());

        File node = stubLauncher("node", "v20.20.2");
        File tmpDir = temporaryFolder.newFolder("staging");

        copier.setNodeExecutablePath(node.getPath());

        String path = copier.buildToolEnvironment(tmpDir).get("PATH");
        String pinned = node.getCanonicalFile().getParentFile().getPath();

        assertTrue("the verified interpreter's directory must be on the path, and first: " + path,
                path != null && path.startsWith(pinned));
        assertTrue("the inherited path must be kept behind it, not discarded",
                path.equals(pinned) || path.startsWith(pinned + File.pathSeparator));
    }

    /**
     * The same guarantee, observed from inside a child process rather than read off a map: a launcher started by the
     * copier must find the verified interpreter under the bare name {@code node}, which is the name its interpreter
     * line uses.
     */
    @Test
    public void aLaunchedToolResolvesTheBareInterpreterNameToTheVerifiedOne() throws Exception
    {
        Assume.assumeTrue("a POSIX shell stub is required for this assertion",
                File.separatorChar == '/' && symbolicLinksSupported());

        File node = stubLauncher("node", "v20.20.2");
        File tmpDir = temporaryFolder.newFolder("staging-launched");
        File resolved = new File(tmpDir, "resolved-interpreter.txt");
        File reporter = new File(temporaryFolder.newFolder("reporter-stub"), "npm");

        write(reporter, "#!/bin/sh\ncommand -v node > \"$1\"\n");
        Assume.assumeTrue("the stub launcher must be executable for this assertion",
                reporter.setExecutable(true, true));

        copier.setNodeExecutablePath(node.getPath());
        copier.runFrontEndBuildCommand(tmpDir, reporter.getPath() + " " + resolved.getPath());

        assertTrue("the launched tool must have reported the interpreter it resolved", resolved.isFile());
        assertEquals("the bare name must resolve to the verified interpreter",
                node.getCanonicalPath(), new File(read(resolved).trim()).getCanonicalPath());
    }

    /**
     * The version check is a security control, so it must not be possible to neutralise it by configuring away the
     * version it checks for.
     */
    @Test
    public void refusesAVersionRequirementThatWouldDisableTheCheck() throws Exception
    {
        copier.setRequiredNodeMajorVersion(0);

        try
        {
            copier.verifyFrontEndRuntime();
            fail("a non-positive required version must be refused");
        }
        catch (IOException expected)
        {
            assertTrue("the message must name the property",
                    expected.getMessage().contains("requiredNodeMajorVersion"));
        }
    }

    /**
     * The environment handed to the package manager has to be one the package manager accepts, and that cannot be
     * established by reading the map back. It was not: the two configuration-file settings were given the same path, and
     * npm refuses to load one file twice, so it aborted before resolving any configuration at all and every install
     * failed with exit status 1 on every host. The map's contents were correct throughout.
     * <p>
     * This test therefore runs the real package manager with the real environment and requires it to answer. It is
     * skipped where the toolchain is absent rather than passing vacuously.
     */
    @Test
    public void theRealPackageManagerAcceptsTheEnvironmentItIsGiven() throws Exception
    {
        File tmpDir = temporaryFolder.newFolder("staging-real-npm");
        File npm = launcherOnPath("npm");
        File node = launcherOnPath("node");

        Assume.assumeTrue("node and npm must be on the path for this assertion", npm != null && node != null);

        Map<String, String> environment = copier.buildToolEnvironment(tmpDir);

        assertFalse("the user and global configuration files must not be the same path, because npm refuses to load "
                + "one file twice and aborts before reading any configuration",
                environment.get("npm_config_userconfig").equals(environment.get("npm_config_globalconfig")));

        CommandLine command = new CommandLine(npm);
        command.addArgument("--version", false);

        ByteArrayOutputStream captured = new ByteArrayOutputStream();
        DefaultExecutor executor = new DefaultExecutor();
        executor.setWorkingDirectory(tmpDir);
        executor.setStreamHandler(new PumpStreamHandler(captured, captured));

        int exitCode = executor.execute(command, environment);
        String reported = new String(captured.toByteArray(), StandardCharsets.UTF_8).trim();

        assertEquals("the package manager must run to completion with this environment; it reported: " + reported, 0,
                exitCode);
        assertTrue("it must have reported a version rather than a configuration error: " + reported,
                reported.matches("(?s)^\\d+\\.\\d+.*"));
    }

    /**
     * A command that fails has to explain itself. Its output used to go only to a DEBUG logger while the process library
     * reported the failure by throwing, so on a failed install an operator saw the exit status and nothing else - and
     * raising a log level is not a remedy, because the shipped log configuration pins this logger above DEBUG. The
     * output is asserted on the thrown message for that reason: that is the path that reaches the container log and the
     * error page whatever the configured level is.
     */
    @Test
    public void aFailedCommandCarriesItsOwnOutputIntoTheFailure() throws Exception
    {
        Assume.assumeTrue("a POSIX shell stub is required for this assertion", File.separatorChar == '/');

        File node = stubLauncher("node", "v20.20.2");
        File tmpDir = temporaryFolder.newFolder("staging-failing-command");
        File failing = new File(temporaryFolder.newFolder("failing-stub"), "npm");

        write(failing, "#!/bin/sh\necho 'npm error code EUSAGE'\necho 'npm error The `npm ci` command can only install "
                + "with an existing package-lock.json'\nexit 1\n");
        Assume.assumeTrue("the stub launcher must be executable for this assertion", failing.setExecutable(true, true));

        copier.setNodeExecutablePath(node.getPath());

        try
        {
            copier.runFrontEndBuildCommand(tmpDir, failing.getPath() + " ci");
            fail("a command that exits non-zero must be reported");
        }
        catch (IOException expected)
        {
            String message = expected.getMessage();

            assertTrue("the failure must name the command: " + message, message.contains(failing.getPath()));
            assertTrue("the failure must carry the tool's own output: " + message,
                    message.contains("npm error code EUSAGE"));
            assertTrue("including the explanatory line: " + message,
                    message.contains("can only install with an existing package-lock.json"));
        }
    }

    /**
     * Resolve one launcher from the process path, or {@code null} when it is not there. Used to skip the assertions that
     * need the real toolchain rather than to weaken them.
     */
    private File launcherOnPath(String name)
    {
        String path = System.getenv("PATH");

        if (path == null)
        {
            return null;
        }

        for (String element : path.split(File.pathSeparator))
        {
            File candidate = new File(element, name);

            if (candidate.isFile() && candidate.canExecute())
            {
                return candidate;
            }
        }

        return null;
    }

    private File stubLauncher(String name, String version) throws IOException
    {
        File launcher = new File(temporaryFolder.newFolder(name + "-stub"), name);

        write(launcher, "#!/bin/sh\nprintf '%s\\n' '" + version + "'\n");

        if (!launcher.setExecutable(true, true))
        {
            Assume.assumeTrue("the stub launcher must be executable for this assertion", false);
        }

        return launcher;
    }

    private boolean symbolicLinksSupported()
    {
        try
        {
            Path probeTarget = temporaryFolder.getRoot().toPath().resolve("symlink-probe-target");
            Files.createDirectories(probeTarget);
            Path probeLink = temporaryFolder.getRoot().toPath().resolve("symlink-probe-link");
            Files.createSymbolicLink(probeLink, probeTarget);
            boolean created = Files.isSymbolicLink(probeLink);
            Files.deleteIfExists(probeLink);
            return created;
        }
        catch (IOException | UnsupportedOperationException e)
        {
            return false;
        }
    }

    private void write(File target, String content) throws IOException
    {
        Files.createDirectories(target.getParentFile().toPath());
        Files.write(target.toPath(), content.getBytes(StandardCharsets.UTF_8));
    }

    private String read(File target) throws IOException
    {
        return new String(Files.readAllBytes(target.toPath()), StandardCharsets.UTF_8);
    }

    /**
     * Guards against the containment check being satisfied by a link rather than by the path: the target must be
     * inspected without following links.
     */
    @Test
    public void containmentIsCheckedWithoutFollowingLinks() throws Exception
    {
        File staging = temporaryFolder.newFolder("nofollow-staging");
        File file = new File(staging, "present.txt");
        write(file, "content\n");

        assertTrue("a plain file inside the folder must be seen as itself",
                Files.isRegularFile(file.toPath(), LinkOption.NOFOLLOW_LINKS));
    }
}
