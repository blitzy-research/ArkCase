package com.armedia.acm.userinterface.angular;

/*-
 * #%L
 * ACM UI: Ark Angular Starter
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

import com.armedia.acm.core.AcmSpringActiveProfile;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.environment.EnvironmentUtils;
import org.apache.commons.exec.PumpStreamHandler;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.io.filefilter.FileFilterUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.web.context.ServletContextAware;
import org.springframework.web.context.support.ServletContextResourcePatternResolver;
import org.zeroturnaround.exec.stream.slf4j.Slf4jDebugOutputStream;

import javax.servlet.ServletContext;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.OutputStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.PosixFilePermission;
import java.nio.file.attribute.PosixFilePermissions;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Copy all angular resources from the base ArkCase WAR file and also from any ArkCase extension jars, run the
 * Angular front-end build tools, and copy the assembled application into the deployment folder.
 * <p>
 * The ArkCase WAR file should configure the deployment folder in a Tomcat context resources element, such that
 * files in this deployment folder are treated as if they were in the root folder of the war file itself.
 * <p>
 * Node.js and npm (the Node.js Package Manager) must be installed on the deployment host, and npm must be in the
 * system path.
 * <p>
 * The resources to be copied from the war file and extension jars; the front-end commands to be run (e.g. npm,
 * grunt); and the resources to be copied to the deployment folder are configured in Spring. All resources to
 * be copied from the war file and extension jars must be within a top-level resources folder.
 */
public class AngularResourceCopier implements ServletContextAware
{
    /**
     * Package-manager configuration files that are removed from the staging folder before the package manager runs.
     * <p>
     * None of them is ever copied out of the WAR or an extension jar, so their presence means something else put them
     * there. Each one changes what an install does rather than what it installs from: the npm and Yarn run-control
     * files redirect the registry, the proxy, the certificate authority and whether lifecycle scripts run, and a
     * shrinkwrap silently takes precedence over the committed lockfile. Removing them makes the install depend on the
     * lockfile and on the configuration set below, and on nothing that happens to be lying in the folder.
     */
    private static final List<String> PACKAGE_MANAGER_CONFIG_FILES = Collections.unmodifiableList(Arrays.asList(
            ".npmrc", "npmrc", ".yarnrc", ".yarnrc.yml", "npm-shrinkwrap.json", ".pnpmfile.cjs", ".pnpmfile.js"));

    /** Matches the leading major version in {@code v20.20.2} and in {@code 10.8.2} alike. */
    private static final Pattern VERSION_MAJOR = Pattern.compile("^v?(\\d+)\\.");

    /** Owner-only directory permissions for the staging and deployment folders, where the platform supports them. */
    private static final Set<PosixFilePermission> OWNER_ONLY_DIRECTORY = PosixFilePermissions.fromString("rwx------");

    private transient final Logger log = LoggerFactory.getLogger(getClass());

    /**
     * Absolute path of the Node.js launcher, or blank to resolve it from the process path once and log the result.
     * Configuring it is the stronger posture, because it removes the ambient path from the trust boundary entirely.
     */
    private String nodeExecutablePath = "";

    /**
     * Absolute path of the npm launcher, or blank to resolve it from the process path once and log the result.
     */
    private String npmExecutablePath = "";

    /**
     * Major Node.js version this build requires. The frontend manifest constrains the runtime to a single major, and
     * that constraint is only advisory to npm, so it is enforced here before an install is allowed to start. A value
     * of zero or less is rejected rather than treated as "no check", so the constraint cannot be switched off by
     * accident.
     */
    private int requiredNodeMajorVersion = 20;

    /** Major npm version this build requires; enforced exactly as {@link #requiredNodeMajorVersion} is. */
    private int requiredNpmMajorVersion = 10;

    /**
     * Registry the package manager must install from. Set explicitly so that the install cannot be redirected by
     * configuration this class does not control.
     */
    private String npmRegistry = "https://registry.npmjs.org/";

    private String tempFolderPath;
    private String deployFolderPath;
    private String mergeConfigFrontendTask;
    private String yarnInstallCommand;
    private String gruntDefaultCommand;
    private List<String> resourceFoldersToCopyFromArchive;
    private List<String> assembledFoldersToCopyToDeployment;
    private List<String> filesToCopyFromArchive;
    private List<String> assembledFilesToCopyToDeployment;
    private List<String> frontEndCommandsToBeExecuted;
    private List<String> customResourceSourcesToCopyFromArchive;
    private AcmSpringActiveProfile springActiveProfile;

    @Override
    public void setServletContext(ServletContext servletContext)
    {
        copyAngularResources(servletContext);
    }

