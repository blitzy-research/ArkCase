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
import org.apache.commons.exec.environment.EnvironmentUtils;
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
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Map;
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
 * npm (the Node.js Package Manager) must be installed on the deployment host, and npm must be in the
 * system path, on a Node runtime that satisfies the frontend's declared engines. The <code>.npmrc</code> copied
 * into the temp folder sets <code>engine-strict</code>, and the install command passes
 * <code>--engine-strict</code> as well, so an out-of-range runtime fails the install instead of quietly building
 * against it.
 * <p>
 * The install needs <strong>outbound HTTPS to registry.npmjs.org and to codeload.github.com</strong>, and nothing
 * else. That second host is easy to miss: 53 of the locked dependencies are GitHub repositories, and
 * <code>package-lock.json</code> records them as <code>git+ssh://git@github.com/...</code> URLs because npm
 * rewrites every GitHub coordinate to ssh when it writes a lockfile, whatever the manifest declared. Those URLs do
 * <em>not</em> make ssh - or even git - a deployment prerequisite: because the lockfile pins each one to an exact
 * commit, npm downloads them as HTTPS tarballs from codeload.github.com and only falls back to cloning with git if
 * that fails. Verified on this codebase by running the install with an empty environment, ssh disabled, a cold npm
 * cache and no git binary on the path at all.
 * <p>
 * A git client is therefore optional here, and needed only for the developer or CI step that regenerates the
 * lockfile. When one is present and recent enough, this class still hands it <code>url.insteadOf</code> rewrite
 * rules through the <code>GIT_CONFIG_COUNT</code> / <code>GIT_CONFIG_KEY_n</code> / <code>GIT_CONFIG_VALUE_n</code>
 * environment variables for the duration of the install, so that even npm's git fallback goes over HTTPS and needs
 * no SSH key and no git configuration on the host. Those variables require git 2.31 or newer; on an older git, or
 * when the deployment host has set <code>GIT_CONFIG_COUNT</code> itself, the host's own git configuration is left
 * strictly alone.
 * <p>
 * The resources to be copied from the war file and extension jars; the front-end commands to be run (e.g. npm,
 * grunt); and the resources to be copied to the deployment folder are configured in Spring. All resources to
 * be copied from the war file and extension jars must be within a top-level resources folder.
 */
public class AngularResourceCopier implements ServletContextAware
{
    /**
     * Command used to find out whether a git client is present, and which version it is.
     */
    private static final String GIT_VERSION_COMMAND = "git --version";

    /**
     * Matches the numeric part of <code>git version 2.31.1</code> and of vendor-suffixed variants such as
     * <code>git version 2.39.5 (Apple Git-154)</code>.
     */
    private static final Pattern GIT_VERSION_PATTERN = Pattern.compile("git version (\\d+)\\.(\\d+)");

    /**
     * First git release that reads configuration from GIT_CONFIG_COUNT / GIT_CONFIG_KEY_n / GIT_CONFIG_VALUE_n. On
     * anything older those variables are ignored, so the rewrite below cannot be applied.
     */
    private static final int GIT_ENVIRONMENT_CONFIG_MIN_MAJOR = 2;

    private static final int GIT_ENVIRONMENT_CONFIG_MIN_MINOR = 31;

    /**
     * Environment variable through which git is told how many configuration entries follow. It doubles as the
     * operator's opt-out: when the deployment host has already set it, this class adds nothing.
     */
    private static final String GIT_CONFIG_COUNT = "GIT_CONFIG_COUNT";

    /**
     * The rewrite this class installs for the install subprocess: reach GitHub over HTTPS instead of ssh. Every form
     * npm can hand to git is listed, since the lockfile is written with git+ssh URLs and older entries may use the
     * scp-like form.
     */
    private static final String GIT_HTTPS_REWRITE_KEY = "url.https://github.com/.insteadOf";

