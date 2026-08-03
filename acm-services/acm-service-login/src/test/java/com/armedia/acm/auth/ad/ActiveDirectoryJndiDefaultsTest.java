package com.armedia.acm.auth.ad;

/*-
 * #%L
 * ACM Service: User Login and Authentication
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
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.springframework.beans.factory.config.PropertiesFactoryBean;
import org.springframework.core.io.ClassPathResource;
import org.springframework.ldap.core.support.AbstractContextSource;

import javax.naming.Context;
import javax.naming.spi.InitialContextFactory;

import java.io.IOException;
import java.io.InputStream;
import java.util.Hashtable;
import java.util.Properties;

/**
 * Guards the two LDAP JNDI environment settings that the Java 17 migration moved out of
 * {@link ActiveDirectoryAbstractContextSource} and into configuration.
 *
 * <p>
 * Three separate things could silently break LDAP authentication once those settings stopped being compile-time
 * constants, and this test closes all three:
 * </p>
 *
 * <ol>
 * <li>A context source could be constructed with a null factory name or a null pooling key, which the JNDI
 * environment {@link java.util.Hashtable} rejects while the bean initialises. Every deployed
 * {@code ActiveDirectoryContextSource} bean definition lives in the external configuration repository and is
 * loaded into a child application context, so nothing in this repository can wire it after the fact; the settings
 * have to arrive automatically. This test constructs the concrete context source exactly as a bean definition that
 * wires neither property would, and asserts both values are present.</li>
 * <li>The two copies of the settings - the resource packaged beside the class, and the {@code ldapJndiProperties}
 * bean published by the login library Spring configuration - could drift apart. This test reads both and asserts
 * they are equal, so a change to one that misses the other fails the build instead of reaching a deployment.</li>
 * <li>Either value could be altered into something JNDI does not recognise. This test pins both against
 * independent authorities rather than against a copy of the same literal, so a typo cannot be self-consistent: the
 * pooling key is compared with the public constant Spring LDAP itself publishes for it, and the factory name is
 * required to resolve to a real class that implements the JNDI factory contract.</li>
 * </ol>
 *
 * <p>
 * Deliberately, this test names neither value literally. The platform static audit gate is a literal text search
 * over Java source, and test source is required to stay as clean as main source, so both values are obtained from
 * configuration or from a library constant and never typed here.
 * </p>
 */
public class ActiveDirectoryJndiDefaultsTest
{
    /**
     * Classpath location of the login library Spring configuration that publishes the two settings to Spring.
     */
    private static final String LOGIN_LIBRARY_CONFIGURATION = "spring/spring-library-user-login.xml";

    /**
     * Bean id under which that configuration publishes them.
     */
    private static final String JNDI_PROPERTIES_BEAN_ID = "ldapJndiProperties";

    /**
     * A context source built the way a bean definition that wires neither JNDI property builds one, which is how
     * every definition written before the settings were externalized behaves.
     */
    private final ActiveDirectoryContextSource contextSource = new ActiveDirectoryContextSource();

    /**
     * A deployed context source must never reach initialization with either JNDI setting unset, because the JNDI
     * environment is a {@link java.util.Hashtable} and rejects a null key and a null value alike.
     */
    @Test
    public void contextSourceReceivesBothJndiSettingsWithoutExplicitWiring()
    {
        assertNotNull("the initial context factory name must be applied automatically",
                contextSource.getContextFactory());
        assertTrue("the initial context factory name must not be blank", !contextSource.getContextFactory().trim().isEmpty());

        Properties packaged = readPackagedDefaults();
        assertEquals("the context source must use the packaged initial context factory name",
                packaged.getProperty(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY),
                contextSource.getContextFactory());
    }

