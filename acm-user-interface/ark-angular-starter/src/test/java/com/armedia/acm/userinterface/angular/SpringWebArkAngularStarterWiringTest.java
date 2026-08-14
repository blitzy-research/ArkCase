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
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import com.armedia.acm.core.AcmSpringActiveProfile;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.PropertyValue;
import org.springframework.beans.factory.xml.XmlBeanDefinitionReader;
import org.springframework.context.support.GenericApplicationContext;

import java.beans.PropertyDescriptor;
import java.util.List;

/**
 * Wiring tests for {@code spring/spring-web-ark-angular-starter.xml}, the bean definition that drives the
 * deploy-time front-end assembly.
 * <p>
 * The subject of these tests is the npm migration of that definition: the install property is now
 * {@code npmInstallCommand} carrying {@code npm ci --ignore-scripts --engine-strict} (the yarn invocation and its
 * {@code --ignore-engines} flag are gone), and {@code package-lock.json} replaced {@code yarn.lock} in the list of
 * files copied out of the archive. Both are strings in XML, so nothing in the compiler or in a Java unit test
 * would notice them drifting from the copier they configure - a renamed setter, a mistyped property name or a
 * lockfile name that no longer matches what the copier protects from pruning would all ship silently.
 * <p>
 * The real XML is loaded, not a copy of it. The context is a plain {@link GenericApplicationContext}, which
 * resolves the {@code $[...]} placeholders and the {@code #{...}} expressions exactly as the deployed context
 * does, but deliberately registers no {@code ServletContextAwareProcessor} - so the copier bean is fully
 * populated without {@code setServletContext} firing, and no assembly, npm run or Grunt run is triggered by
 * refreshing it. The one collaborator that lives outside this module, {@code acmSpringActiveProfile}, is
 * registered as a stub singleton before refresh.
 */
public class SpringWebArkAngularStarterWiringTest
{
    private static final String CONTEXT_LOCATION = "classpath:spring/spring-web-ark-angular-starter.xml";
    private static final String COPIER_BEAN_NAME = "angularResourceCopier";
    private static final String ACTIVE_PROFILE_BEAN_NAME = "acmSpringActiveProfile";

    private GenericApplicationContext applicationContext;
    private AngularResourceCopier angularResourceCopier;

    @Before
    public void setUp()
    {
        applicationContext = new GenericApplicationContext();
        applicationContext.getBeanFactory().registerSingleton(ACTIVE_PROFILE_BEAN_NAME, new AcmSpringActiveProfile()
        {
            @Override
            public String[] getActiveProfiles()
            {
                return new String[] { "ldap" };
            }
        });
        new XmlBeanDefinitionReader(applicationContext).loadBeanDefinitions(CONTEXT_LOCATION);
        applicationContext.refresh();

        angularResourceCopier = applicationContext.getBean(COPIER_BEAN_NAME, AngularResourceCopier.class);
    }

    @After
    public void tearDown()
    {
        applicationContext.close();
    }

    /**
     * The install step the deployed application runs is {@code npm ci --ignore-scripts --engine-strict}, resolved
     * through the renamed property. {@code npm ci} is the reproducible install against the committed lockfile;
     * {@code --ignore-scripts} is required because one git-sourced asset dependency's {@code prepare} script tries
     * to build a native module that cannot compile on Node 20; and {@code --engine-strict} makes npm refuse an
     * out-of-range runtime instead of emitting an EBADENGINE warning and installing anyway, which is what turns
     * the manifest's declared {@code engines} range into a deploy-time precondition. The flag is asserted here as
     * well as carried by the copied {@code .npmrc}, so the range is enforced even if the staged file were missing.
     */
    @Test
    public void npmInstallCommandIsWiredToNpmCiIgnoringScriptsAndEnforcingEngines()
    {
        assertEquals(commandPrefix() + "npm ci --ignore-scripts --engine-strict",
                angularResourceCopier.getNpmInstallCommand());
    }