    private static final String[] GIT_REWRITTEN_GITHUB_PREFIXES = { "git+ssh://git@github.com/", "ssh://git@github.com/",
            "git@github.com:", "git://github.com/" };

    private transient final Logger log = LoggerFactory.getLogger(getClass());

    private String tempFolderPath;
    private String deployFolderPath;
    private String mergeConfigFrontendTask;
    private String npmInstallCommand;
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

            // npm ci, with git pointed at HTTPS so that even its fallback clone needs no SSH credentials
            runFrontEndBuildCommand(tmpDir, npmInstallCommand, npmInstallEnvironment());
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

    public void runFrontEndBuildCommand(File tmpDir, String commandLine) throws IOException
    {
        runFrontEndBuildCommand(tmpDir, commandLine, null);
    }

    /**
     * Runs a front-end build command in the temp folder, optionally with a specific environment.
     *
     * @param tmpDir
     *            the working directory for the command.
     * @param commandLine
     *            the command to run.
     * @param environment
     *            the complete environment for the child process, or <code>null</code> to inherit this JVM's
     *            environment unchanged. Commons Exec replaces rather than extends the environment when one is
     *            supplied, which is why {@link #npmInstallEnvironment()} starts from the current process
     *            environment.
     * @throws IOException
     *             if the command cannot be started, or exits with a non-zero status. Either way the caller turns it
     *             into a deployment failure, because a partially assembled webapp is worse than one that refuses to
     *             start.
     */
    public void runFrontEndBuildCommand(File tmpDir, String commandLine, Map<String, String> environment) throws IOException
    {
        log.debug("About to run [{}]", commandLine);
        CommandLine command = CommandLine.parse(commandLine);
        DefaultExecutor executor = new DefaultExecutor();
        executor.setWorkingDirectory(tmpDir);

        // Slf4jDebugOutputStream is an OutputStream we can send to the DefaultExecutor; the DefaultExecutor will
        // pipe its STDIN and STDOUT to this output stream, which will log such output at DEBUG level to our
        // SLF4j logger.
        try (Slf4jDebugOutputStream debugOutputStream = new Slf4jDebugOutputStream(log))
        {

            executor.setStreamHandler(new PumpStreamHandler(debugOutputStream));
            int exitCode = environment == null ? executor.execute(command) : executor.execute(command, environment);
            log.debug("done with [{}]: exit code {}", commandLine, exitCode);
        }
    }

    /**
     * Builds the environment for the npm install, so that npm's git fallback for the lockfile's GitHub dependencies
     * travels over HTTPS instead of ssh.
     * <p>
     * npm writes every GitHub coordinate into the lockfile as a <code>git+ssh://git@github.com/...</code> URL, no
     * matter how the manifest spelled it. The install itself does not need ssh - each of those entries is pinned to
     * a commit, so npm downloads a tarball from codeload.github.com over HTTPS - but if that download fails npm
     * falls back to cloning the repository with git, and on a host with no SSH key that fallback dies with a
     * permission-denied error which says nothing about the real cause. Handing git the rewrite rules here removes
     * that trap: the fallback resolves over HTTPS too. Nothing on the host is modified, because the rules travel as
     * environment variables of this one child process.
     * <p>
     * Two situations leave the host's git configuration strictly alone. When the host has set
     * <code>GIT_CONFIG_COUNT</code> itself, an operator has arranged their own transport (an internal mirror, or a
     * deploy key) and must keep it, since git gives environment configuration the last word. When git is absent or
     * predates environment configuration, there is nothing to configure - and nothing is broken by that, because the
     * install's primary path never invokes git.
     *
     * @return the environment to run the install with; never <code>null</code>.
     * @throws IOException
     *             if this process's own environment cannot be read.
     */
    private Map<String, String> npmInstallEnvironment() throws IOException
    {
        Map<String, String> environment = EnvironmentUtils.getProcEnvironment();

        if (environment.containsKey(GIT_CONFIG_COUNT))
        {
            log.info("{} is already set in the environment; leaving the git configuration of this host untouched.",
                    GIT_CONFIG_COUNT);
            return environment;
        }

        String gitVersion = detectGitClient();
        if (gitVersion == null || !supportsEnvironmentConfiguration(gitVersion))
        {
            log.info("No git client supporting environment configuration was found (git {}.{} or newer); the npm "
                    + "install will fetch the GitHub dependencies of package-lock.json as HTTPS tarballs from "
                    + "codeload.github.com, which needs no git at all. Should npm have to fall back to cloning them, "
                    + "this host would need its own url.insteadOf rewrites or SSH credentials for git@github.com.",
                    GIT_ENVIRONMENT_CONFIG_MIN_MAJOR, GIT_ENVIRONMENT_CONFIG_MIN_MINOR);
            return environment;
        }

        environment.put(GIT_CONFIG_COUNT, String.valueOf(GIT_REWRITTEN_GITHUB_PREFIXES.length));
        for (int i = 0; i < GIT_REWRITTEN_GITHUB_PREFIXES.length; i++)
        {
            environment.put("GIT_CONFIG_KEY_" + i, GIT_HTTPS_REWRITE_KEY);
            environment.put("GIT_CONFIG_VALUE_" + i, GIT_REWRITTEN_GITHUB_PREFIXES[i]);
        }
        log.info("Configured [{}] to reach github.com over HTTPS for the duration of the npm install, so no SSH "
                + "credentials are needed on this host.", gitVersion);

        return environment;
    }

