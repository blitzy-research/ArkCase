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

import org.junit.Assume;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.springframework.mock.web.MockServletContext;
import org.springframework.web.context.support.ServletContextResourcePatternResolver;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Coverage for the copy that carries the assembled front-end from the staging folder into the deployment folder that
 * the servlet container serves.
 * <p>
 * Every assertion here corresponds to a defect that reached a running deployment while the class's other tests passed,
 * which is the reason this class exercises the real filesystem rather than asserting on the arguments a copy would have
 * been given:
 * <ul>
 * <li>The package manager creates a symbolic link for every executable dependency, under {@code node_modules/.bin},
 * and {@code node_modules} is one of the folders configured for the deployment copy. A copy that refuses to follow a
 * link and has no other handling for one therefore failed the entire assembly on every install.</li>
 * <li>An enumeration that follows a directory link walks out of the staging folder, and whatever it finds is written
 * into a folder served over HTTP.</li>
 * <li>Both stale sweeps end in a delete, so the same enumeration decides what is eligible for deletion.</li>
 * <li>A copy that opens its destination before its source shortens a good file when the source cannot be read.</li>
 * </ul>
 */
public class AngularResourceCopierDeploymentCopyTest
{
    @Rule
    public TemporaryFolder temporaryFolder = new TemporaryFolder();

    private AngularResourceCopier copier;

    private File staging;

    private File deployment;

    @Before
    public void setUp() throws Exception
    {
        copier = new AngularResourceCopier();
        staging = temporaryFolder.newFolder("staging");
        deployment = temporaryFolder.newFolder("deployment");
        copier.setTempFolderPath(staging.getPath());
        copier.setDeployFolderPath(deployment.getPath());
    }

    /**
     * The defect that stopped every deployment: {@code npm ci} creates one symbolic link per executable dependency and
     * the copy has to carry them. This builds the same shape the package manager builds - a package with a real script
     * and a relative link to it from {@code .bin} - and requires the copy to complete and the link to arrive as a link
     * pointing at the same relative text.
     */
    @Test
    public void reproducesThePackageManagersBinSymbolicLinks() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        File real = new File(staging, "node_modules/grunt-cli/bin/grunt");
        write(real, "#!/usr/bin/env node\n");
        link(new File(staging, "node_modules/.bin/grunt"), Paths.get("../grunt-cli/bin/grunt"));

        copier.copyWebappResources(staging, deployment, "node_modules");

        Path deployedLink = new File(deployment, "node_modules/.bin/grunt").toPath();
        Path deployedTarget = new File(deployment, "node_modules/grunt-cli/bin/grunt").toPath();