    public void copyAngularResources(ServletContext servletContext)
    {
        try
        {
            File tmpDir = cleanAndCreateResourceTempFolder();

            ServletContextResourcePatternResolver resolver = new ServletContextResourcePatternResolver(servletContext);

            Resource modulesRoot = resolver.getResource(AngularResourceConstants.WAR_ANGULAR_RESOURCE_PATH);
            log.debug("modulesRoot: [{}]", modulesRoot);
            String rootPath = modulesRoot.getFile().getCanonicalPath();
            String libFolderPath = tmpDir.getCanonicalPath() + File.separator + "lib";
            log.info("lib folder path: {}", libFolderPath);

            List<String> copiedFiles = new ArrayList<>();

            for (String resourceFolder : getResourceFoldersToCopyFromArchive())
            {
                List<String> copied = copyResources(resolver, rootPath, tmpDir, resourceFolder);
                copiedFiles.addAll(copied);
            }

            for (String resourceFile : getFilesToCopyFromArchive())
            {
                String copied = copyFile(resolver, tmpDir, resourceFile);
                copiedFiles.add(copied);
            }

            // Remove everything left over from a previous assembly BEFORE the package manager runs, not after.
            // The staging folder outlives a restart, so anything stale in it - including a file a previous
            // dependency's install script created - is content the package manager would otherwise read first. The
            // outputs this deletes are all regenerated further down by the same commands that produced them.
            removeStaleFilesFromTempFolder(tmpDir, libFolderPath, copiedFiles);

            // The manifests are in place and nothing stale is left, so the runtime can be checked and the install
            // run. The check comes first: an install performed by the wrong Node.js or npm major version is not a
            // reproducible install, and the manifest's engine constraint alone does not stop one.
            verifyFrontEndRuntime();

            // npm ci
            runFrontEndBuildCommand(tmpDir, yarnInstallCommand);
            // add 'customer' as specific profile, so if any customer resources are present will come
            // on top of core and extension resources

            List<String> activeProfiles = springActiveProfile.getExtensionActiveProfile()
                    .map(it -> Arrays.asList(it, "custom"))
                    .orElse(Collections.singletonList("custom"));

            copiedFiles.add(createProfilesJsFileInDir(activeProfiles, tmpDir));

            for (String profile : activeProfiles)
            {
                copyFilesAndExecuteCommands(profile, resolver, rootPath, tmpDir, copiedFiles);
            }

            runFrontEndBuildCommand(tmpDir, gruntDefaultCommand);

            File deployFolder = new File(getDeployFolderPath());
            createFolderStructure(deployFolder);

            for (String assembledFolder : getAssembledFoldersToCopyToDeployment())
            {
                copyWebappResources(tmpDir, deployFolder, assembledFolder);
            }
            for (String assembledFile : getAssembledFilesToCopyToDeployment())
            {
                copyWebappFile(tmpDir, deployFolder, assembledFile);
            }

        }
        catch (IOException e)
        {
            log.error("Could not copy Angular resources", e);
            // make sure the webapp does not start... if it did start it wouldn't work right. So better to make sure
            // it doesn't deploy.
            throw new RuntimeException("Could not assemble Angular webapp: " + e.getMessage(), e);
        }
    }

    private void copyFilesAndExecuteCommands(String profile, ServletContextResourcePatternResolver resolver, String rootPath,
            File tmpDir, List<String> copiedFiles)
            throws IOException
    {

        log.debug("Copy resources for specific profile [{}]", profile);
        for (String folder : customResourceSourcesToCopyFromArchive)
        {
            String moduleRoot = String.format("%s_%s", profile, folder);
            copiedFiles.addAll(copyResources(resolver, rootPath, tmpDir, moduleRoot, folder));
        }
        runFrontEndBuildCommand(tmpDir, mergeConfigFrontendTask);
    }

    private String createProfilesJsFileInDir(List<String> profiles, File parentDir) throws IOException
    {
        String exportProfiles = String.format("module.exports = %s", profiles.stream()
                .map(it -> String.format("'%s'", it))
                .collect(Collectors.joining(", ", "{ profiles: [ ", " ] };")));
        File target = assertWithin(parentDir, new File(parentDir, "profiles.js"));

        try (OutputStream out = newNoFollowOutputStream(target))
        {
            IOUtils.copy(IOUtils.toInputStream(exportProfiles, StandardCharsets.UTF_8), out);
        }

        target.setLastModified(new Date().getTime());
        return target.getCanonicalPath();
    }

    /**
     * Delete every file in the staging folder that this assembly did not put there, so that the package manager and
     * the build tools read only content this run produced.
     * <p>
     * The exceptions are the artefacts the package manager and Grunt own themselves and which must survive between
     * runs for the incremental assembly to work at all: the installed dependency trees, the vendored library folder
     * and the committed lockfile.
     *
     * @param tmpDir
     *            the staging folder.
     * @param libFolderPath
     *            canonical path of the vendored library folder inside the staging folder.
     * @param copiedFiles
     *            canonical paths this run has copied in so far.
     * @throws IOException
     *             if the staging folder cannot be listed.
     */
    private void removeStaleFilesFromTempFolder(File tmpDir, String libFolderPath, List<String> copiedFiles)
            throws IOException
    {
        List<String> tmpFilesFound = findAllFilesInFolder(tmpDir);

        log.debug("Found {} files in tmp folder", tmpFilesFound.size());

        // delete all files that exist in the tmp dir, but we didn't copy them there; such files must have been
        // removed from the project. Exceptions are files managed by npm and grunt: lib folder, node_modules
        // folder, bower_components folder, package-lock.json
        List<File> oldFilesInTmpFolder = tmpFilesFound.stream()
                .filter(p -> !p.contains("node_modules"))
                .filter(p -> !p.contains("bower_components"))
                .filter(p -> !p.endsWith("package-lock.json"))
                .filter(p -> !p.startsWith(libFolderPath))
                .filter(p -> !copiedFiles.contains(p))
                .peek(p -> log.debug("File to be removed: {}", p))
                .map(File::new)
                .collect(Collectors.toList());
        log.debug("Found {} files to be removed from tmp folder", oldFilesInTmpFolder.size());
        oldFilesInTmpFolder.stream()
                .peek(f -> log.debug("Removing tmp file [{}]", f.toPath()))
                .forEach(File::delete);
    }

    private List<String> findAllFilesInFolder(File folder)
    {
        return FileUtils.listFiles(folder, FileFilterUtils.trueFileFilter(), FileFilterUtils.trueFileFilter())
                .stream()
                .filter(File::isFile)
                .map(File::toPath)
                .map(Path::toString)
                .collect(Collectors.toList());
    }

    /**
     * Create a folder if it is missing, without following a symbolic link at any level.
     * <p>
     * Every folder this class creates - the staging folder, the deployment folder and every intermediate folder of a
     * copied resource - goes through here, so the same symbolic-link refusal applies to all of them.
     *
     * @param folder
     *            the folder to create.
     * @throws IOException
     *             if it cannot be created, or its path is not trustworthy.
     */
    public void createFolderStructure(File folder) throws IOException
    {
        createTrustedFolder(folder);
    }

