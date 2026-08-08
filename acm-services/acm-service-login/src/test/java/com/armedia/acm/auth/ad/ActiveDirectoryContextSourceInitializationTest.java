package com.armedia.acm.auth.ad;

/*-
 * #%L
 * ACM Service: User Login and Authentication
 * %%
 * Copyright (C) 2014 - 2026 ArkCase LLC
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
import static org.junit.Assert.fail;

import org.junit.Before;
import org.junit.Test;

import javax.naming.Context;

import java.io.IOException;
import java.io.InputStream;
import java.util.Hashtable;
import java.util.Properties;

/**
 * Initialization tests for {@link ActiveDirectoryAbstractContextSource}.
 *
 * <p>
 * These exist because of a specific regression risk introduced by the Java 17 runtime migration. The
 * initial context factory used to be a class literal compiled into the context source, and the
 * connection pooling flag a String constant beside it; strong encapsulation of the JDK-internal
 * naming provider package made the class literal uncompilable, so both names moved into the login
 * library's own configuration. Bean definitions for this context source are declared outside this
 * repository, in the deployed configuration, and they supply the directory url, the bind account and
 * the search base - never these two JNDI internals. If moving the names out had also dropped their
 * defaults, every one of those definitions would have failed at initialization, because the JNDI
 * environment is a {@link Hashtable} and rejects a null key or value on insertion. Login would have
 * broken on startup.
 * </p>
 *
 * <p>
 * Each test therefore asserts on the assembled JNDI environment rather than on a getter, and none of
 * them contacts a directory server: {@code afterPropertiesSet} builds the environment and stops, so
 * the whole initialization path is observable offline. The concrete
 * {@link ActiveDirectoryContextSource} is used rather than an ad-hoc subclass so that the production
 * class hierarchy is the one under test.
 * </p>
 */
public class ActiveDirectoryContextSourceInitializationTest
{
    private static final String TEST_URL = "ldap://ad_vm:389";

    /**
     * The two names, read from the same configuration resource the production class reads. They are
     * loaded here rather than written out as literals so that this test verifies the wiring between
     * the class and its configuration instead of restating the values and drifting from them.
     */
    private Properties expected;

    private ActiveDirectoryContextSource contextSource;

    @Before
    public void setUp() throws IOException
    {
        expected = new Properties();
        try (InputStream in = ActiveDirectoryAbstractContextSource.class
                .getResourceAsStream("/spring/ldap-jndi.properties"))
        {
            assertNotNull("spring/ldap-jndi.properties must be on the classpath", in);
            expected.load(in);
        }

        contextSource = new ActiveDirectoryContextSource();
        contextSource.setUrl(TEST_URL);
    }

    /**
     * The case every deployed bean definition actually exercises: url, and nothing else. Both JNDI
     * names must resolve from configuration and reach the environment unchanged.
     */
    @Test
    public void initialisesWithoutExplicitJndiWiring() throws Exception
    {
        contextSource.afterPropertiesSet();

        Hashtable<?, ?> env = contextSource.getAnonymousEnv();

        assertEquals(expected.getProperty("ldap.jndi.initialContextFactory"), env.get(Context.INITIAL_CONTEXT_FACTORY));
        assertEquals(TEST_URL, env.get(Context.PROVIDER_URL));
        assertEquals(expected.getProperty("ldap.jndi.initialContextFactory"), contextSource.getContextFactory());
    }

    /**
     * Pooling disabled is the default, and the pooling key must then be absent from the environment
     * rather than present with a false value. This is the assertion that a null pooling key would
     * have made impossible, because removing a null key from a {@link Hashtable} throws.
     */
    @Test
    public void omitsThePoolingKeyWhenPoolingIsDisabled() throws Exception
    {
        contextSource.afterPropertiesSet();

        Hashtable<?, ?> env = contextSource.getAnonymousEnv();

        assertFalse("pooling is disabled by default, so the pooling key must not be in the environment",
                env.containsKey(expected.getProperty("ldap.jndi.connectionPoolFlag")));
    }

    /**
     * Pooling enabled must place the pooling key into the environment under the exact key the naming
     * service recognizes, carrying the same value it carried before the key moved into configuration.
     */
    @Test
    public void addsThePoolingKeyWhenPoolingIsEnabled() throws Exception
    {
        contextSource.setPooled(true);
        contextSource.afterPropertiesSet();

        Hashtable<?, ?> env = contextSource.getAnonymousEnv();

        assertEquals("true", env.get(expected.getProperty("ldap.jndi.connectionPoolFlag")));
    }