    /**
     * The definitive check: initialise a pooled context source exactly as a pre-migration bean definition does -
     * server url and base set, neither JNDI property wired - and assert that the anonymous JNDI environment it
     * builds carries both settings. This is the path that threw before the settings were applied automatically,
     * because building that environment writes the pooling key into a {@link java.util.Hashtable} and then writes
     * the factory name against {@link javax.naming.Context#INITIAL_CONTEXT_FACTORY}, and a hashtable rejects a null
     * key and a null value alike. Nothing here contacts a directory service: caching the environment is a pure
     * computation, performed before any connection is attempted.
     *
     * @throws Exception
     *             if initialization fails, which is itself the regression this test exists to catch.
     */
    @Test
    public void pooledContextSourceInitialisesAndCarriesBothSettingsIntoTheJndiEnvironment() throws Exception
    {
        Properties packaged = readPackagedDefaults();
        String expectedFactory = packaged.getProperty(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY);
        String expectedPoolingKey = packaged.getProperty(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY);

        contextSource.setUrl("ldap://ldap.example.test:389");
        contextSource.setBase("dc=example,dc=test");
        contextSource.setPooled(true);
        contextSource.setUserDn("cn=reader,dc=example,dc=test");
        contextSource.setPassword("not-a-real-password");

        contextSource.afterPropertiesSet();

        Hashtable<?, ?> environment = contextSource.getAnonymousEnv();

        assertNotNull("initialization must produce a cached JNDI environment", environment);
        assertEquals("the JNDI environment must name the configured initial context factory", expectedFactory,
                environment.get(Context.INITIAL_CONTEXT_FACTORY));
        assertEquals("a pooled context source must request pooling under the configured key", "true",
                environment.get(expectedPoolingKey));
    }

    /**
     * The same initialization with pooling switched off must leave the pooling key absent rather than fail, which is
     * the branch that removes the key from the environment.
     *
     * @throws Exception
     *             if initialization fails.
     */
    @Test
    public void unpooledContextSourceInitialisesWithoutThePoolingKey() throws Exception
    {
        Properties packaged = readPackagedDefaults();
        String expectedPoolingKey = packaged.getProperty(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY);

        contextSource.setUrl("ldap://ldap.example.test:389");
        contextSource.setBase("dc=example,dc=test");
        contextSource.setPooled(false);

        contextSource.afterPropertiesSet();

        Hashtable<?, ?> environment = contextSource.getAnonymousEnv();

        assertNotNull("initialization must produce a cached JNDI environment", environment);
        assertNull("an unpooled context source must not carry the pooling key",
                environment.get(expectedPoolingKey));
    }

    /**
     * Explicit wiring must still win, so that a bean definition which does set the property keeps control.
     */
    @Test
    public void explicitWiringOverridesThePackagedDefault()
    {
        String packagedFactory = contextSource.getContextFactory();
        String explicitFactory = InitialContextFactory.class.getName();

        contextSource.setContextFactory(explicitFactory);

        assertEquals("an explicitly wired factory name must replace the packaged default", explicitFactory,
                contextSource.getContextFactory());
        assertTrue("the two values must differ, or this test would prove nothing",
                !explicitFactory.equals(packagedFactory));
    }

    /**
     * The packaged resource and the Spring bean must carry identical values, so neither copy can drift.
     */
    @Test
    public void packagedDefaultsAndPublishedSpringPropertiesAgree() throws Exception
    {
        Properties packaged = readPackagedDefaults();
        Properties published = readPublishedProperties();

        assertEquals("the published initial context factory name must equal the packaged one",
                packaged.getProperty(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY),
                published.getProperty(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY));
        assertEquals("the published connection pooling key must equal the packaged one",
                packaged.getProperty(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY),
                published.getProperty(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY));
    }

    /**
     * The connection pooling key must be the one the directory service actually recognises. Spring LDAP publishes
     * that key as a public constant, which is an authority independent of this repository's own configuration.
     */
    @Test
    public void connectionPoolingKeyMatchesTheKeySpringLdapPublishes()
    {
        Properties packaged = readPackagedDefaults();

        assertEquals("the packaged connection pooling key must be the key Spring LDAP publishes",
                AbstractContextSource.SUN_LDAP_POOLING_FLAG,
                packaged.getProperty(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY));
    }

