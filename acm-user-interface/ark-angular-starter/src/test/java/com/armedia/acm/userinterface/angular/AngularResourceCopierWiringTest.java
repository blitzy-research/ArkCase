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
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;
import org.springframework.context.support.ClassPathXmlApplicationContext;

/**
 * Coverage for the production wiring of the startup frontend build.
 * <p>
 * The runtime contract of this library is expressed almost entirely in its Spring context: which package manager runs,
 * which lockfile is carried into the staging folder, and which runtime major versions the build insists on. A typo in
 * any of those is invisible until a deployment starts, and a deployment is the only place that wiring is exercised.
 * These assertions read the real context - imported unchanged by the test context - and pin the values that matter.
 */
public class AngularResourceCopierWiringTest
{
    private static ClassPathXmlApplicationContext context;

    @BeforeClass
    public static void loadContext()
    {
        context = new ClassPathXmlApplicationContext("spring/angular-starter-wiring-test-context.xml");
    }

    @AfterClass
    public static void closeContext()
    {
        if (context != null)
        {
            context.close();
        }
    }

    /**
     * The context must initialise at all. Every placeholder in it has to resolve, including the two launcher paths,
     * which resolve to an empty value when no absolute launcher has been configured.
     */
    @Test
    public void contextInitialisesAndDefinesTheCopier()
    {
        assertNotNull(context.getBean("angularResourceCopier", AngularResourceCopier.class));
    }

    /**
     * The install command must be the lockfile-respecting one. A plain install would resolve the dependency graph
     * afresh and could produce a tree the committed lockfile does not describe.
     */
    @Test
    public void installsFromTheCommittedLockfile()
    {
        String install = copier().getYarnInstallCommand().trim();

        assertTrue("the install must be the clean, lockfile-driven form, but was: " + install,
                install.endsWith("npm ci"));
    }

    /**
     * The lockfile itself must be carried into the staging folder, or the install has nothing to read.
     */
    @Test
    public void carriesTheLockfileIntoTheStagingFolder()
    {
        assertTrue("package-lock.json must be copied out of the archive",
                copier().getFilesToCopyFromArchive().contains("package-lock.json"));
        assertTrue("the manifest must be copied out of the archive",
                copier().getFilesToCopyFromArchive().contains("package.json"));
        assertTrue("the superseded lockfile must not be copied any more",
                !copier().getFilesToCopyFromArchive().contains("yarn.lock"));
    }

    /**
     * The runtime versions the build refuses to run without. These are the values that make the Node 20 requirement
     * real at runtime rather than merely declared in the manifest, so they are pinned here.
     */
    @Test
    public void enforcesTheRuntimeMajorVersions()
    {
        assertEquals(20, copier().getRequiredNodeMajorVersion());
        assertEquals(10, copier().getRequiredNpmMajorVersion());
    }

    /**
     * The launcher paths are optional, so they must resolve to a usable empty value rather than to an unresolved
     * placeholder, which would then be treated as a file name.
     */
    @Test
    public void launcherPathsResolveEvenWhenNotConfigured()
    {
        assertNotNull(copier().getNodeExecutablePath());
        assertNotNull(copier().getNpmExecutablePath());
        assertTrue("an unconfigured launcher path must not leave a placeholder behind: "
                + copier().getNodeExecutablePath(), !copier().getNodeExecutablePath().contains("$["));
        assertTrue("an unconfigured launcher path must not leave a placeholder behind: "
                + copier().getNpmExecutablePath(), !copier().getNpmExecutablePath().contains("$["));
    }

    /**
     * Grunt is retained by design, so its two invocations must still be wired.
     */
    @Test
    public void retainsTheGruntPipeline()
    {
        assertTrue(copier().getGruntDefaultCommand().contains("grunt"));
        assertTrue(copier().getMergeConfigFrontendTask().contains("updateModulesConfig"));
    }

    private AngularResourceCopier copier()
    {
        return context.getBean("angularResourceCopier", AngularResourceCopier.class);
    }
}