    /**
     * An authenticated environment is rebuilt from the anonymous one, so it must carry the same
     * factory name. This covers the path a login actually takes.
     */
    @Test
    public void authenticatedEnvironmentCarriesTheSameFactory() throws Exception
    {
        contextSource.afterPropertiesSet();

        Hashtable<?, ?> env = contextSource.getAuthenticatedEnv("cn=probe", "secret");

        assertEquals(expected.getProperty("ldap.jndi.initialContextFactory"), env.get(Context.INITIAL_CONTEXT_FACTORY));
        assertEquals("cn=probe", env.get(Context.SECURITY_PRINCIPAL));
    }

    /**
     * A bean definition remains free to override either name. An override must win over the default.
     */
    @Test
    public void anExplicitOverrideWins() throws Exception
    {
        contextSource.setContextFactory("com.example.TestCtxFactory");
        contextSource.setConnectionPoolFlag("com.example.connect.pool");
        contextSource.setPooled(true);
        contextSource.afterPropertiesSet();

        Hashtable<?, ?> env = contextSource.getAnonymousEnv();

        assertEquals("com.example.TestCtxFactory", env.get(Context.INITIAL_CONTEXT_FACTORY));
        assertEquals("true", env.get("com.example.connect.pool"));
    }

    /**
     * A blank override must be rejected at initialization, naming the property, rather than reaching
     * the environment assembly and surfacing as a bare NullPointerException out of
     * {@link Hashtable}.
     */
    @Test
    public void aBlankContextFactoryIsRejectedAtInitialisation()
    {
        contextSource.setContextFactory("  ");

        try
        {
            contextSource.afterPropertiesSet();
            fail("a blank contextFactory must be rejected when the context source initialises");
        }
        catch (Exception e)
        {
            assertTrue("the failure must be an IllegalArgumentException, not a NullPointerException",
                    e instanceof IllegalArgumentException);
            assertTrue("the failure must name the offending property, was: " + e.getMessage(),
                    e.getMessage().contains("contextFactory"));
        }
    }

    /**
     * The same contract for the pooling key.
     */
    @Test
    public void aBlankConnectionPoolFlagIsRejectedAtInitialisation()
    {
        contextSource.setConnectionPoolFlag(null);

        try
        {
            contextSource.afterPropertiesSet();
            fail("a blank connectionPoolFlag must be rejected when the context source initialises");
        }
        catch (Exception e)
        {
            assertTrue("the failure must be an IllegalArgumentException, not a NullPointerException",
                    e instanceof IllegalArgumentException);
            assertTrue("the failure must name the offending property, was: " + e.getMessage(),
                    e.getMessage().contains("connectionPoolFlag"));
        }
    }

    /**
     * The migration's central claim about this class, asserted rather than assumed: the configured
     * factory name resolves to a loadable class on the running JVM.
     *
     * <p>
     * This is the whole reason the representation changed. A class literal naming the JDK-internal
     * naming provider no longer compiles, because the module that owns the package does not export
     * it; a lookup of the same class by name still succeeds, because loading is not gated by the
     * export. The name is read from configuration rather than written here, so this test carries no
     * copy of it and cannot drift from the value the production class uses.
     * </p>
     */
    @Test
    public void theConfiguredFactoryNameResolvesOnThisRuntime() throws Exception
    {
        String factoryName = expected.getProperty("ldap.jndi.initialContextFactory");

        Class<?> factory = Class.forName(factoryName);

        assertEquals(factoryName, factory.getName());
    }

    /**
     * The pre-existing url check must keep firing, so that adding the two new checks above has not
     * displaced it or changed the order in which initialization rejects an incomplete definition.
     */
    @Test
    public void aMissingUrlIsStillRejectedFirst()
    {
        ActiveDirectoryContextSource noUrl = new ActiveDirectoryContextSource();

        try
        {
            noUrl.afterPropertiesSet();
            fail("a context source with no server url must be rejected");
        }
        catch (Exception e)
        {
            assertTrue(e instanceof IllegalArgumentException);
            assertTrue("was: " + e.getMessage(), e.getMessage().contains("server url"));
        }
    }
}