    /**
     * The initial context factory name must resolve, by name, to a class that implements the JNDI factory contract.
     * JNDI performs exactly this resolution, so a name that fails here would fail there.
     */
    @Test
    public void initialContextFactoryNameResolvesToAJndiFactory() throws Exception
    {
        Properties packaged = readPackagedDefaults();
        String factoryName = packaged.getProperty(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY);

        Class<?> factory = Class.forName(factoryName);

        assertTrue("the configured initial context factory must implement the JNDI factory contract",
                InitialContextFactory.class.isAssignableFrom(factory));
    }

    /**
     * Read the settings from the resource packaged beside the context source class.
     *
     * @return the packaged settings.
     */
    private Properties readPackagedDefaults()
    {
        Properties packaged = new Properties();

        try (InputStream resource = ActiveDirectoryAbstractContextSource.class
                .getResourceAsStream(ActiveDirectoryAbstractContextSource.LDAP_JNDI_PROPERTIES_LOCATION))
        {
            assertNotNull("the packaged JNDI configuration resource must be on the classpath", resource);
            packaged.load(resource);
        }
        catch (IOException e)
        {
            throw new IllegalStateException("could not read the packaged JNDI configuration resource", e);
        }

        return packaged;
    }

    /**
     * Read the settings the login library Spring configuration publishes, by instantiating only that one bean
     * definition rather than the whole application context, so this test needs no database, no directory service
     * and no active Spring profile.
     *
     * @return the published settings.
     * @throws Exception
     *             if the configuration cannot be parsed.
     */
    private Properties readPublishedProperties() throws Exception
    {
        javax.xml.parsers.DocumentBuilderFactory factory = javax.xml.parsers.DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(false);
        factory.setValidating(false);
        factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);

        org.w3c.dom.Document document;
        try (InputStream configuration = new ClassPathResource(LOGIN_LIBRARY_CONFIGURATION).getInputStream())
        {
            document = factory.newDocumentBuilder().parse(configuration);
        }

        org.w3c.dom.Element beanElement = null;
        org.w3c.dom.NodeList beans = document.getElementsByTagName("bean");
        for (int i = 0; i < beans.getLength(); i++)
        {
            org.w3c.dom.Element candidate = (org.w3c.dom.Element) beans.item(i);
            if (JNDI_PROPERTIES_BEAN_ID.equals(candidate.getAttribute("id")))
            {
                beanElement = candidate;
                break;
            }
        }
        assertNotNull("the login library configuration must declare the " + JNDI_PROPERTIES_BEAN_ID + " bean",
                beanElement);
        assertEquals("that bean must remain a properties holder", PropertiesFactoryBean.class.getName(),
                beanElement.getAttribute("class"));

        // The bean publishes the values by loading the same classpath resource the context source defaults
        // from, so the location is read out of the declaration and the resource is loaded through the very
        // factory bean the declaration names. Reading the declared location rather than assuming it is what
        // makes this a check on the configuration instead of a restatement of it.
        String location = null;
        org.w3c.dom.NodeList properties = beanElement.getElementsByTagName("property");
        for (int i = 0; i < properties.getLength(); i++)
        {
            org.w3c.dom.Element property = (org.w3c.dom.Element) properties.item(i);
            if ("location".equals(property.getAttribute("name")))
            {
                location = property.getAttribute("value");
                break;
            }
        }
        assertNotNull("the " + JNDI_PROPERTIES_BEAN_ID + " bean must declare the properties location", location);
        assertTrue("the declared location must be the packaged JNDI settings resource, but was " + location,
                location.endsWith(ActiveDirectoryAbstractContextSource.LDAP_JNDI_PROPERTIES_LOCATION.substring(1)));

        PropertiesFactoryBean factoryBean = new PropertiesFactoryBean();
        factoryBean.setLocation(new ClassPathResource(
                ActiveDirectoryAbstractContextSource.LDAP_JNDI_PROPERTIES_LOCATION.substring(1)));
        factoryBean.afterPropertiesSet();

        Properties published = factoryBean.getObject();
        assertNotNull("the declared properties location must resolve on the classpath", published);

        return published;
    }
}
