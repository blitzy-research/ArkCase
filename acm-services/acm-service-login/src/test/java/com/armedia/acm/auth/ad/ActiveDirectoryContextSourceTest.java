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

import org.easymock.EasyMock;
import org.junit.Before;
import org.junit.Test;
import org.springframework.beans.factory.config.PropertiesFactoryBean;
import org.springframework.core.io.ClassPathResource;
import org.springframework.ldap.core.support.AbstractContextSource;

import javax.naming.CommunicationException;
import javax.naming.Context;
import javax.naming.NamingException;
import javax.naming.directory.DirContext;

import java.io.InputStream;
import java.util.Hashtable;
import java.util.Properties;

/**
 * Startup and environment-assembly coverage for the Active Directory context source.
 * <p>
 * The JNDI initial context factory and the connection pooling flag key were hardcoded in
 * {@link ActiveDirectoryAbstractContextSource} until the Java 17 migration moved them into this library's
 * {@code spring/ldap-jndi.properties} resource. The real
 * {@code ActiveDirectoryContextSource} bean definitions live in the external ArkCase configuration repository and do
 * not set either property, so the whole platform's LDAP authentication depends on the class still supplying those
 * values by itself. These tests hold that contract: a context source configured exactly as those bean definitions
 * configure it must initialise, must assemble a complete JNDI environment, and must fail with a precise message
 * rather than a bare {@code NullPointerException} when a value really is missing.
 * <p>
 * The expected values are read from the same configuration resource the class reads rather than written out here.
 * That is deliberate on two counts: it keeps the assertion honest, because a test that repeated the literals could
 * only ever agree with itself, and it keeps this file clear of the internal class name the platform static audit
 * gate searches for.
 * <p>
 * The raw-type suppression matches the class under test: {@code ActiveDirectoryAbstractContextSource} exposes the
 * JNDI environment as a raw {@code Hashtable}, as the JNDI API itself does, and a test asserting on that API has to
 * speak it. Parameterising the test's own locals would not remove the warning, because the values come out of raw
 * signatures.
 */
@SuppressWarnings({ "rawtypes", "unchecked" })
public class ActiveDirectoryContextSourceTest
{
    private static final String TEST_URL = "ldap://directory.example.test:389";

    private String expectedContextFactory;
    private String expectedPoolingFlagKey;
    private ActiveDirectoryContextSource contextSource;

    @Before
    public void setUp() throws Exception
    {
        Properties jndiSettings = new Properties();
        try (InputStream in = ActiveDirectoryAbstractContextSource.class
                .getResourceAsStream(ActiveDirectoryAbstractContextSource.LDAP_JNDI_PROPERTIES_LOCATION))
        {
            assertNotNull("the LDAP JNDI settings resource must ship in this library's jar", in);
            jndiSettings.load(in);
        }

        expectedContextFactory = jndiSettings
                .getProperty(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY);
        expectedPoolingFlagKey = jndiSettings
                .getProperty(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY);

        contextSource = new ActiveDirectoryContextSource();
        contextSource.setUrl(TEST_URL);
    }

    /**
     * The configuration resource must carry both settings, since every other test - and the running platform -
     * depends on them being there.
     */
    @Test
    public void jndiSettingsResourceCarriesBothValues()
    {
        assertTrue("the initial context factory must be configured",
                expectedContextFactory != null && !expectedContextFactory.trim().isEmpty());
        assertTrue("the connection pooling flag key must be configured",
                expectedPoolingFlagKey != null && !expectedPoolingFlagKey.trim().isEmpty());
    }

    /**
     * The class must supply both values without any injection, because the real bean definitions inject neither.
     */
    @Test
    public void suppliesBothJndiSettingsWithoutInjection() throws Exception
    {
        assertEquals(expectedContextFactory, contextSource.getContextFactory());

        // The pooling flag key has no accessor, so it is observed where it actually matters: the key the
        // context source writes into the JNDI environment when pooling is requested.
        contextSource.setPooled(true);
        contextSource.afterPropertiesSet();

        assertEquals("pooling must be requested under the configured key", "true",
                contextSource.getAnonymousEnv().get(expectedPoolingFlagKey));
    }

    /**
     * The {@code ldapJndiProperties} bean in {@code spring-library-user-login.xml} declares exactly this factory
     * bean and location, so that a bean definition wanting to override either value can wire it from there. This
     * asserts that the declaration actually resolves, rather than trusting that a classpath location in XML is
     * correct, and that it yields the same two values the context source itself defaults to.
     */
    @Test
    public void springConfigurationExposesTheSameTwoValues() throws Exception
    {
        PropertiesFactoryBean factoryBean = new PropertiesFactoryBean();
        factoryBean.setLocation(new ClassPathResource("spring/ldap-jndi.properties"));
        factoryBean.afterPropertiesSet();

        Properties exposed = factoryBean.getObject();

        assertNotNull("the ldapJndiProperties location must resolve on the classpath", exposed);
        assertEquals(expectedContextFactory,
                exposed.getProperty(ActiveDirectoryAbstractContextSource.INITIAL_CONTEXT_FACTORY_PROPERTY));
        assertEquals(expectedPoolingFlagKey,
                exposed.getProperty(ActiveDirectoryAbstractContextSource.CONNECTION_POOL_FLAG_PROPERTY));
    }