    private String copyFile(ServletContextResourcePatternResolver resolver, File tmpDir, String fileName)
            throws IOException
    {
        Resource r = resolver.getResource(AngularResourceConstants.WAR_ANGULAR_RESOURCE_PATH + "/" + fileName);
        File target = assertWithin(tmpDir, new File(tmpDir, fileName));

        try (OutputStream out = newNoFollowOutputStream(target))
        {
            IOUtils.copy(r.getInputStream(), out);
        }

        target.setLastModified(r.lastModified());
        log.debug("Copying file to: {}", target.toPath());
        log.debug("Copying file to: {}", target.getCanonicalPath());
        return target.getCanonicalPath();

    }

    public void copyWebappFile(File sourceFolder, File targetFolder, String filenameToCopy) throws IOException
    {
        File source = assertWithin(sourceFolder, new File(sourceFolder, filenameToCopy));
        File target = assertWithin(targetFolder, new File(targetFolder, filenameToCopy));

        copyWithoutFollowingLinks(source, target);
    }

    /**
     * Copy one file, refusing to follow a symbolic link on either side.
     *
     * @param source
     *            the file to read.
     * @param target
     *            the file to write.
     * @throws IOException
     *             if either side is a symbolic link, or the copy fails.
     */
    private void copyWithoutFollowingLinks(File source, File target) throws IOException
    {
        try (java.io.InputStream in = Files.newInputStream(source.toPath(), LinkOption.NOFOLLOW_LINKS);
                OutputStream out = newNoFollowOutputStream(target))
        {
            IOUtils.copy(in, out);
        }
    }

    public void copyWebappResources(File tmpDir, File deployFolder, String folderName) throws IOException
    {
        File toFolder = new File(deployFolder, folderName);
        File fromFolder = new File(tmpDir, folderName);

        Collection<File> sourceFiles = FileUtils.listFiles(fromFolder, FileFilterUtils.trueFileFilter(), FileFilterUtils.trueFileFilter());
        List<String> filesToKeep = new ArrayList<>(sourceFiles.size());

        copyFilesAsNeeded(fromFolder, toFolder, sourceFiles, filesToKeep);

        deleteOldFilesFromFolder(toFolder, filesToKeep);
    }

    private void deleteOldFilesFromFolder(File folder, List<String> filesToKeep) throws IOException
    {
        List<String> targetFilesFound = findAllFilesInFolder(folder);
        log.debug("Found {} files in target folder [{}]", targetFilesFound.size(), folder.getCanonicalPath());

        List<File> oldFilesInTargetFolder = targetFilesFound.stream()
                .filter(p -> !filesToKeep.contains(p))
                .map(File::new)
                .collect(Collectors.toList());
        log.debug("Found {} files to be removed from target folder [{}]", oldFilesInTargetFolder.size(), folder.getCanonicalPath());
        oldFilesInTargetFolder.stream().peek(f -> log.debug("Removing custom file [{}]", f.toPath())).forEach(File::delete);
    }

    private void copyFilesAsNeeded(File fromFolder, File toFolder, Collection<File> sourceFiles, List<String> filesToKeep)
            throws IOException
    {
        for (File f : sourceFiles)
        {
            log.trace("Considering [{}]", f.getCanonicalPath());

            long sourceModified = f.lastModified();
            String relativeName = f.getCanonicalPath().replace(fromFolder.getCanonicalPath(), "");
            File targetFile = assertWithin(toFolder, new File(toFolder, relativeName));

            filesToKeep.add(targetFile.getCanonicalPath());

            log.trace("\tTarget file: [{}]", targetFile.getCanonicalPath());

            if (f.isDirectory())
            {
                createFolderStructure(f);
            }
            else if (targetFile.exists())
            {
                long targetModified = targetFile.lastModified();

                log.trace("\tTarget file exists; modified time is different? {}", targetModified != sourceModified);
                if (targetModified != sourceModified)
                {
                    log.debug("Copying [{}] to [{}]", f.getCanonicalPath(), targetFile.toPath());
                    copyWithoutFollowingLinks(f, targetFile);
                    targetFile.setLastModified(sourceModified);
                }
            }
            else
            {
                createFolderStructure(targetFile.getParentFile());
                copyWithoutFollowingLinks(f, targetFile);
                targetFile.setLastModified(sourceModified);
            }
        }
    }

    public void runFrontEndBuildCommand(File tmpDir, String commandLine) throws IOException
    {
        log.debug("About to run [{}]", commandLine);

        CommandLine command = toTrustedCommandLine(tmpDir, commandLine);
        DefaultExecutor executor = new DefaultExecutor();
        executor.setWorkingDirectory(tmpDir);

        // Slf4jDebugOutputStream is an OutputStream we can send to the DefaultExecutor; the DefaultExecutor will
        // pipe its STDIN and STDOUT to this output stream, which will log such output at DEBUG level to our
        // SLF4j logger.
        try (Slf4jDebugOutputStream debugOutputStream = new Slf4jDebugOutputStream(log))
        {

            executor.setStreamHandler(new PumpStreamHandler(debugOutputStream));
            int exitCode = executor.execute(command, buildToolEnvironment(tmpDir));
            log.debug("done with [{}]: exit code {}", commandLine, exitCode);
        }
    }