        assertTrue("the ordinary file must be copied", Files.isRegularFile(deployedTarget, LinkOption.NOFOLLOW_LINKS));
        assertTrue("the .bin entry must arrive as a symbolic link, not as a second copy",
                Files.isSymbolicLink(deployedLink));
        assertEquals("the link must keep its own relative text so it resolves inside the deployment folder",
                Paths.get("../grunt-cli/bin/grunt"), Files.readSymbolicLink(deployedLink));
        assertTrue("the reproduced link must resolve to the deployed file",
                deployedLink.toRealPath().equals(deployedTarget.toRealPath()));
        assertEquals("#!/usr/bin/env node\n", read(deployedTarget.toFile()));
    }

    /**
     * The stale sweep that runs immediately after the copy must not delete the links the copy has just created. It
     * compares the paths it walks against the paths the copy recorded, and a link's canonical path is its target's, so
     * recording only canonical paths made every link a deletion candidate the moment it was created.
     */
    @Test
    public void keepsTheReproducedLinksThroughTheStaleSweep() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        write(new File(staging, "node_modules/acorn/bin/acorn"), "acorn\n");
        link(new File(staging, "node_modules/.bin/acorn"), Paths.get("../acorn/bin/acorn"));

        copier.copyWebappResources(staging, deployment, "node_modules");
        // A second run is the case that matters: the sweep of the first run has already happened, and the second must
        // recognise the link as its own rather than as something left behind.
        copier.copyWebappResources(staging, deployment, "node_modules");

        assertTrue("the link must survive the sweep",
                Files.isSymbolicLink(new File(deployment, "node_modules/.bin/acorn").toPath()));
    }

    /**
     * A directory link planted in the staging folder must not be able to publish anything through it. The whole chain
     * is asserted, because the chain is what made this serious: enumeration follows the link, the copy writes what it
     * finds into the deployment folder, and the container serves that folder without authentication.
     */
    @Test
    public void refusesToPublishThroughADirectorySymbolicLink() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        File outside = temporaryFolder.newFolder("outside-the-staging-folder");
        write(new File(outside, "deep/host-file.txt"), "this file is not part of the front-end build\n");

        write(new File(staging, "lib/json8/package.json"), "{}\n");
        link(new File(staging, "lib/escape-dir"), outside.toPath());

        copier.copyWebappResources(staging, deployment, "lib");

        assertTrue("content that really is inside the staging folder must still be copied",
                new File(deployment, "lib/json8/package.json").isFile());
        assertFalse("the link itself must not be reproduced, because it leaves the tree",
                Files.exists(new File(deployment, "lib/escape-dir").toPath(), LinkOption.NOFOLLOW_LINKS));
        assertFalse("nothing reachable through the link may be written under the deployment folder",
                new File(deployment, "lib/deep/host-file.txt").exists());
        assertFalse("and it may not be written at the target's own absolute path either",
                new File(deployment, "lib" + outside.getPath()).exists());
        assertTrue("the file outside the tree must be left alone", new File(outside, "deep/host-file.txt").isFile());
    }

    /**
     * A file link that leaves the tree is refused for the same reason, and it is refused rather than followed: a copy
     * that followed it would place host content in the deployment folder just as effectively as a directory link.
     */
    @Test
    public void refusesToPublishThroughAFileSymbolicLink() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        File outside = temporaryFolder.newFolder("outside-file-target");
        File secret = new File(outside, "host-secret.txt");
        write(secret, "not front-end content\n");

        write(new File(staging, "lib/pointer/package.json"), "{}\n");
        link(new File(staging, "lib/escape-file"), secret.toPath());

        copier.copyWebappResources(staging, deployment, "lib");

        assertTrue("the genuine file must still be copied", new File(deployment, "lib/pointer/package.json").isFile());
        assertFalse("the escaping link must not be deployed in any form",
                Files.exists(new File(deployment, "lib/escape-file").toPath(), LinkOption.NOFOLLOW_LINKS));
    }

    /**
     * A link whose target does not exist has no content to deploy and must not produce a dangling link in a folder the
     * container serves. It must also not abort the assembly, which is what a walk that followed links did when it met
     * one.
     */
    @Test
    public void skipsADanglingSymbolicLinkWithoutFailingTheAssembly() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        write(new File(staging, "lib/text-sequence/package.json"), "{}\n");
        link(new File(staging, "lib/dangling"), Paths.get("no-such-target"));

        copier.copyWebappResources(staging, deployment, "lib");

        assertTrue("the genuine file must still be copied",
                new File(deployment, "lib/text-sequence/package.json").isFile());
        assertFalse("a dangling link must not be deployed",
                Files.exists(new File(deployment, "lib/dangling").toPath(), LinkOption.NOFOLLOW_LINKS));
    }

    /**
     * The stale sweep ends in a delete, so the enumeration that feeds it decides what may be deleted. A directory link
     * planted in the deployment folder must not put host files on that list.
     */
    @Test
    public void theStaleSweepDoesNotDeleteThroughADirectorySymbolicLink() throws Exception
    {
        Assume.assumeTrue("symbolic links are required for this assertion", symbolicLinksSupported());

        File outside = temporaryFolder.newFolder("outside-the-deployment-folder");
        File hostFile = new File(outside, "host-file-the-sweep-must-not-delete.txt");
        write(hostFile, "still here\n");

        write(new File(staging, "assets/dist/application.js"), "application\n");
        File deployedFolder = new File(deployment, "assets");
        assertTrue(deployedFolder.mkdirs());
        link(new File(deployedFolder, "escape-dir"), outside.toPath());

        copier.copyWebappResources(staging, deployment, "assets");

        assertTrue("the assembled file must be deployed", new File(deployment, "assets/dist/application.js").isFile());
        assertTrue("the sweep must not delete a file outside the folder it is sweeping", hostFile.isFile());
        assertEquals("still here\n", read(hostFile));
    }

    /**
     * A stale file that really is inside the deployment folder must still be swept, so the confinement above cannot be
     * satisfied by sweeping nothing.
     */
    @Test
    public void theStaleSweepStillRemovesFilesInsideTheFolder() throws Exception
    {
        write(new File(staging, "assets/dist/application.js"), "application\n");
        File stale = new File(deployment, "assets/dist/left-over-from-a-previous-build.js");
        write(stale, "stale\n");

        copier.copyWebappResources(staging, deployment, "assets");

        assertTrue("the assembled file must be deployed", new File(deployment, "assets/dist/application.js").isFile());
        assertFalse("a stale file inside the folder must be removed", stale.exists());
    }

    /**
     * An assembled folder that is missing means the front-end build did not finish. The copy must say so rather than
     * deploy a tree with a folder silently absent from it.
     */
    @Test
    public void refusesToDeployWhenAnAssembledFolderIsMissing() throws Exception
    {
        try
        {
            copier.copyWebappResources(staging, deployment, "node_modules");
            fail("a missing assembled folder must fail the assembly");
        }
        catch (IOException expected)
        {
            assertTrue("the message must name the folder: " + expected.getMessage(),
                    expected.getMessage().contains("node_modules"));
        }
    }

    /**
     * The lockfile is the file this matters for. The stale sweep deliberately keeps it between runs, so a copy that
     * truncated it before discovering the source was unreadable left a zero-length lockfile in place, and the install
     * then failed on the next start for a second reason that looked unrelated to the first.
     */
    @Test
    public void anUnreadableSourceLeavesTheExistingStagingFileIntact() throws Exception
    {
        File archive = temporaryFolder.newFolder("war-resources");
        File resources = new File(archive, "resources");
        assertTrue(resources.mkdirs());
        write(new File(resources, "package.json"), "{ \"name\": \"arkcase\" }\n");

        ServletContextResourcePatternResolver resolver = new ServletContextResourcePatternResolver(
                new MockServletContext("file:" + archive.getAbsolutePath()));

        // A good copy first, so that there is something to lose.
        copier.copyFile(resolver, staging, "package.json");
        assertEquals("{ \"name\": \"arkcase\" }\n", read(new File(staging, "package.json")));

        File good = new File(staging, "package-lock.json");
        write(good, "{ \"lockfileVersion\": 3 }\n");
        long lengthBefore = good.length();

        try
        {
            // package-lock.json is deliberately absent from the archive, which is exactly the condition that arises
            // when the deployment copy of it has been removed.
            copier.copyFile(resolver, staging, "package-lock.json");
            fail("an unreadable source must be reported");
        }
        catch (IOException expected)
        {
            assertTrue("the failure must name the file: " + expected.getMessage(),
                    expected.getMessage().contains("package-lock.json"));
        }

        assertTrue("the previously good file must still exist", good.isFile());
        assertEquals("it must not have been truncated", lengthBefore, good.length());
        assertEquals("and its content must be unchanged", "{ \"lockfileVersion\": 3 }\n", read(good));
        assertFalse("no half-written staging file may be left behind",
                new File(staging, "package-lock.json.arkcase-incoming").exists());
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

    /**
     * Create a symbolic link, establishing its parent directory first, exactly as the package manager does when it
     * populates {@code node_modules/.bin}.
     */
    private void link(File linkFile, Path linkText) throws IOException
    {
        Files.createDirectories(linkFile.getParentFile().toPath());
        Files.createSymbolicLink(linkFile.toPath(), linkText);
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
}