    /**
     * Reports which git client is on the path, if any.
     *
     * @return the trimmed output of <code>git --version</code>, or <code>null</code> when git cannot be run. A
     *         <code>null</code> is not an error: the install fetches the locked GitHub dependencies over HTTPS and
     *         only uses git as a fallback.
     */
    private String detectGitClient()
    {
        try (ByteArrayOutputStream versionOutput = new ByteArrayOutputStream())
        {
            DefaultExecutor executor = new DefaultExecutor();
            executor.setStreamHandler(new PumpStreamHandler(versionOutput));
            executor.execute(CommandLine.parse(GIT_VERSION_COMMAND));
            String gitVersion = versionOutput.toString(StandardCharsets.UTF_8).trim();
            log.debug("git client reported [{}]", gitVersion);
            return gitVersion;
        }
        catch (IOException e)
        {
            log.debug("Could not run '{}' on this host: {}", GIT_VERSION_COMMAND, e.getMessage());
            return null;
        }
    }

    /**
     * Decides whether a git client honours the GIT_CONFIG_COUNT family of environment variables.
     *
     * @param gitVersion
     *            the output of <code>git --version</code>.
     * @return <code>true</code> when the reported version is at least the minimum that reads configuration from the
     *         environment; <code>false</code> when it is older, or when the output cannot be parsed - an unreadable
     *         version is treated as unsupported so that the host's own configuration is left alone.
     */
    private boolean supportsEnvironmentConfiguration(String gitVersion)
    {
        Matcher versionMatcher = GIT_VERSION_PATTERN.matcher(gitVersion);
        if (!versionMatcher.find())
        {
            return false;
        }

        int major = Integer.parseInt(versionMatcher.group(1));
        int minor = Integer.parseInt(versionMatcher.group(2));

        return major > GIT_ENVIRONMENT_CONFIG_MIN_MAJOR
                || (major == GIT_ENVIRONMENT_CONFIG_MIN_MAJOR && minor >= GIT_ENVIRONMENT_CONFIG_MIN_MINOR);
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

    public String getNpmInstallCommand()
    {
        return npmInstallCommand;
    }

    public void setNpmInstallCommand(String npmInstallCommand)
    {
        this.npmInstallCommand = npmInstallCommand;
    }

    public String getGruntDefaultCommand()
    {
        return gruntDefaultCommand;
    }

    public void setGruntDefaultCommand(String gruntDefaultCommand)
    {
        this.gruntDefaultCommand = gruntDefaultCommand;
    }
}