    /**
     * Rewrite a configured command line so that its launcher is an absolute path this class has resolved and logged.
     * <p>
     * As configured, the install command names a bare {@code npm}, which the process library resolves from whatever
     * path the server happens to have inherited. Resolving it here instead means the launcher that runs is recorded in
     * the log, is checked to exist and to be executable, and - for the tools installed into the staging folder - is
     * proven to be inside it.
     * <p>
     * On Windows the configured commands are wrapped in the shell's {@code /C} form, so the real launcher is the first
     * argument rather than the executable; that shape is recognised and the launcher inside it is resolved.
     *
     * @param tmpDir
     *            the staging folder, which is the trusted root for locally installed launchers.
     * @param commandLine
     *            the configured command line.
     * @return an equivalent command line whose launcher is absolute.
     * @throws IOException
     *             if the launcher cannot be resolved to an existing executable file.
     */
    private CommandLine toTrustedCommandLine(File tmpDir, String commandLine) throws IOException
    {
        CommandLine parsed = CommandLine.parse(commandLine);
        String[] arguments = parsed.getArguments();
        String executable = parsed.getExecutable();

        // Windows shell wrapper: cmd /C <launcher> <args...>
        if (isWindowsShell(executable) && arguments.length >= 2 && "/C".equalsIgnoreCase(arguments[0]))
        {
            CommandLine rebuilt = new CommandLine(executable);
            rebuilt.addArgument(arguments[0], false);
            rebuilt.addArgument(resolveLauncher(tmpDir, arguments[1]).getPath(), false);
            for (int i = 2; i < arguments.length; i++)
            {
                rebuilt.addArgument(arguments[i], false);
            }
            return rebuilt;
        }

        CommandLine rebuilt = new CommandLine(resolveLauncher(tmpDir, executable));
        rebuilt.addArguments(arguments, false);
        return rebuilt;
    }

    private boolean isWindowsShell(String executable)
    {
        String name = new File(executable).getName();
        return "cmd".equalsIgnoreCase(name) || "cmd.exe".equalsIgnoreCase(name);
    }

    /**
     * Resolve one launcher name to an absolute, existing, executable file.
     *
     * @param tmpDir
     *            the staging folder; a relative launcher is resolved inside it and proven to be contained by it.
     * @param launcher
     *            the launcher as configured.
     * @return the resolved launcher.
     * @throws IOException
     *             if it cannot be resolved.
     */
    private File resolveLauncher(File tmpDir, String launcher) throws IOException
    {
        File asGiven = new File(launcher);

        if (asGiven.isAbsolute())
        {
            return requireExecutable(asGiven, launcher);
        }

        // Grunt and its siblings are installed into the staging folder by the package manager, from the committed
        // lockfile. Resolving them against the staging folder makes the path explicit and lets the containment check
        // prove the launcher is one of those, not something picked up elsewhere.
        if (launcher.indexOf('/') >= 0 || launcher.indexOf('\\') >= 0)
        {
            return requireExecutable(assertWithin(tmpDir, new File(tmpDir, launcher)), launcher);
        }

        String configured = configuredLauncherFor(launcher);

        if (configured != null && !configured.trim().isEmpty())
        {
            return requireExecutable(new File(configured.trim()), launcher);
        }

        return requireExecutable(searchProcessPath(launcher), launcher);
    }

    /**
     * The configured absolute launcher for a bare tool name, if this class has one.
     *
     * @param launcher
     *            the bare launcher name.
     * @return the configured path, or {@code null} when the tool is not one this class pins.
     */
    private String configuredLauncherFor(String launcher)
    {
        String name = stripExecutableSuffix(launcher);

        if ("npm".equals(name))
        {
            return getNpmExecutablePath();
        }

        if ("node".equals(name))
        {
            return getNodeExecutablePath();
        }

        return null;
    }

    private String stripExecutableSuffix(String launcher)
    {
        String name = new File(launcher).getName().toLowerCase();

        for (String suffix : new String[] { ".cmd", ".exe", ".bat", ".ps1" })
        {
            if (name.endsWith(suffix))
            {
                return name.substring(0, name.length() - suffix.length());
            }
        }

        return name;
    }

    /**
     * Find a bare launcher on the process path, once, so that the absolute result can be logged and reused.
     * <p>
     * This is the fallback for a deployment that has not configured an absolute launcher. It is still a real
     * improvement over letting the process library resolve the name on every invocation: the file that will run is
     * named in the log, and the version check that follows rejects it if it is the wrong major version.
     *
     * @param launcher
     *            the bare launcher name.
     * @return the first match on the path.
     * @throws IOException
     *             if the path contains no such executable.
     */
    private File searchProcessPath(String launcher) throws IOException
    {
        String path = System.getenv("PATH");

        if (path == null || path.trim().isEmpty())
        {
            throw new IOException("Cannot locate '" + launcher + "': the server process has no PATH. Configure an "
                    + "absolute path for it on the angularResourceCopier bean.");
        }

        List<String> candidateNames = new ArrayList<>();
        candidateNames.add(launcher);
        if (File.separatorChar == '\\')
        {
            candidateNames.add(launcher + ".cmd");
            candidateNames.add(launcher + ".exe");
            candidateNames.add(launcher + ".bat");
        }

        for (String entry : path.split(Pattern.quote(File.pathSeparator)))
        {
            if (entry.trim().isEmpty())
            {
                continue;
            }

            for (String candidateName : candidateNames)
            {
                File candidate = new File(entry, candidateName);

                if (candidate.isFile() && candidate.canExecute())
                {
                    log.info("Resolved front-end launcher [{}] to [{}]. Configure it explicitly on the "
                            + "angularResourceCopier bean to take the process path out of the trust boundary.",
                            launcher, candidate.getCanonicalPath());
                    return candidate;
                }
            }
        }

        throw new IOException("Cannot locate '" + launcher + "' on the server process PATH. Install it, or configure "
                + "an absolute path for it on the angularResourceCopier bean.");
    }

    private File requireExecutable(File candidate, String launcher) throws IOException
    {
        File canonical = candidate.getCanonicalFile();

        if (!canonical.isFile())
        {
            throw new IOException("Cannot run '" + launcher + "': '" + canonical + "' is not a file.");
        }

        if (!canonical.canExecute())
        {
            throw new IOException("Cannot run '" + launcher + "': '" + canonical + "' is not executable.");
        }

        return canonical;
    }

