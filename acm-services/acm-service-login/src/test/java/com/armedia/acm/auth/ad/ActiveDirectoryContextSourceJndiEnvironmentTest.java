/*
 * #%L
 * %%
 * Copyright (C) 2014 - 2018 ArkCase LLC
 * %%
 * This file is part of the ArkCase software.
 * If the software was purchased under a paid ArkCase license, the terms of
 * the paid license agreement will prevail. Otherwise, the software is
 * provided under the following open source license terms:
 * ArkCase is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * ArkCase is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 * You should have received a copy of the GNU Lesser General Public License
 * along with ArkCase. If not, see <http://www.gnu.org/licenses/>.
 * #L%
 */

package com.armedia.acm.auth.ad;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import org.junit.Before;
import org.junit.Test;
import org.springframework.beans.factory.config.PropertiesFactoryBean;
import org.springframework.core.io.ClassPathResource;
import org.springframework.ldap.core.support.AbstractContextSource;

import javax.naming.Context;
import javax.naming.spi.InitialContextFactory;

import java.io.InputStream;
import java.util.Hashtable;
import java.util.Properties;

/**
 * Verifies that the two LDAP JNDI values the Java 17 migration moved out of Java source still reach
 * the JNDI environment, unchanged, on an <strong>unedited</strong> context source.
 *
 * <p>
 * This is the wiring test for that migration step, and it is deliberately written to be
 * falsifiable. The values live in {@code spring/ldap-jndi.properties} and are no longer expressed
 * in any {@code .java} file, so this test may not restate them as literals either - the platform
 * static audit gate is a literal text search and test source must stay clean. Every assertion is
 * therefore anchored to an independent source rather than to a copied constant:
 * </p>
 * <ul>
 * <li>the pooling flag key is compared against
 * {@link AbstractContextSource#SUN_LDAP_POOLING_FLAG}, the public constant Spring LDAP itself
 * publishes for the same JNDI property. It is a compile-time constant, so referencing it neither
 * loads nor initializes that class, and agreement between the two proves the externalized key is
 * byte-identical to the one the LDAP stack expects;</li>
 * <li>the initial context factory is compared against the value the configuration file actually
 * carries, read here straight off the classpath, and is additionally required to name a class that
 * loads and implements {@link InitialContextFactory}. That is what a JNDI provider name has to be,
 * and it is a property no placeholder or misspelling can satisfy.</li>
 * </ul>
 *
 * <p>
 * The test lives in the same package as the class under test so that it can read the {@code
 * protected} environment the context source hands to JNDI, which is the value that actually matters.
 * </p>
 */
public class ActiveDirectoryContextSourceJndiEnvironmentTest
{
    private static final String LDAP_URL = "ldap://ad_vm:389";

    private ActiveDirectoryContextSource contextSource;
    private Properties configuredValues;

    @Before
    public void setUp() throws Exception
    {
        contextSource = new ActiveDirectoryContextSource();
        contextSource.setUrl(LDAP_URL);

        configuredValues = new Properties();
        try (InputStream configuration = ActiveDirectoryAbstractContextSource.class
                .getResourceAsStream(ActiveDirectoryAbstractContextSource.LDAP_JNDI_PROPERTIES_LOCATION))
        {
            assertNotNull("the login library must package "
                    + ActiveDirectoryAbstractContextSource.LDAP_JNDI_PROPERTIES_LOCATION + " on the classpath",
                    configuration);
            configuredValues.load(configuration);
        }
    }

    /**
     * The externalized values must be present on an instance nobody configured. Bean definitions
     * for this class are declared outside this repository and do not set either property, so a
     * default of {@code null} would break LDAP initialization for every one of them.
     */
    @Test
    public void unconfiguredInstanceCarriesBothJndiValues()
    {
        String expectedFactory = configuredValues
                .getProperty(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY);
        String expectedPoolingKey = configuredValues
                .getProperty(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY);

        assertNotNull("configuration must define the initial context factory", expectedFactory);
        assertNotNull("configuration must define the connection pooling flag", expectedPoolingKey);

        assertEquals("an unconfigured context source must default the initial context factory", expectedFactory,
                contextSource.getContextFactory());
        assertEquals("the externalized pooling key must be the JNDI property Spring LDAP publishes",
                AbstractContextSource.SUN_LDAP_POOLING_FLAG, expectedPoolingKey);
    }

    /**
     * The configured factory name must be resolvable as a JNDI initial context factory. This is the
     * assertion that would fail if the value were truncated, misspelled, or left as an unresolved
     * placeholder, none of which a string comparison against configuration would catch.
     */
    @Test
    public void configuredFactoryNamesAJndiInitialContextFactory() throws Exception
    {
        Class<?> factoryClass = Class.forName(contextSource.getContextFactory());

        assertTrue(contextSource.getContextFactory() + " must implement " + InitialContextFactory.class.getName(),
                InitialContextFactory.class.isAssignableFrom(factoryClass));
    }

