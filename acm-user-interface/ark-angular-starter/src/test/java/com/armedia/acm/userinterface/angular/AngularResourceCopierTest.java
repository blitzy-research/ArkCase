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

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.armedia.acm.core.AcmSpringActiveProfile;

import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.springframework.mock.web.MockServletContext;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Unit tests for the deploy-time front-end assembly driven by {@link AngularResourceCopier}.
 * <p>
 * The subject of these tests is the npm migration of that assembly: the install command the copier runs is now
 * {@code npm ci --ignore-scripts --engine-strict} instead of a yarn invocation, it is injected through the renamed
 * {@code npmInstallCommand} property, and {@code package-lock.json} - which npm owns and which is not copied out
 * of the archive on every run - has to survive the temp-folder prune that deletes anything the copier did not
 * place there itself. None of that is checkable by the compiler, so it is pinned here.
 * <p>
 * The ordering assertion is the important one. The install must run BEFORE {@code profiles.js} is generated, and
 * Grunt must run AFTER it, because the Grunt configuration requires that module: if the sequence were ever
 * reordered, a deployment would fail at Grunt time with an opaque module-not-found error. The test records, at
 * the moment each front-end command is invoked, whether {@code profiles.js} was on disk yet - so the ordering is
 * observed rather than inferred from the call list.
 * <p>
 * No real process is ever launched: the seam
 * {@link AngularResourceCopier#runFrontEndBuildCommand(File, String)} is overridden by a recording subclass - every
 * front-end command the assembly runs goes through it, so all of them are captured and neither npm nor Grunt has to
 * exist for these tests to run.
 */
public class AngularResourceCopierTest
{
    private static final String NPM_INSTALL_COMMAND = "npm ci --ignore-scripts --engine-strict";
    private static final String GRUNT_DEFAULT_COMMAND = "node_modules/.bin/grunt --no-color";
    private static final String MERGE_CONFIG_COMMAND = "node_modules/.bin/grunt updateModulesConfig --no-color";
    private static final String LOCK_FILE_NAME = "package-lock.json";
    private static final String PROFILES_FILE_NAME = "profiles.js";

    /**
     * Rooted at the CANONICAL temporary directory on purpose: the prune step compares canonical paths (the ones
     * it recorded while copying) against absolute paths (the ones it finds on disk), so a symlinked temporary
     * directory would make the assertions below about symlink resolution instead of about pruning.
     */
    @Rule
    public TemporaryFolder temporaryFolder = new TemporaryFolder(canonicalTemporaryDirectory());

    private File webappFolder;
    private File tempFolder;
    private File deployFolder;
    private RecordingAngularResourceCopier angularResourceCopier;

    @Before
    public void setUp() throws Exception
    {
        // the copier resolves "/resources" out of the servlet context and needs it to be a real directory
        webappFolder = temporaryFolder.newFolder("webapp");
        new File(webappFolder, AngularResourceConstants.WAR_ANGULAR_RESOURCE_PATH.substring(1)).mkdirs();

        tempFolder = temporaryFolder.newFolder("arkcase-tmp");
        deployFolder = new File(temporaryFolder.getRoot(), "arkcase-custom");

        angularResourceCopier = new RecordingAngularResourceCopier(tempFolder);
        angularResourceCopier.setTempFolderPath(tempFolder.getAbsolutePath());
        angularResourceCopier.setDeployFolderPath(deployFolder.getAbsolutePath());
        angularResourceCopier.setNpmInstallCommand(NPM_INSTALL_COMMAND);
        angularResourceCopier.setGruntDefaultCommand(GRUNT_DEFAULT_COMMAND);
        angularResourceCopier.setMergeConfigFrontendTask(MERGE_CONFIG_COMMAND);
        // the copy lists are exercised by the Spring wiring test; here they are empty so the assembly sequence
        // itself is what is under test, with no archive resources to resolve
        angularResourceCopier.setResourceFoldersToCopyFromArchive(Collections.emptyList());
        angularResourceCopier.setFilesToCopyFromArchive(Collections.emptyList());
        angularResourceCopier.setCustomResourceSourcesToCopyFromArchive(Collections.emptyList());
        angularResourceCopier.setAssembledFoldersToCopyToDeployment(Collections.emptyList());
        angularResourceCopier.setAssembledFilesToCopyToDeployment(Collections.emptyList());
        angularResourceCopier.setSpringActiveProfile(activeProfiles("ldap"));
    }

    /**
     * The renamed property is readable under its new name - the guard against the Spring XML and the accessor
     * drifting apart, since the XML sets this property by name and nothing else would catch a rename.
     */
    @Test
    public void npmInstallCommandIsReadableUnderItsNewName()
    {
        assertEquals(NPM_INSTALL_COMMAND, angularResourceCopier.getNpmInstallCommand());
    }

    /**
     * The assembly must run the injected install command first, then the per-profile config merge, then the
     * default Grunt build - and {@code profiles.js} must already exist by the time the last two run.
     */
    @Test
    public void assemblyRunsNpmInstallThenGeneratesProfilesThenRunsGrunt()
    {
        angularResourceCopier.copyAngularResources(servletContext());

        assertEquals(Arrays.asList(NPM_INSTALL_COMMAND, MERGE_CONFIG_COMMAND, GRUNT_DEFAULT_COMMAND),
                angularResourceCopier.getExecutedCommands());
        assertEquals("the install must run before profiles.js exists", Arrays.asList(false, true, true),
                angularResourceCopier.getProfilesFilePresentPerCommand());
    }

    /**
     * The generated module is exactly what the front-end expects: {@code module.exports = { profiles: [ 'custom'
     * ] };} with no trailing newline. The single default profile is what an install without an extension profile
     * resolves to.
     */
    @Test
    public void profilesModuleIsGeneratedWithTheDefaultProfile() throws Exception
    {
        angularResourceCopier.copyAngularResources(servletContext());

        File profilesFile = new File(tempFolder, PROFILES_FILE_NAME);
        assertTrue(profilesFile.isFile());
        assertEquals("module.exports = { profiles: [ 'custom' ] };",
                new String(Files.readAllBytes(profilesFile.toPath()), StandardCharsets.UTF_8));
    }

    /**
     * With an extension profile active, that profile is merged ahead of {@code custom} and the config-merge
     * command runs once per profile - so the recorded sequence grows by exactly one merge, still bracketed by the
     * install and the Grunt build.
     */
    @Test
    public void extensionProfileIsAssembledAheadOfCustom() throws Exception
    {
        angularResourceCopier.setSpringActiveProfile(activeProfiles("ldap", "extension-foia"));

        angularResourceCopier.copyAngularResources(servletContext());

        assertEquals(
                Arrays.asList(NPM_INSTALL_COMMAND, MERGE_CONFIG_COMMAND, MERGE_CONFIG_COMMAND,
                        GRUNT_DEFAULT_COMMAND),
                angularResourceCopier.getExecutedCommands());
        assertEquals("module.exports = { profiles: [ 'foia', 'custom' ] };",
                new String(Files.readAllBytes(new File(tempFolder, PROFILES_FILE_NAME).toPath()),
                        StandardCharsets.UTF_8));
    }

    /**
     * The prune step deletes everything in the temp folder that the copier did not put there, which is how files
     * removed from the project stop lingering in a long-lived deployment. {@code package-lock.json} is written by
     * npm rather than copied from the archive, so it is explicitly protected - and this test is what keeps that
     * protection honest: the lockfile must survive while a genuinely stale sibling is removed. The npm-managed
     * folders are protected the same way.
     */
    @Test
    public void pruneKeepsTheNpmLockfileAndNodeModulesButRemovesStaleFiles() throws Exception
    {
        File lockFile = writeTempFile(LOCK_FILE_NAME, "{ \"lockfileVersion\": 3 }");
        File staleFile = writeTempFile("removed-from-the-project.js", "// no longer in the archive");
        File nodeModulesFile = writeTempFile("node_modules/some-package/index.js", "// installed by npm");
        File libFile = writeTempFile("lib/json8/json8.js", "// first-party in-repo library");

        angularResourceCopier.copyAngularResources(servletContext());

        assertTrue("npm owns package-lock.json; the prune must not delete it", lockFile.isFile());
        assertTrue("npm owns node_modules; the prune must not delete it", nodeModulesFile.isFile());
        assertTrue("the lib folder is protected by path prefix", libFile.isFile());
        assertFalse("a file the copier did not place must be pruned", staleFile.exists());
        assertTrue("the generated profiles module must survive its own prune",
                new File(tempFolder, PROFILES_FILE_NAME).isFile());
    }

    /**
     * A servlet context whose document root is the fake exploded webapp. The base path is given as a
     * {@code file:} URL deliberately: {@link MockServletContext} resolves its base path through a
     * {@code FileSystemResourceLoader}, which treats a bare leading-slash path as relative to the working
     * directory, so {@code getRealPath("/resources")} would come back null and the copier would abort with "web
     * application archive not expanded?".
     */
    private MockServletContext servletContext()
    {
        return new MockServletContext("file:" + webappFolder.getAbsolutePath());
    }

    private File writeTempFile(String relativeName, String content) throws Exception
    {
        File file = new File(tempFolder, relativeName);
        file.getParentFile().mkdirs();
        Files.write(file.toPath(), content.getBytes(StandardCharsets.UTF_8));
        return file;
    }

    private static File canonicalTemporaryDirectory()
    {
        try
        {
            return new File(System.getProperty("java.io.tmpdir")).getCanonicalFile();
        }
        catch (IOException e)
        {
            throw new IllegalStateException("cannot resolve the temporary directory", e);
        }
    }

    /**
     * An {@link AcmSpringActiveProfile} that reports the supplied profiles without needing a Spring
     * {@link org.springframework.core.env.Environment}.
     */
    private AcmSpringActiveProfile activeProfiles(String... profiles)
    {
        return new AcmSpringActiveProfile()
        {
            @Override
            public String[] getActiveProfiles()
            {
                return profiles;
            }
        };
    }

    /**
     * Records every front-end command instead of executing it, together with whether {@code profiles.js} existed
     * at that moment, which is what makes the install/generate/build ordering observable.
     */
    private static class RecordingAngularResourceCopier extends AngularResourceCopier
    {
        private final File tempFolder;
        private final List<String> executedCommands = new ArrayList<>();
        private final List<Boolean> profilesFilePresentPerCommand = new ArrayList<>();

        RecordingAngularResourceCopier(File tempFolder)
        {
            this.tempFolder = tempFolder;
        }

        /**
         * The single command seam: every front-end command the assembly runs - the npm install and both Grunt
         * invocations - goes through this method. Overriding it therefore intercepts all of them, so no npm or
         * Grunt process is ever launched by this suite.
         */
        @Override
        public void runFrontEndBuildCommand(File tmpDir, String commandLine)
        {
            executedCommands.add(commandLine);
            profilesFilePresentPerCommand.add(new File(tempFolder, PROFILES_FILE_NAME).isFile());
        }

        List<String> getExecutedCommands()
        {
            return executedCommands;
        }

        List<Boolean> getProfilesFilePresentPerCommand()
        {
            return profilesFilePresentPerCommand;
        }
    }
}