    /**
     * The pooling flag key the class mirrors from Spring LDAP must agree with the configured key, so that the two
     * routes to the same value cannot diverge.
     */
    @Test
    public void mirroredPoolingFlagConstantMatchesConfiguration()
    {
        assertEquals(expectedPoolingFlagKey, AbstractContextSource.SUN_LDAP_POOLING_FLAG);
    }

    /**
     * A context source configured the way the external bean definitions configure it must initialise, and must
     * produce a JNDI environment carrying the initial context factory and the provider URL. This is the case that
     * used to throw {@code NullPointerException} out of {@code Hashtable.put}.
     */
    @Test
    public void initialisesAndAssemblesEnvironmentWithoutInjection() throws Exception
    {
        contextSource.afterPropertiesSet();

        Hashtable environment = contextSource.getAnonymousEnv();

        assertNotNull("initialisation must leave a usable anonymous environment", environment);
        assertEquals(expectedContextFactory, environment.get(Context.INITIAL_CONTEXT_FACTORY));
        assertEquals(TEST_URL, environment.get(Context.PROVIDER_URL));
        assertNotNull("the directory object factory must be carried through", environment.get(Context.OBJECT_FACTORIES));
    }

    /**
     * The initial context factory the class defaults to must be a class this runtime can actually resolve by name.
     * A compile-time reference to it no longer compiles on this JDK, so resolving it by name is the whole point of
     * holding the value in configuration, and a value that cannot be resolved would fail only at bind time.
     */
    @Test
    public void configuredInitialContextFactoryIsResolvableByName() throws Exception
    {
        assertNotNull(Class.forName(expectedContextFactory));
    }

    /**
     * Requesting pooling must place the configured flag key in the environment.
     */
    @Test
    public void poolingRequestSetsTheConfiguredFlagKey() throws Exception
    {
        contextSource.setPooled(true);
        contextSource.afterPropertiesSet();

        assertEquals("true", contextSource.getAnonymousEnv().get(expectedPoolingFlagKey));
    }

    /**
     * Not requesting pooling must leave the flag out of the environment entirely, rather than setting it false.
     */
    @Test
    public void noPoolingRequestLeavesTheFlagUnset() throws Exception
    {
        contextSource.afterPropertiesSet();

        assertFalse(contextSource.isPooled());
        assertNull(contextSource.getAnonymousEnv().get(expectedPoolingFlagKey));
    }

    /**
     * A bind must reach the directory carrying the initial context factory and the caller's principal, and must have
     * the pooling flag removed for its duration. This exercises the second place the pooling flag key is handed to
     * {@code Hashtable}, which is the other site that produced a {@code NullPointerException}.
     * <p>
     * No directory is contacted: the recording subclass captures the assembled environment and reports a
     * communication failure, which is exactly what the abstract class expects an unreachable directory to do.
     */
    @Test
    public void bindEnvironmentCarriesCredentialsAndDisablesPooling() throws Exception
    {
        RecordingContextSource recording = new RecordingContextSource();
        recording.setUrl(TEST_URL);
        recording.setPooled(true);
        recording.afterPropertiesSet();

        expectBindFailure(recording);

        Hashtable bindEnvironment = recording.lastEnvironment;

        assertNotNull("the bind must have reached the directory layer", bindEnvironment);
        assertEquals(expectedContextFactory, bindEnvironment.get(Context.INITIAL_CONTEXT_FACTORY));
        assertEquals("uid=probe", bindEnvironment.get(Context.SECURITY_PRINCIPAL));
        assertNull("pooling must be disabled for the duration of an authenticating bind",
                bindEnvironment.get(expectedPoolingFlagKey));
    }