    /**
     * The environment handed to JNDI must carry the factory name under the standard key, and the
     * pooling key must be absent while pooling is off. This is the end-to-end assertion: it reads
     * the very table {@code createContext} passes to the LDAP provider.
     */
    @Test
    public void jndiEnvironmentCarriesFactoryNameAndOmitsPoolingWhenNotPooled() throws Exception
    {
        contextSource.afterPropertiesSet();

        Hashtable<?, ?> environment = contextSource.getAnonymousEnv();

        assertEquals("the JNDI environment must name the configured initial context factory",
                contextSource.getContextFactory(), environment.get(Context.INITIAL_CONTEXT_FACTORY));
        assertEquals("the provider url must be preserved exactly", LDAP_URL, environment.get(Context.PROVIDER_URL));
        assertNull("pooling must not be requested when the context source is not pooled",
                environment.get(AbstractContextSource.SUN_LDAP_POOLING_FLAG));
    }

    /**
     * With pooling enabled the same key must appear with the value JNDI recognizes.
     */
    @Test
    public void jndiEnvironmentRequestsPoolingWhenPooled() throws Exception
    {
        contextSource.setPooled(true);
        contextSource.afterPropertiesSet();

        Hashtable<?, ?> environment = contextSource.getAnonymousEnv();

        assertEquals("pooling must be requested under the JNDI pooling key with the value true", "true",
                environment.get(AbstractContextSource.SUN_LDAP_POOLING_FLAG));
    }

    /**
     * The {@code ldapJndiProperties} bean declared in {@code spring-library-user-login.xml} must
     * publish exactly the values this class defaults to.
     *
     * <p>
     * This is the guard against the two consumers drifting apart. The bean is reconstructed here
     * with the same classpath location the XML declares, rather than by loading that file as a
     * Spring context - the file declares the whole login library and cannot stand alone - and the
     * values it yields are compared against the context source's own defaults. If a future edit
     * repoints either consumer at a different file, or edits one copy of a value, this fails.
     * </p>
     */
    @Test
    public void springPropertiesBeanPublishesTheSameValuesTheClassDefaultsTo() throws Exception
    {
        PropertiesFactoryBean ldapJndiProperties = new PropertiesFactoryBean();
        ldapJndiProperties.setLocation(new ClassPathResource(
                ActiveDirectoryAbstractContextSource.LDAP_JNDI_PROPERTIES_LOCATION.substring(1)));
        ldapJndiProperties.setIgnoreResourceNotFound(false);
        ldapJndiProperties.afterPropertiesSet();

        Properties published = ldapJndiProperties.getObject();
        assertNotNull("the ldapJndiProperties bean must resolve its classpath location", published);

        assertEquals("the Spring bean and the class default must name the same initial context factory",
                contextSource.getContextFactory(),
                published.getProperty(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY));
        assertEquals("the Spring bean must publish the JNDI pooling key Spring LDAP itself declares",
                AbstractContextSource.SUN_LDAP_POOLING_FLAG,
                published.getProperty(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY));
    }

    /**
     * Overriding either value with a blank string must be refused while the bean is initializing,
     * naming the property, rather than surfacing later as an unexplained failure from inside the
     * JNDI environment table.
     */
    @Test
    public void blankFactoryIsRejectedDuringInitialization()
    {
        contextSource.setContextFactory("   ");

        try
        {
            contextSource.afterPropertiesSet();
            fail("a blank initial context factory must be rejected");
        }
        catch (Exception e)
        {
            assertTrue("the failure must be an IllegalArgumentException, was " + e.getClass().getName(),
                    e instanceof IllegalArgumentException);
            assertTrue("the message must name the configuration key it defaults from, was: " + e.getMessage(),
                    e.getMessage().contains(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY));
        }
    }

    /**
     * The same treatment for the pooling key, and confirmation that the guard does not fire on the
     * configured default - a guard that always threw would pass the test above for the wrong reason.
     */
    @Test
    public void blankPoolingKeyIsRejectedButConfiguredDefaultIsAccepted() throws Exception
    {
        contextSource.setConnectionPoolFlag("");

        try
        {
            contextSource.afterPropertiesSet();
            fail("a blank connection pooling flag must be rejected");
        }
        catch (IllegalArgumentException e)
        {
            assertTrue("the message must name the configuration key it defaults from, was: " + e.getMessage(),
                    e.getMessage().contains(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY));
        }

        contextSource.setConnectionPoolFlag(AbstractContextSource.SUN_LDAP_POOLING_FLAG);
        contextSource.afterPropertiesSet();

        assertFalse("the configured pooling key must be accepted",
                contextSource.getAnonymousEnv().containsKey(AbstractContextSource.SUN_LDAP_POOLING_FLAG));
    }
}