    /**
     * The environment the front-end tools run with.
     * <p>
     * It starts from the server's own environment, because the tools need a working {@code HOME}, {@code PATH} and
     * temporary directory, and then overrides exactly the settings that decide where an install reads its
     * configuration from and which registry it contacts. Pointing the user and global configuration files at a
     * location inside the staging folder that this class does not create means the package manager finds no
     * configuration file at all, so neither the server user's own file nor a file left in the folder can redirect the
     * registry, the proxy or the certificate authority.
     *
     * @param tmpDir
     *            the staging folder.
     * @return the environment to run with.
     * @throws IOException
     *             if the server's own environment cannot be read.
     */
    private Map<String, String> buildToolEnvironment(File tmpDir) throws IOException
    {
        Map<String, String> environment = EnvironmentUtils.getProcEnvironment();
        File absentConfig = new File(tmpDir, ".arkcase-no-npm-config");

        environment.put("npm_config_userconfig", absentConfig.getPath());
        environment.put("npm_config_globalconfig", absentConfig.getPath());

        if (getNpmRegistry() != null && !getNpmRegistry().trim().isEmpty())
        {
            environment.put("npm_config_registry", getNpmRegistry().trim());
        }

        // The install is driven entirely by the committed lockfile, so nothing needs to be resolved interactively and
        // no progress rendering is wanted in a server log.
        environment.put("npm_config_progress", "false");
        environment.put("npm_config_fund", "false");

        return environment;
    }

    /**
     * Refuse to install unless the Node.js and npm major versions are the ones this build was locked against.
     * <p>
     * The frontend manifest declares its runtime constraint in the {@code engines} field, and npm treats that as
     * advisory by default, so an install performed by a different major version would succeed quietly and produce a
     * dependency tree the lockfile does not describe. The check is therefore made here, before the install, and it
     * fails closed.
     *
     * @throws IOException
     *             if either tool is absent, cannot be interrogated, or reports an unacceptable major version.
     */
    public void verifyFrontEndRuntime() throws IOException
    {
        requirePositive("requiredNodeMajorVersion", getRequiredNodeMajorVersion());
        requirePositive("requiredNpmMajorVersion", getRequiredNpmMajorVersion());

        verifyToolMajorVersion("node", getNodeExecutablePath(), getRequiredNodeMajorVersion());
        verifyToolMajorVersion("npm", getNpmExecutablePath(), getRequiredNpmMajorVersion());
    }

    private void requirePositive(String propertyName, int value) throws IOException
    {
        if (value <= 0)
        {
            throw new IOException("The " + propertyName + " property is " + value + ". It must name the major version "
                    + "the frontend build requires; the check cannot be switched off.");
        }
    }

    private void verifyToolMajorVersion(String tool, String configuredPath, int requiredMajor) throws IOException
    {
        File launcher = configuredPath != null && !configuredPath.trim().isEmpty()
                ? requireExecutable(new File(configuredPath.trim()), tool)
                : requireExecutable(searchProcessPath(tool), tool);

        String reported = readToolVersion(launcher);
        Matcher matcher = VERSION_MAJOR.matcher(reported);

        if (!matcher.find())
        {
            throw new IOException("Could not read a version from '" + launcher + "', which reported '" + reported
                    + "'. The frontend build requires " + tool + " " + requiredMajor + ".");
        }

        int major = Integer.parseInt(matcher.group(1));

        if (major != requiredMajor)
        {
            throw new IOException("Refusing to run the frontend build: '" + launcher + "' is " + tool + " " + reported
                    + ", but this build requires " + tool + " " + requiredMajor + ". Install that major version, or "
                    + "point the angularResourceCopier bean at one, rather than letting the build run on a runtime "
                    + "the committed lockfile was not produced with.");
        }

        log.info("Front-end {} launcher [{}] reports {}, which satisfies the required major version {}.", tool,
                launcher, reported, requiredMajor);
    }

    /**
     * Ask a launcher for its own version, capturing standard output rather than logging it.
     *
     * @param launcher
     *            the resolved launcher.
     * @return the trimmed first line the launcher printed.
     * @throws IOException
     *             if the launcher cannot be run.
     */
    private String readToolVersion(File launcher) throws IOException
    {
        CommandLine command = new CommandLine(launcher);
        command.addArgument("--version", false);

        DefaultExecutor executor = new DefaultExecutor();

        try (ByteArrayOutputStream captured = new ByteArrayOutputStream())
        {
            executor.setStreamHandler(new PumpStreamHandler(captured, captured));
            executor.execute(command);

            String output = new String(captured.toByteArray(), StandardCharsets.UTF_8).trim();
            int newline = output.indexOf('\n');

            return newline < 0 ? output : output.substring(0, newline).trim();
        }
    }

    /**
     * Establish the staging folder as a trusted root for this assembly, and clean the part of it that is not trusted.
     * <p>
     * The folder is configured, long lived and shared with whatever else runs as this user, so it is validated rather
     * than assumed: no component of its path may be a symbolic link, it must be a real directory, and it is created
     * owner-only where the platform expresses permissions that way. Any package-manager configuration file found in
     * it is removed, because nothing copies one there and each one changes what an install does.
     * <p>
     * The folder is deliberately NOT recreated from scratch on every startup. Its whole purpose is to carry the
     * installed dependency tree and the modified-time comparisons across restarts; discarding it would turn every
     * Tomcat start into a full dependency install and a full rebuild. What made a reused folder dangerous was that
     * its contents were trusted, and that is what is fixed: the path is validated here, every stale file is deleted
     * before the package manager runs, every file this class writes is written without following a symbolic link and
     * only after its target has been proven to be inside a trusted root, and the package manager is given a
     * configuration of this class's choosing.
     *
     * @return the validated staging folder.
     * @throws IOException
     *             if the folder cannot be created, is not a directory, or its path is not trustworthy.
     */
    public File cleanAndCreateResourceTempFolder() throws IOException
    {
        File tmpDir = new File(getTempFolderPath());

        createTrustedFolder(tmpDir);
        removePackageManagerConfiguration(tmpDir);

        return tmpDir;
    }