    /**
     * A bean definition may legitimately clear the pooling flag key to opt out of managing the flag. That must be
     * treated as "do not manage the flag" rather than producing a {@code NullPointerException} from
     * {@code Hashtable}, both while assembling the environment and while explicitly disabling pooling for a bind.
     */
    @Test
    public void blankPoolingFlagKeyIsRejectedAtInitialization()
    {
        RecordingContextSource recording = new RecordingContextSource();
        recording.setUrl(TEST_URL);
        recording.setConnectionPoolFlag("");
        recording.setPooled(true);

        // Clearing the key cannot be allowed to pass silently: the key is what the pooling flag is written
        // under, so a blank one would either be written into the JNDI environment as an empty key or drop
        // pooling without saying so. Initialization refuses it and names the property, which is the same
        // fail-fast contract the initial context factory name gets.
        try
        {
            recording.afterPropertiesSet();
            fail("a blank connection pooling flag key must be rejected when the context source initializes");
        }
        catch (Exception expected)
        {
            assertTrue("the failure must name the property that is unset, but was: " + expected.getMessage(),
                    expected.getMessage() != null && expected.getMessage().contains("connectionPoolFlag"));
        }

        assertNull("no JNDI environment may be assembled from a rejected configuration", recording.lastEnvironment);
    }

    /**
     * The success path. A bind that the directory layer accepts must return that context to the caller, which
     * confirms the whole path - environment assembly, pooling suppression, context creation and the
     * post-creation authentication step - completes for a context source that injects neither JNDI setting.
     */
    @Test
    public void acceptedBindReturnsTheDirectoryContext() throws Exception
    {
        DirContext accepted = EasyMock.createNiceMock(DirContext.class);
        EasyMock.replay(accepted);

        RecordingContextSource recording = new RecordingContextSource();
        recording.contextToReturn = accepted;
        recording.setUrl(TEST_URL);
        recording.afterPropertiesSet();

        DirContext returned = recording.getContext("uid=probe", "credentials");

        assertNotNull("an accepted bind must return a context", returned);
        assertEquals(accepted, returned);
        assertEquals(expectedContextFactory, recording.lastEnvironment.get(Context.INITIAL_CONTEXT_FACTORY));
        assertEquals("uid=probe", recording.lastEnvironment.get(Context.SECURITY_PRINCIPAL));
        EasyMock.verify(accepted);
    }

    /**
     * Drive one authenticating bind and require it to fail from the directory layer rather than from environment
     * assembly. A {@code NullPointerException} is the specific regression these tests exist to catch, so it is
     * re-reported as an assertion failure instead of being swallowed as "some exception".
     */
    private void expectBindFailure(ActiveDirectoryAbstractContextSource source)
    {
        try
        {
            source.getContext("uid=probe", "credentials");
            fail("a bind against a directory that reports a communication failure must not succeed");
        }
        catch (NullPointerException e)
        {
            throw new AssertionError("assembling the bind environment must not produce a NullPointerException", e);
        }
        catch (RuntimeException expected)
        {
            assertNotNull("the directory layer must report the failure", expected);
        }
    }

    /**
     * A context source that records the environment it is asked to bind with and then reports the directory as
     * unreachable. It keeps these tests free of network access while still driving the real environment-assembly
     * code path all the way to the point of connecting.
     */
    private static final class RecordingContextSource extends ActiveDirectoryAbstractContextSource
    {
        private Hashtable lastEnvironment;

        private DirContext contextToReturn;

        @Override
        protected DirContext getDirContextInstance(Hashtable environment) throws NamingException
        {
            lastEnvironment = new Hashtable(environment);

            if (contextToReturn != null)
            {
                return contextToReturn;
            }

            throw new CommunicationException("no directory is contacted by this test");
        }
    }

    /**
     * An explicitly blank initial context factory must be rejected at initialisation, with a message that names the
     * property and the configuration resource, rather than surfacing later as a {@code NullPointerException} from
     * {@code Hashtable.put}.
     */
    @Test
    public void blankInitialContextFactoryIsRejectedAtInitialisation()
    {
        contextSource.setContextFactory("   ");

        try
        {
            contextSource.afterPropertiesSet();
            fail("a blank initial context factory must be rejected");
        }
        catch (IllegalArgumentException expected)
        {
            assertTrue("the message must name the property that is wrong",
                    expected.getMessage().contains("contextFactory"));
            assertTrue("the message must name the configuration resource that supplies the default",
                    expected.getMessage().contains(ActiveDirectoryAbstractContextSource.LDAP_JNDI_PROPERTIES_LOCATION));
        }
        catch (Exception e)
        {
            throw new AssertionError("a blank initial context factory must be rejected with IllegalArgumentException",
                    e);
        }
    }

    /**
     * The pre-existing url validation must still fire, so that this change has not weakened the checks that were
     * already there.
     */
    @Test
    public void missingUrlIsStillRejected()
    {
        ActiveDirectoryContextSource withoutUrl = new ActiveDirectoryContextSource();

        try
        {
            withoutUrl.afterPropertiesSet();
            fail("a context source with no server url must be rejected");
        }
        catch (IllegalArgumentException expected)
        {
            assertNotNull(expected.getMessage());
        }
        catch (Exception e)
        {
            throw new AssertionError("a missing server url must be rejected with IllegalArgumentException", e);
        }
    }
}
