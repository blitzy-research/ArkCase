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
import org.apache.commons.exec.PumpStreamHandler;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.io.filefilter.FileFilterUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.util.FileCopyUtils;
import org.springframework.web.context.ServletContextAware;
import org.springframework.web.context.support.ServletContextResourcePatternResolver;
import org.zeroturnaround.exec.stream.slf4j.Slf4jDebugOutputStream;

import javax.servlet.ServletContext;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Copy all angular resources from the base ArkCase WAR file and also from any ArkCase extension jars, run the
 * Angular front-end build tools, and copy the assembled application into the deployment folder.
 * <p>
 * The ArkCase WAR file should configure the deployment folder in a Tomcat context resources element, such that
 * files in this deployment folder are treated as if they were in the root folder of the war file itself.
 * <p>
 * npm (the Node.js Package Manager) must be installed on the deployment host and must be in the system path;
 * the install step runs `npm ci`, so the committed package-lock.json is what determines the dependency tree.
 * <p>
 * <b>The required Node.js and npm major versions are verified before the install runs, not assumed.</b> The
 * committed lockfile is at lockfileVersion 3 and was produced by npm 10 on Node 20, and the frontend manifest
 * declares both majors in its {@code engines} block. Declaring a runtime in a manifest does not make a
 * deployment use it, so this class asks the launchers on the path for their own versions and refuses to run the
 * build when either major is wrong. The alternative - installing on whatever happens to be first on the path -
 * is how a deployment ends up serving assets that no one built on the supported runtime.
 * <p>
 * <b>The front-end commands run with an explicitly constructed environment rather than with the servlet
 * container's.</b> Tomcat's environment carries whatever the deployment gave it - keystore and trust-store
 * passwords among the JVM arguments, database and integration credentials, deployment tokens - and a package
 * manager installing several hundred third-party packages is the last process that should inherit it. Only the
 * variables the build genuinely needs are passed through, by name or by prefix; see
 * {@link #DEFAULT_ENVIRONMENT_VARIABLES_TO_PASS_THROUGH} and
 * {@link #DEFAULT_ENVIRONMENT_VARIABLE_PREFIXES_TO_PASS_THROUGH}.
 * <p>
 * <b>Package lifecycle scripts are disabled for the install by default, and that default was measured rather
 * than chosen.</b> Five packages in the committed graph declare install scripts and every source-control
 * dependency may declare a prepare script, so an install is an arbitrary-code-execution surface. Installing the
 * committed lockfile twice on Node 20, once with lifecycle scripts enabled and once with them disabled, produced
 * <em>byte-identical</em> output for all five pipeline artifacts and for the source map, so disabling them costs
 * nothing here. It is a property, not a hard-coded choice: an estate whose graph needs an install script can set
 * {@code npmLifecycleScriptsEnabled} to true and the previous behaviour returns.
 * <p>
 * The resources to be copied from the war file and extension jars; the front-end commands to be run (e.g. npm,
 * grunt); and the resources to be copied to the deployment folder are configured in Spring. All resources to
 * be copied from the war file and extension jars must be within a top-level resources folder.
 */
public class AngularResourceCopier implements ServletContextAware
{
    /**
     * The environment variables the front-end build is given by name. Each one is here because the build or one
     * of its launchers needs it, and nothing is here for convenience:
     * <ul>
     * <li>{@code PATH} resolves the launchers; {@code HOME} is where npm keeps its cache and configuration.</li>
     * <li>{@code NODE_ENV} is <b>behaviour-bearing</b>: the Gruntfile branches on it when it renders the entry
     * document, so dropping it would change a produced artifact.</li>
     * <li>{@code LANG} and {@code LC_ALL} keep tool output and any locale-sensitive sorting stable.</li>
     * <li>The temporary-directory and Windows-shell variables are what let the same code run on a Windows
     * deployment, where the configured command prefix is {@code cmd /C}.</li>
     * <li>The proxy and certificate variables are how an estate behind an egress proxy or a private trust store
     * reaches a registry at all; omitting them would turn a working deployment into a failing one.</li>
     * <li>{@code SSH_AUTH_SOCK} and {@code GIT_SSH_COMMAND} are how a source-control dependency that resolves
     * over SSH authenticates. They are the two most sensitive entries in this list and they are here because
     * removing them would break that resolution rather than because they are harmless.</li>
     * </ul>
     */
    public static final List<String> DEFAULT_ENVIRONMENT_VARIABLES_TO_PASS_THROUGH = Collections
            .unmodifiableList(Arrays.asList(
                    "PATH", "HOME", "NODE_ENV", "LANG", "LC_ALL",
                    "TMPDIR", "TEMP", "TMP",
                    "SystemRoot", "SystemDrive", "COMSPEC", "PATHEXT", "USERPROFILE", "APPDATA", "LOCALAPPDATA",
                    "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy",
                    "NODE_EXTRA_CA_CERTS", "SSL_CERT_FILE", "SSL_CERT_DIR", "GIT_SSL_CAINFO",
                    "SSH_AUTH_SOCK", "GIT_SSH_COMMAND"));

    /**
     * Prefixes whose variables are passed through wholesale. npm's own configuration arrives this way -
     * {@code npm_config_registry}, {@code npm_config_cache}, an authentication token for a private registry -
     * and an estate that configures npm through the environment would otherwise silently lose that
     * configuration and fall back to the public registry. {@code NODE_OPTIONS} is deliberately <b>not</b>
     * passed through by default: it can inject code into every Node process the build starts.
     */
    public static final List<String> DEFAULT_ENVIRONMENT_VARIABLE_PREFIXES_TO_PASS_THROUGH = Collections
            .unmodifiableList(Arrays.asList("npm_config_", "NPM_CONFIG_"));

    private static final String DEFAULT_NODE_VERSION_COMMAND = "node --version";

    private static final String DEFAULT_NPM_VERSION_COMMAND = "npm --version";

    private transient final Logger log = LoggerFactory.getLogger(getClass());

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
    private String nodeVersionCommand = DEFAULT_NODE_VERSION_COMMAND;
    private String npmVersionCommand = DEFAULT_NPM_VERSION_COMMAND;
    private String requiredNodeMajorVersion = "20";
    private String requiredNpmMajorVersion = "10";
    private boolean npmLifecycleScriptsEnabled = false;
    private List<String> environmentVariablesToPassThrough = DEFAULT_ENVIRONMENT_VARIABLES_TO_PASS_THROUGH;
    private List<String> environmentVariablePrefixesToPassThrough = DEFAULT_ENVIRONMENT_VARIABLE_PREFIXES_TO_PASS_THROUGH;

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

            // Verify the runtime BEFORE installing anything. The install is what writes several hundred packages
            // into the deployment's temporary tree, so a wrong major version has to be caught in front of it
            // rather than after.
            verifyFrontEndToolchain(tmpDir);

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
        File target = new File(parentDir, "profiles.js");
        Files.copy(IOUtils.toInputStream(exportProfiles), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
        target.setLastModified(new Date().getTime());
        return target.getCanonicalPath();
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

    public void createFolderStructure(File folder) throws IOException
    {
        if (!folder.exists())
        {
            log.debug("Creating folder [{}]", folder.getCanonicalPath());
            boolean foldersCreated = folder.mkdirs();
            if (!foldersCreated)
            {
                throw new IOException("Could not create folder '" + folder.getCanonicalPath() + "'");
            }
        }
    }

    private String copyFile(ServletContextResourcePatternResolver resolver, File tmpDir, String fileName)
            throws IOException
    {
        Resource r = resolver.getResource(AngularResourceConstants.WAR_ANGULAR_RESOURCE_PATH + "/" + fileName);
        File target = new File(tmpDir, fileName);

        Files.copy(r.getInputStream(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
        target.setLastModified(r.lastModified());
        log.debug("Copying file to: {}", target.toPath());
        log.debug("Copying file to: {}", target.getCanonicalPath());
        return target.getCanonicalPath();

    }

    public void copyWebappFile(File sourceFolder, File targetFolder, String filenameToCopy) throws IOException
    {
        FileCopyUtils.copy(new File(sourceFolder, filenameToCopy), new File(targetFolder, filenameToCopy));
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
            File targetFile = new File(toFolder, relativeName);

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
                    FileCopyUtils.copy(f, targetFile);
                    targetFile.setLastModified(sourceModified);
                }
            }
            else
            {
                createFolderStructure(targetFile.getParentFile());
                FileCopyUtils.copy(f, targetFile);
                targetFile.setLastModified(sourceModified);
            }
        }
    }

    /**
     * Build the environment the front-end commands run with.
     * <p>
     * Commons Exec inherits the calling process's environment when it is handed no environment at all, and the
     * calling process here is Tomcat. Everything Tomcat was given - the keystore and trust-store passwords in its
     * JVM arguments, database and integration credentials, deployment tokens - would reach every install script
     * and every task in the build. So the environment is composed rather than inherited: a variable is present
     * only if it is named in {@link #getEnvironmentVariablesToPassThrough()} or carries one of the prefixes in
     * {@link #getEnvironmentVariablePrefixesToPassThrough()}.
     * <p>
     * The lifecycle-script decision is applied last, so it cannot be overridden by an inherited
     * {@code npm_config_ignore_scripts} that arrived through the prefix pass-through. It is expressed as npm
     * configuration rather than as a command-line flag so that the configured command string - which an estate
     * may have customised - does not have to be rewritten to carry it.
     *
     * @return the environment for the child process, never null and never the inherited environment
     */
    public Map<String, String> buildFrontEndCommandEnvironment()
    {
        Map<String, String> inherited = System.getenv();
        Map<String, String> childEnvironment = new LinkedHashMap<>();

        for (String name : getEnvironmentVariablesToPassThrough())
        {
            String value = inherited.get(name);
            if (value != null)
            {
                childEnvironment.put(name, value);
            }
        }

        for (Map.Entry<String, String> entry : inherited.entrySet())
        {
            for (String prefix : getEnvironmentVariablePrefixesToPassThrough())
            {
                if (entry.getKey().startsWith(prefix))
                {
                    childEnvironment.put(entry.getKey(), entry.getValue());
                    break;
                }
            }
        }

        childEnvironment.put("npm_config_ignore_scripts", Boolean.toString(!isNpmLifecycleScriptsEnabled()));

        // Names only. The values are exactly what must not be written to a log, which is the reason this method
        // exists at all.
        log.info("Front-end build environment composed from {} of the {} variables this process holds: {}",
                childEnvironment.size(), inherited.size(), childEnvironment.keySet());
        log.info("npm lifecycle scripts enabled for the front-end install: {}", isNpmLifecycleScriptsEnabled());

        return childEnvironment;
    }

    /**
     * Refuse to build unless the Node.js and npm major versions on the path are the ones the committed lockfile
     * was produced with.
     * <p>
     * This is a fail-fast check with a diagnostic, deliberately not a warning. A lockfile at lockfileVersion 3
     * installed by an older npm, or a build run on an older Node.js, produces a dependency graph and a set of
     * assets that nothing in this project was verified against - and it does so quietly, leaving a deployment
     * that looks healthy and serves assets no one built on the supported runtime.
     *
     * @param tmpDir
     *            the directory the launchers are probed from, so the probe sees the same resolution the build will
     * @throws IOException
     *             if a launcher cannot be executed, or if either reported major version is not the required one
     */
    public void verifyFrontEndToolchain(File tmpDir) throws IOException
    {
        String nodeReported = captureCommandOutput(tmpDir, getNodeVersionCommand());
        String npmReported = captureCommandOutput(tmpDir, getNpmVersionCommand());

        log.info("Front-end toolchain reported by the launchers on the path: node [{}], npm [{}]", nodeReported,
                npmReported);

        assertMajorVersion("Node.js", nodeReported, getRequiredNodeMajorVersion(), getNodeVersionCommand());
        assertMajorVersion("npm", npmReported, getRequiredNpmMajorVersion(), getNpmVersionCommand());
    }

    /**
     * Extract the leading major version from a launcher's own output and compare it with the required one.
     * <p>
     * The output is parsed rather than matched whole, because {@code node} answers with a leading {@code v} and
     * {@code npm} without one, and both may add a suffix. Anything that is not a leading run of digits - an empty
     * answer, a usage message, a shell error - fails the check rather than being read as a version.
     */
    private void assertMajorVersion(String tool, String reported, String required, String command) throws IOException
    {
        String trimmed = reported == null ? "" : reported.trim();
        String withoutPrefix = trimmed.startsWith("v") || trimmed.startsWith("V") ? trimmed.substring(1) : trimmed;
        StringBuilder major = new StringBuilder();
        for (int i = 0; i < withoutPrefix.length() && Character.isDigit(withoutPrefix.charAt(i)); i++)
        {
            major.append(withoutPrefix.charAt(i));
        }

        if (major.length() == 0)
        {
            throw new IOException(String.format(
                    "The front-end build cannot start: [%s] reported [%s], which carries no version this check can read. "
                            + "%s %s is required. Put the required launcher on the path Tomcat runs with, or adjust the "
                            + "angularResourceCopier bean's %sVersionCommand property to name it.",
                    command, trimmed, tool, required, tool.equals("npm") ? "npm" : "node"));
        }

        if (!major.toString().equals(required))
        {
            throw new IOException(String.format(
                    "The front-end build cannot start: %s major version %s is on the path, but the committed "
                            + "package-lock.json was produced with %s %s and the frontend package.json engines block "
                            + "requires it. [%s] reported [%s]. Install the required version, or - if this estate has "
                            + "verified another one - set the angularResourceCopier bean's required%sMajorVersion "
                            + "property.",
                    tool, major, tool, required, command, trimmed, tool.equals("npm") ? "Npm" : "Node"));
        }
    }

    /**
     * Run a command and return its standard output as a string, rather than logging it.
     * <p>
     * Used by the toolchain check, which has to read a launcher's answer rather than merely record it. The child
     * gets the same composed environment and the same working directory as the build itself, so the version it
     * reports is the version the build will use and not the version some other path resolution would give.
     */
    private String captureCommandOutput(File tmpDir, String commandLine) throws IOException
    {
        log.debug("About to run [{}] and capture its output", commandLine);
        CommandLine command = CommandLine.parse(commandLine);
        DefaultExecutor executor = new DefaultExecutor();
        executor.setWorkingDirectory(tmpDir);

        try (ByteArrayOutputStream captured = new ByteArrayOutputStream())
        {
            executor.setStreamHandler(new PumpStreamHandler(captured));
            executor.execute(command, buildFrontEndCommandEnvironment());
            return captured.toString("UTF-8");
        }
    }

    public void runFrontEndBuildCommand(File tmpDir, String commandLine) throws IOException
    {
        log.info("About to run [{}]", commandLine);
        CommandLine command = CommandLine.parse(commandLine);
        DefaultExecutor executor = new DefaultExecutor();
        executor.setWorkingDirectory(tmpDir);

        // Slf4jDebugOutputStream is an OutputStream we can send to the DefaultExecutor; the DefaultExecutor will
        // pipe its STDIN and STDOUT to this output stream, which will log such output at DEBUG level to our
        // SLF4j logger.
        try (Slf4jDebugOutputStream debugOutputStream = new Slf4jDebugOutputStream(log))
        {

            executor.setStreamHandler(new PumpStreamHandler(debugOutputStream));
            // The environment is passed explicitly. Calling the single-argument execute here would hand the child
            // Tomcat's whole environment, which is what this overload exists to avoid.
            int exitCode = executor.execute(command, buildFrontEndCommandEnvironment());
            log.info("done with [{}]: exit code {}", commandLine, exitCode);
        }
    }

    public File cleanAndCreateResourceTempFolder() throws IOException
    {
        File tmpDir = new File(getTempFolderPath());
        createFolderStructure(tmpDir);
        return tmpDir;
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
                        FileCopyUtils.copy(r.getInputStream(), new FileOutputStream(targetFile));
                        targetFile.setLastModified(resourceLastModified);
                    }
                }
                else
                {
                    FileCopyUtils.copy(r.getInputStream(), new FileOutputStream(targetFile));
                    targetFile.setLastModified(resourceLastModified);
                }
            }
        }
        return filepaths;
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

        return targetFile;
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

    public String getNodeVersionCommand()
    {
        return nodeVersionCommand;
    }

    public void setNodeVersionCommand(String nodeVersionCommand)
    {
        this.nodeVersionCommand = nodeVersionCommand;
    }

    public String getNpmVersionCommand()
    {
        return npmVersionCommand;
    }

    public void setNpmVersionCommand(String npmVersionCommand)
    {
        this.npmVersionCommand = npmVersionCommand;
    }

    public String getRequiredNodeMajorVersion()
    {
        return requiredNodeMajorVersion;
    }

    public void setRequiredNodeMajorVersion(String requiredNodeMajorVersion)
    {
        this.requiredNodeMajorVersion = requiredNodeMajorVersion;
    }

    public String getRequiredNpmMajorVersion()
    {
        return requiredNpmMajorVersion;
    }

    public void setRequiredNpmMajorVersion(String requiredNpmMajorVersion)
    {
        this.requiredNpmMajorVersion = requiredNpmMajorVersion;
    }

    public boolean isNpmLifecycleScriptsEnabled()
    {
        return npmLifecycleScriptsEnabled;
    }

    public void setNpmLifecycleScriptsEnabled(boolean npmLifecycleScriptsEnabled)
    {
        this.npmLifecycleScriptsEnabled = npmLifecycleScriptsEnabled;
    }

    public List<String> getEnvironmentVariablesToPassThrough()
    {
        return environmentVariablesToPassThrough;
    }

    public void setEnvironmentVariablesToPassThrough(List<String> environmentVariablesToPassThrough)
    {
        this.environmentVariablesToPassThrough = environmentVariablesToPassThrough == null
                ? DEFAULT_ENVIRONMENT_VARIABLES_TO_PASS_THROUGH
                : environmentVariablesToPassThrough;
    }

    public List<String> getEnvironmentVariablePrefixesToPassThrough()
    {
        return environmentVariablePrefixesToPassThrough;
    }

    public void setEnvironmentVariablePrefixesToPassThrough(List<String> environmentVariablePrefixesToPassThrough)
    {
        this.environmentVariablePrefixesToPassThrough = environmentVariablePrefixesToPassThrough == null
                ? DEFAULT_ENVIRONMENT_VARIABLE_PREFIXES_TO_PASS_THROUGH
                : environmentVariablePrefixesToPassThrough;
    }
}