    /**
     * Create a folder, and every missing parent of it, refusing to follow a symbolic link at any level.
     * <p>
     * {@code mkdirs} would happily create the tree through a symbolic link an attacker planted, which would place the
     * whole assembly outside the folder the operator configured. Each level is therefore created individually and
     * checked without following links.
     *
     * @param folder
     *            the folder to establish.
     * @throws IOException
     *             if any path component is a symbolic link, or the folder cannot be created, or it exists as
     *             something other than a directory.
     */
    private void createTrustedFolder(File folder) throws IOException
    {
        Path target = Paths.get(folder.getAbsolutePath()).normalize();

        requireDirectoryNotLink(target);

        if (Files.exists(target, LinkOption.NOFOLLOW_LINKS))
        {
            return;
        }

        log.debug("Creating folder [{}]", target);

        Path existing = firstExistingAncestor(target);
        boolean posix = Files.getFileStore(existing).supportsFileAttributeView("posix");
        int firstMissing = existing.getNameCount();

        for (int depth = firstMissing + 1; depth <= target.getNameCount(); depth++)
        {
            Path level = target.getRoot() == null ? target.subpath(0, depth) : target.getRoot().resolve(target.subpath(0, depth));

            try
            {
                // Created one level at a time, and owner-only where the file system expresses permissions that way, so
                // that nothing else running on the host can plant content the build would later read. Creating each
                // level explicitly is what makes this different from mkdirs: a level that has meanwhile appeared as a
                // symbolic link makes this fail rather than silently place the rest of the tree behind the link.
                if (posix)
                {
                    Files.createDirectory(level, PosixFilePermissions.asFileAttribute(OWNER_ONLY_DIRECTORY));
                }
                else
                {
                    Files.createDirectory(level);
                }
            }
            catch (FileAlreadyExistsException alreadyThere)
            {
                // Benign when it is a real directory - a sibling call created it - and a redirection attempt when it is
                // not, which requireDirectoryNotLink reports as such.
                requireDirectoryNotLink(level);
            }
            catch (IOException e)
            {
                throw new IOException("Could not create folder '" + level + "'", e);
            }
        }
    }

    /**
     * Require that a path is either absent or a real directory, never a symbolic link and never a file.
     * <p>
     * This is applied to every folder this class establishes: the staging folder, the deployment folder and each
     * intermediate folder of a copied resource. Pre-existing ancestors above them are deliberately NOT checked, because
     * an operator may legitimately place the ArkCase home on a symbolic link, and refusing that would break a valid
     * deployment for no gain: containment is proven against canonical paths, which see through such a link, and every
     * write refuses to follow one.
     *
     * @param candidate
     *            the path to check.
     * @throws IOException
     *             if the path exists as a symbolic link or as a non-directory.
     */
    private void requireDirectoryNotLink(Path candidate) throws IOException
    {
        if (Files.isSymbolicLink(candidate))
        {
            throw new IOException("Refusing to use '" + candidate + "': it is a symbolic link where a directory is "
                    + "required. The assembled application must not be redirected outside the configured folder.");
        }

        if (Files.exists(candidate, LinkOption.NOFOLLOW_LINKS) && !Files.isDirectory(candidate, LinkOption.NOFOLLOW_LINKS))
        {
            throw new IOException("Refusing to use '" + candidate + "': it exists but is not a directory.");
        }
    }

    /**
     * The closest ancestor of a path that already exists, used to ask the file system about its capabilities before
     * the path itself is created.
     *
     * @param target
     *            the path being created.
     * @return the nearest existing ancestor, or the path itself if it exists.
     */
    private Path firstExistingAncestor(Path target)
    {
        Path candidate = target;

        while (candidate != null && !Files.exists(candidate))
        {
            candidate = candidate.getParent();
        }

        return candidate == null ? target : candidate;
    }

    /**
     * Remove any package-manager configuration file from the staging folder.
     *
     * @param tmpDir
     *            the staging folder.
     * @throws IOException
     *             if a file is present and cannot be removed, which must stop the assembly rather than let the
     *             package manager read it.
     */
    private void removePackageManagerConfiguration(File tmpDir) throws IOException
    {
        for (String name : PACKAGE_MANAGER_CONFIG_FILES)
        {
            Path candidate = tmpDir.toPath().resolve(name);

            if (Files.exists(candidate, LinkOption.NOFOLLOW_LINKS))
            {
                log.warn("Removing package-manager configuration [{}] from the staging folder; it is not part of the "
                        + "application and would change what the install does.", candidate);
                Files.delete(candidate);
            }
        }
    }

    /**
     * Assert that a file this class is about to write really sits inside the folder it is supposed to sit inside.
     * <p>
     * A resource name that walks upwards, or a target whose parent has been replaced by a symbolic link, would
     * otherwise let a copy land anywhere the server user can write. The comparison is on canonical paths, so it sees
     * through both.
     *
     * @param root
     *            the folder the target must be inside.
     * @param target
     *            the file about to be written.
     * @return the target, unchanged, so this can be used inline.
     * @throws IOException
     *             if the target resolves outside the root.
     */
    private File assertWithin(File root, File target) throws IOException
    {
        String rootPath = root.getCanonicalPath();
        String targetPath = target.getCanonicalPath();

        if (!targetPath.equals(rootPath) && !targetPath.startsWith(rootPath + File.separator))
        {
            throw new IOException("Refusing to write '" + targetPath + "': it resolves outside '" + rootPath + "'.");
        }

        return target;
    }