    /**
     * No yarn invocation survives anywhere in this definition - not in the install command, not in either Grunt
     * command, and not in the copy list. In particular {@code --ignore-engines}, which used to suppress engine
     * enforcement at deploy time, must be gone: the manifest now declares Node 20 and npm 10 and that declaration
     * has to be enforced.
     */
    @Test
    public void noYarnInvocationOrEngineSuppressionRemains()
    {
        assertFalse(angularResourceCopier.getNpmInstallCommand().contains("yarn"));
        assertFalse(angularResourceCopier.getNpmInstallCommand().contains("--ignore-engines"));
        assertFalse(angularResourceCopier.getGruntDefaultCommand().contains("yarn"));
        assertFalse(angularResourceCopier.getMergeConfigFrontendTask().contains("yarn"));

        for (String fileToCopy : angularResourceCopier.getFilesToCopyFromArchive())
        {
            assertFalse("no yarn artefact may be copied out of the archive: " + fileToCopy,
                    fileToCopy.contains("yarn"));
        }
    }

    /**
     * The npm lockfile has to be copied out of the archive, because {@code npm ci} refuses to run without one and
     * the name has to be exactly the one the copier's prune step protects.
     */
    @Test
    public void npmLockfileIsCopiedOutOfTheArchiveAlongsideTheManifest()
    {
        List<String> filesToCopy = angularResourceCopier.getFilesToCopyFromArchive();

        assertTrue("npm ci validates against package-lock.json, so it must be copied",
                filesToCopy.contains("package-lock.json"));
        assertTrue(filesToCopy.contains("package.json"));
        assertTrue(filesToCopy.contains("Gruntfile.js"));
        assertTrue(".npmrc carries engine-strict, so the temp-folder install enforces the declared runtime range",
                filesToCopy.contains(".npmrc"));
    }

    /**
     * The two Grunt commands are unchanged by the migration and still resolve through the locally installed
     * binary: the default build, and the per-profile config merge.
     */
    @Test
    public void gruntCommandsRemainWiredToTheLocalBinary()
    {
        assertEquals(commandPrefix() + commandPath() + "grunt" + commandSuffix() + " --no-color",
                angularResourceCopier.getGruntDefaultCommand());
        assertEquals(commandPrefix() + commandPath() + "grunt" + commandSuffix() + " updateModulesConfig --no-color",
                angularResourceCopier.getMergeConfigFrontendTask());
    }

    /**
     * Every property this XML sets must exist as a writable property on the copier. Spring would refuse to
     * refresh a context with a stale property name, so this assertion is here to say WHICH name broke rather than
     * leaving a reader of the failure to work it out - and to keep the guard explicit if the definition is ever
     * loaded more leniently.
     */
    @Test
    public void everyPropertyTheXmlSetsExistsOnTheCopier()
    {
        PropertyValue[] propertyValues = applicationContext.getBeanFactory().getBeanDefinition(COPIER_BEAN_NAME)
                .getPropertyValues().getPropertyValues();

        assertTrue("the copier definition must configure the assembly", propertyValues.length > 0);

        for (PropertyValue propertyValue : propertyValues)
        {
            PropertyDescriptor descriptor = BeanUtils.getPropertyDescriptor(AngularResourceCopier.class,
                    propertyValue.getName());
            assertNotNull("the XML sets a property the copier does not declare: " + propertyValue.getName(),
                    descriptor);
            assertNotNull("the XML sets a property with no setter: " + propertyValue.getName(),
                    descriptor.getWriteMethod());
        }
    }

    /**
     * Mirrors the {@code frontEndCommandPrefix} expression in the XML so these assertions hold on every platform
     * the build runs on rather than only on the one that happens to run them.
     */
    private String commandPrefix()
    {
        return isWindows() ? "cmd /C " : "";
    }

    private String commandPath()
    {
        if ("true".equals(System.getProperty("arkcase.external.bower-grunt")))
        {
            return "";
        }
        return isWindows() ? "node_modules\\.bin\\" : "node_modules/.bin/";
    }

    private String commandSuffix()
    {
        return isWindows() ? ".cmd" : "";
    }

    private boolean isWindows()
    {
        return System.getProperty("os.name").startsWith("Windows");
    }
}
