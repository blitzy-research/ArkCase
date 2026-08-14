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

import javax.naming.spi.InitialContextFactory;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Supplies the JNDI provider configuration that {@link ActiveDirectoryAbstractContextSource} needs, read once from the
 * <code>ldap-provider.properties</code> resource beside this class on the classpath. The initial context factory is
 * published as a {@link Class}, because that is what the context source's public accessors exchange with their callers.
 * <p>
 * Both values used to be compile-time literals in the context source, and their bytes are unchanged from the Java 8
 * baseline: the same provider is resolved and the same pooling property is set as before. One of them named the initial
 * context factory as a class literal, which stopped compiling on Java 17 because the package declaring that factory is
 * contained in - but not exported by - the <code>java.naming</code> module. Loading the very same class <em>by name</em>
 * is unaffected by that encapsulation, so both strings are held here as data and no <code>.java</code> file names the
 * encapsulated package. There is deliberately no hardcoded fallback for either value, which would put that name back.
 * <p>
 * The name is resolved <em>without initializing</em> the class and is accepted only after it is confirmed to be an
 * {@link InitialContextFactory}; {@link #loadContextFactory(String)} carries the reasoning for both.
 * <p>
 * Loading is fail-fast and happens once, in the class initializer: an absent or unreadable resource, a missing key, a
 * blank or whitespace-padded value, or a name that does not resolve to a JNDI initial context factory raises
 * {@link IllegalStateException} there, which reaches callers as an {@link ExceptionInInitializerError} carrying it as
 * the cause. The alternative - a silently <code>null</code> provider name - would reappear much later as an opaque JNDI
 * lookup failure, and a green build cannot rule it out, because the resource is packaged by ordinary Maven resource
 * handling; the diagnostics therefore name both the path searched and the key wanted.
 */
final class LdapProviderProperties
{
    /** Resolved relative to this class, so the resource has to stay in this class's package directory. */
    private static final String RESOURCE_NAME = "ldap-provider.properties";

    /** Derived from this class's own package, and used only so that a failure names the path that was searched. */
    private static final String RESOURCE_PATH = LdapProviderProperties.class.getPackageName().replace('.', '/') + "/" + RESOURCE_NAME;

    private static final String CONTEXT_FACTORY_KEY = "ldap.provider.contextFactory";

    private static final String CONNECTION_POOL_FLAG_KEY = "ldap.provider.connectionPoolFlag";

    private static final String CONTEXT_FACTORY_NAME;

    /**
     * The JNDI initial context factory named by {@link #CONTEXT_FACTORY_NAME}, loaded by name without being
     * initialized. Never null once initialization has completed.
     */
    private static final Class<? extends InitialContextFactory> CONTEXT_FACTORY_CLASS;

    private static final String CONNECTION_POOL_FLAG;

    static
    {
        Properties providerProperties = load();
        CONTEXT_FACTORY_NAME = requireValue(providerProperties, CONTEXT_FACTORY_KEY);
        CONTEXT_FACTORY_CLASS = loadContextFactory(CONTEXT_FACTORY_NAME);
        CONNECTION_POOL_FLAG = requireValue(providerProperties, CONNECTION_POOL_FLAG_KEY);
    }

    private LdapProviderProperties()
    {
    }

    /**
     * The JNDI initial context factory used when creating LDAP contexts, as a {@link Class}.
     * <p>
     * The factory is resolved from the configured name with
     * {@link Class#forName(String, boolean, ClassLoader)} - <em>without</em> initializing it, and only after
     * {@link Class#asSubclass(Class)} has confirmed it really is an {@link InitialContextFactory} - rather than
     * referenced as a class literal. That distinction is the whole point of this class: the literal no longer compiles
     * on Java 17, because the declaring package is contained in - but not exported by - the <code>java.naming</code>
     * module, whereas loading the same class by name is unaffected by JEP 396 encapsulation and yields exactly the
     * {@link Class} the literal used to - including its <em>uninitialized</em> state, since a class literal does not
     * trigger static initialization either. The name it is resolved from is the value of the
     * <code>ldap.provider.contextFactory</code> key in the backing resource, so the class this accessor returns and the
     * provider that resource configures can never describe different providers.
     * <p>
     * Callers need the {@link Class} because it is the type the context source's public
     * <code>getContextFactory()</code> / <code>setContextFactory(Class)</code> pair exchanges with its callers; the
     * LDAP environment itself is still populated from the class <em>name</em>.
     *
     * @return the context factory class; never <code>null</code>.
     * @throws IllegalStateException
     *             if the configured name does not resolve to a class on this runtime, or resolves to a class that is not
     *             an {@link InitialContextFactory}. Failing here is deliberate and matches the previous behaviour: a
     *             class literal that could not be loaded raised {@link NoClassDefFoundError} during class
     *             initialization, and one naming a non-factory type could not have compiled at all, so neither is
     *             something this class has ever survived.
     */
    static Class<? extends InitialContextFactory> getContextFactoryClass()
    {
        return CONTEXT_FACTORY_CLASS;
    }

    /**
     * The name of the JNDI environment property that enables LDAP connection pooling, exactly as configured.
     */
    static String getConnectionPoolFlag()
    {
        return CONNECTION_POOL_FLAG;
    }

    /**
     * Loads the configured initial context factory once, during class initialization.
     * <p>
     * Two properties of this lookup are security-relevant, and both exist to keep a classpath resource from becoming a
     * lever for running arbitrary code:
     * <ul>
     * <li><strong>The class is loaded but not initialized.</strong> The three-argument
     * {@link Class#forName(String, boolean, ClassLoader)} with <code>initialize = false</code> is used deliberately in
     * place of {@link Class#forName(String)}, which initializes. A class literal - what this resource replaced - never
     * triggered static initialization either, so this is the form that reproduces the Java 8 baseline exactly. The
     * one-argument form does not: it would run the named class's static initializer at the moment this class is first
     * touched, which turns "a name in a properties file" into "code that runs during authentication start-up" and hands
     * a side effect to anything that can edit the resource. JNDI still initializes the real factory when it
     * instantiates it, so nothing is lost.</li>
     * <li><strong>The type is checked before the name is ever used.</strong> {@link Class#asSubclass(Class)} rejects
     * anything that is not an {@link InitialContextFactory}, so a name that resolves to some unrelated class fails here
     * - with a message that says what was wrong - instead of being handed to JNDI as a provider and failing later, or
     * being loaded for its side effects alone.</li>
     * </ul>
     * The class loader is this class's own, which is the loader that resolved the class literal on Java 8; delegation
     * reaches the platform loader for the JDK-supplied provider, so the {@link Class} produced here is the identical
     * object the literal produced.
     *
     * @param contextFactoryName
     *            the fully qualified class name read from the backing resource.
     * @return the loaded, uninitialized context factory class; never <code>null</code>.
     * @throws IllegalStateException
     *             if the name cannot be resolved, or does not name an {@link InitialContextFactory}, naming both the
     *             resource and the key so the misconfiguration is actionable rather than opaque.
     */
    private static Class<? extends InitialContextFactory> loadContextFactory(String contextFactoryName)
    {
        Class<?> resolved;

        try
        {
            resolved = Class.forName(contextFactoryName, false, LdapProviderProperties.class.getClassLoader());
        }
        catch (ClassNotFoundException | LinkageError e)
        {
            throw new IllegalStateException("LDAP provider resource '" + RESOURCE_PATH + "' names the initial context factory '"
                    + contextFactoryName + "' for key '" + CONTEXT_FACTORY_KEY
                    + "', but no such class is on the classpath. Point the key at a JNDI initial context factory this deployment ships.",
                    e);
        }

        try
        {
            return resolved.asSubclass(InitialContextFactory.class);
        }
        catch (ClassCastException e)
        {
            throw new IllegalStateException("LDAP provider resource '" + RESOURCE_PATH + "' names '" + contextFactoryName
                    + "' for key '" + CONTEXT_FACTORY_KEY + "', but that class does not implement "
                    + InitialContextFactory.class.getName()
                    + ", so JNDI could never use it as a provider. Point the key at a JNDI initial context factory this deployment ships.",
                    e);
        }
    }

    /**
     * Both values are ASCII, so the ISO-8859-1 decoding {@link Properties#load(InputStream)} performs is lossless here.
     */
    private static Properties load()
    {
        Properties providerProperties = new Properties();

        try (InputStream resource = LdapProviderProperties.class.getResourceAsStream(RESOURCE_NAME))
        {
            if (resource == null)
            {
                throw new IllegalStateException("LDAP provider resource '" + RESOURCE_PATH
                        + "' is not on the classpath; it must be packaged next to " + LdapProviderProperties.class.getName() + ".");
            }

            providerProperties.load(resource);
        }
        catch (IOException e)
        {
            throw new IllegalStateException("LDAP provider resource '" + RESOURCE_PATH + "' could not be read.", e);
        }

        return providerProperties;
    }

    /**
     * Returns a mandatory value verbatim, rejecting an absent, blank or whitespace-padded entry. Nothing is trimmed:
     * these strings are a JNDI provider name and a JNDI property name, and {@link Properties#load(InputStream)} keeps
     * every character after a value, so a trailing space would otherwise reach JNDI inside a class name.
     */
    private static String requireValue(Properties providerProperties, String key)
    {
        String value = providerProperties.getProperty(key);

        if (value == null || value.isBlank())
        {
            throw new IllegalStateException(
                    "LDAP provider resource '" + RESOURCE_PATH + "' is missing a value for required key '" + key + "'.");
        }

        if (!value.equals(value.trim()))
        {
            throw new IllegalStateException("LDAP provider resource '" + RESOURCE_PATH + "' has a value for key '" + key
                    + "' that begins or ends with whitespace: '" + value
                    + "'. Remove the surrounding whitespace; the value is used verbatim and is not trimmed.");
        }

        return value;
    }
}