    /**
     * Open a file for writing without following a symbolic link.
     * <p>
     * A plain {@code FileOutputStream} follows one, so a link planted in the staging or deployment folder between one
     * assembly and the next would send the copy to the link's target. Refusing to follow it turns that into a failure
     * instead of a silent write to somewhere else.
     *
     * @param target
     *            the file to write.
     * @return an output stream that will not follow a symbolic link.
     * @throws IOException
     *             if the file cannot be opened, including because it is a symbolic link.
     */
    private OutputStream newNoFollowOutputStream(File target) throws IOException
    {
        return Files.newOutputStream(target.toPath(), StandardOpenOption.CREATE, StandardOpenOption.WRITE,
                StandardOpenOption.TRUNCATE_EXISTING, LinkOption.NOFOLLOW_LINKS);
    }

    public List<String> copyResources(
            ServletContextResourcePatternResolver resolver,
            String rootPath,
            File tmpDir,
            String moduleRoot) throws IOException
    {
        return copyResources(resolver, rootPath, tmpDir, moduleRoot, moduleRoot);
    }

    public List<String> copyResources(
            ServletContextResourcePatternResolver resolver,
            String rootPath,
            File tmpDir,
            String moduleRoot,
            String targetRoot) throws IOException
    {
        Resource[] resources;
        try
        {
            resources = resolver.getResources(AngularResourceConstants.WAR_ANGULAR_RESOURCE_PATH + "/" + moduleRoot + "/**");
        }
        catch (FileNotFoundException fe)
        {
            log.debug("Not copying resources under [{}], since no such resources exist.",
                    AngularResourceConstants.WAR_ANGULAR_RESOURCE_PATH + "/" + moduleRoot);
            return Collections.emptyList();
        }

        return copyFilesFromWebapp(rootPath, tmpDir, resources, moduleRoot, targetRoot);
    }

    public List<String> copyFilesFromWebapp(String rootPath, File tmpDir, Resource[] resources, String moduleRoot, String targetRoot)
            throws IOException
    {
        File targetFile;
        List<String> filepaths = new ArrayList<>(resources.length);

        for (Resource r : resources)
        {

            targetFile = fileFromResource(rootPath, tmpDir, moduleRoot, targetRoot, r);
            long resourceLastModified = r.lastModified();

            if (targetFile != null)
            {
                String canonicalPath = targetFile.getCanonicalPath();
                log.trace("Copying file [{}]", canonicalPath);

                filepaths.add(canonicalPath);
                createFolderStructure(targetFile.getParentFile());

                if (targetFile.exists())
                {
                    Resource targetResource = new FileSystemResource(targetFile);
                    long targetResourceLastModified = targetResource.lastModified();

                    log.trace("[{}] last modified is different from target? {}", canonicalPath,
                            (resourceLastModified != targetResourceLastModified));
                    if (resourceLastModified != targetResourceLastModified)
                    {
                        log.debug("[{}] has been modified - copying it", canonicalPath);
                        writeResourceWithoutFollowingLinks(r, targetFile);
                        targetFile.setLastModified(resourceLastModified);
                    }
                }
                else
                {
                    writeResourceWithoutFollowingLinks(r, targetFile);
                    targetFile.setLastModified(resourceLastModified);
                }
            }
        }
        return filepaths;
    }

    /**
     * Write one WAR or extension-jar resource into the staging folder without following a symbolic link.
     *
     * @param resource
     *            the resource to read.
     * @param targetFile
     *            the file to write.
     * @throws IOException
     *             if the target is a symbolic link, or the copy fails.
     */
    private void writeResourceWithoutFollowingLinks(Resource resource, File targetFile) throws IOException
    {
        try (java.io.InputStream in = resource.getInputStream(); OutputStream out = newNoFollowOutputStream(targetFile))
        {
            IOUtils.copy(in, out);
        }
    }

    public File fileFromResource(String rootPath, File tmpDir, String moduleRoot, String targetRoot, Resource r) throws IOException
    {
        File targetFile = null;

        URL url = r.getURL();
        if ("jar".equals(url.getProtocol()))
        {
            String webappPath = logicalPathFromJarPath(url);
            webappPath = webappPath.replaceFirst(moduleRoot, targetRoot);

            if (!webappPath.endsWith("/"))
            {
                targetFile = new File(tmpDir, webappPath);
            }
        }
        else if (r.getFile().isFile())
        {
            targetFile = determineTargetFile(rootPath, tmpDir, r, moduleRoot, targetRoot);
        }

        // The target path is derived from a resource name inside a WAR or an extension jar, so it is external input.
        // Both branches above build it by appending to the staging folder, which a name containing an upward
        // traversal would escape. Proving containment here covers every caller in one place, because this is the only
        // method that turns a resource into a file to write.
        return targetFile == null ? null : assertWithin(tmpDir, targetFile);
    }

    public String logicalPathFromJarPath(URL url)
    {
        // should have come from META-INF/resources/resources folder
        String path = url.getFile();

        int metaInfPortionLength = AngularResourceConstants.JAR_PATH_META_INF_PORTION.length();

        String webappPath = path.substring(path.indexOf(AngularResourceConstants.JAR_PATH_META_INF_PORTION) + metaInfPortionLength + 1);
        log.trace("webapp path for URL [{}] is [{}]: ", url, webappPath);
        return webappPath;
    }

    public File determineTargetFile(String rootPath, File tmpDir, Resource r, String moduleRoot, String targetRoot) throws IOException
    {
        String resourceFullPath = r.getFile().getCanonicalPath();
        String relativePath = resourceFullPath.replace(rootPath, "");

        log.trace("relative path: [{}]", relativePath);

        relativePath = relativePath.replaceFirst(moduleRoot, targetRoot);

        log.trace("new relative path: [{}]", relativePath);

        return new File(tmpDir, relativePath);
    }

    public String getTempFolderPath()
    {
        return tempFolderPath;
    }

    public void setTempFolderPath(String tempFolderPath)
    {
        this.tempFolderPath = tempFolderPath;
    }

    public String getDeployFolderPath()
    {
        return deployFolderPath;
    }

    public void setDeployFolderPath(String deployFolderPath)
    {
        this.deployFolderPath = deployFolderPath;
    }

    public List<String> getResourceFoldersToCopyFromArchive()
    {
        return resourceFoldersToCopyFromArchive;
    }

    public void setResourceFoldersToCopyFromArchive(List<String> resourceFoldersToCopyFromArchive)
    {
        this.resourceFoldersToCopyFromArchive = resourceFoldersToCopyFromArchive;
    }

    public List<String> getAssembledFoldersToCopyToDeployment()
    {
        return assembledFoldersToCopyToDeployment;
    }

    public void setAssembledFoldersToCopyToDeployment(List<String> assembledFoldersToCopyToDeployment)
    {
        this.assembledFoldersToCopyToDeployment = assembledFoldersToCopyToDeployment;
    }

    public List<String> getFilesToCopyFromArchive()
    {
        return filesToCopyFromArchive;
    }

    public void setFilesToCopyFromArchive(List<String> filesToCopyFromArchive)
    {
        this.filesToCopyFromArchive = filesToCopyFromArchive;
    }

    public List<String> getAssembledFilesToCopyToDeployment()
    {
        return assembledFilesToCopyToDeployment;
    }

    public void setAssembledFilesToCopyToDeployment(List<String> assembledFilesToCopyToDeployment)
    {
        this.assembledFilesToCopyToDeployment = assembledFilesToCopyToDeployment;
    }

    public List<String> getFrontEndCommandsToBeExecuted()
    {
        return frontEndCommandsToBeExecuted;
    }

    public void setFrontEndCommandsToBeExecuted(List<String> frontEndCommandsToBeExecuted)
    {
        this.frontEndCommandsToBeExecuted = frontEndCommandsToBeExecuted;
    }

    public List<String> getCustomResourceSourcesToCopyFromArchive()
    {
        return customResourceSourcesToCopyFromArchive;
    }

    public void setCustomResourceSourcesToCopyFromArchive(List<String> customResourceSourcesToCopyFromArchive)
    {
        this.customResourceSourcesToCopyFromArchive = customResourceSourcesToCopyFromArchive;
    }

    public AcmSpringActiveProfile getSpringActiveProfile()
    {
        return springActiveProfile;
    }

    public void setSpringActiveProfile(AcmSpringActiveProfile springActiveProfile)
    {
        this.springActiveProfile = springActiveProfile;
    }

    public String getMergeConfigFrontendTask()
    {
        return mergeConfigFrontendTask;
    }

    public void setMergeConfigFrontendTask(String mergeConfigFrontendTask)
    {
        this.mergeConfigFrontendTask = mergeConfigFrontendTask;
    }

    public String getYarnInstallCommand()
    {
        return yarnInstallCommand;
    }

    public void setYarnInstallCommand(String yarnInstallCommand)
    {
        this.yarnInstallCommand = yarnInstallCommand;
    }

    public String getGruntDefaultCommand()
    {
        return gruntDefaultCommand;
    }

    public void setGruntDefaultCommand(String gruntDefaultCommand)
    {
        this.gruntDefaultCommand = gruntDefaultCommand;
    }

    public String getNodeExecutablePath()
    {
        return nodeExecutablePath;
    }

    /**
     * Pin the Node.js launcher to an absolute path.
     *
     * @param nodeExecutablePath
     *            absolute path of the launcher, or blank to resolve it from the server process path once and log the
     *            result.
     */
    public void setNodeExecutablePath(String nodeExecutablePath)
    {
        this.nodeExecutablePath = nodeExecutablePath == null ? "" : nodeExecutablePath;
    }

    public String getNpmExecutablePath()
    {
        return npmExecutablePath;
    }

    /**
     * Pin the npm launcher to an absolute path.
     *
     * @param npmExecutablePath
     *            absolute path of the launcher, or blank to resolve it from the server process path once and log the
     *            result.
     */
    public void setNpmExecutablePath(String npmExecutablePath)
    {
        this.npmExecutablePath = npmExecutablePath == null ? "" : npmExecutablePath;
    }

    public int getRequiredNodeMajorVersion()
    {
        return requiredNodeMajorVersion;
    }

    /**
     * Set the Node.js major version the frontend build requires. The check that uses it cannot be switched off: a
     * value of zero or less is rejected when the build runs.
     *
     * @param requiredNodeMajorVersion
     *            the required major version.
     */
    public void setRequiredNodeMajorVersion(int requiredNodeMajorVersion)
    {
        this.requiredNodeMajorVersion = requiredNodeMajorVersion;
    }

    public int getRequiredNpmMajorVersion()
    {
        return requiredNpmMajorVersion;
    }

    /**
     * Set the npm major version the frontend build requires. The check that uses it cannot be switched off: a value of
     * zero or less is rejected when the build runs.
     *
     * @param requiredNpmMajorVersion
     *            the required major version.
     */
    public void setRequiredNpmMajorVersion(int requiredNpmMajorVersion)
    {
        this.requiredNpmMajorVersion = requiredNpmMajorVersion;
    }

    public String getNpmRegistry()
    {
        return npmRegistry;
    }

    /**
     * Set the registry the package manager installs from.
     *
     * @param npmRegistry
     *            the registry url.
     */
    public void setNpmRegistry(String npmRegistry)
    {
        this.npmRegistry = npmRegistry;
    }
}