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

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Supplies the two JNDI provider strings that {@link ActiveDirectoryAbstractContextSource} needs, read once from a
 * properties resource that sits beside this class on the classpath.
 * <p>
 * Both strings used to be compile-time literals in the context source. One of them named the initial context factory
 * as a class literal, which stopped compiling on Java 17: the package that declares that factory is contained in - but
 * not exported by - the <code>java.naming</code> module, so JEP 396 strong encapsulation puts it out of reach of
 * ordinary classpath code. JNDI never needs the {@link Class} object, only the fully qualified class <em>name</em>, so
 * the two strings are held here as data instead. Their bytes are unchanged from the Java 8 baseline, which is why this
 * class validates values but never rewrites them: the same provider is resolved, and the same pooling property is set,
 * as before.
 * <p>
 * Loading is deliberately fail-fast and happens exactly once, during class initialization. A resource that is absent,
 * unreadable, missing either key, or carrying a value that is blank or padded with whitespace raises
 * {@link IllegalStateException}, which the JVM surfaces as an
 * {@link ExceptionInInitializerError} at the point of first use. That is the intended behaviour: the alternative - a
 * silently <code>null</code> provider name - would reappear much later as an opaque JNDI lookup failure. Such a
 * misconfiguration cannot be caught by a build, either: the resource is packaged by ordinary Maven resource handling,
 * so a green build says nothing about its presence at run time, and the diagnostics below therefore name both the path
 * that was searched and the key that was wanted.
 * <p>
 * There is intentionally no hardcoded fallback for either value. A default written into Java source would put the
 * encapsulated provider's name straight back into a <code>.java</code> file, which is precisely what externalizing it
 * removed.
 */
final class LdapProviderProperties
{
    /**
     * Simple name of the backing resource. It is resolved relative to this class, so the resource has to stay in this
     * class's package directory; that makes the package-path coupling structural rather than a magic string.
     */
    private static final String RESOURCE_NAME = "ldap-provider.properties";

    /**
     * Classpath location of the backing resource, derived from this class's own package so it cannot drift out of step
     * with the lookup above. Used only in diagnostics, so that a failure names the exact path that was searched.
     */
    private static final String RESOURCE_PATH = LdapProviderProperties.class.getPackageName().replace('.', '/') + "/" + RESOURCE_NAME;

    /**
     * Key whose value is the fully qualified name of the JNDI initial context factory.
     */
    private static final String CONTEXT_FACTORY_KEY = "ldap.provider.contextFactory";

    /**
     * Key whose value is the name of the JNDI environment property that turns LDAP connection pooling on.
     */
    private static final String CONNECTION_POOL_FLAG_KEY = "ldap.provider.connectionPoolFlag";

    /**
     * Fully qualified name of the JNDI initial context factory. Never null or blank once initialization has completed.
     */
    private static final String CONTEXT_FACTORY_NAME;

    /**
     * Name of the JNDI connection-pooling environment property. Never null or blank once initialization has completed.
     */
    private static final String CONNECTION_POOL_FLAG;

    static
    {
        Properties providerProperties = load();
        CONTEXT_FACTORY_NAME = requireValue(providerProperties, CONTEXT_FACTORY_KEY);
        CONNECTION_POOL_FLAG = requireValue(providerProperties, CONNECTION_POOL_FLAG_KEY);
    }

    /**
     * Not instantiable: this class only publishes two classpath-supplied constants.
     */
    private LdapProviderProperties()
    {
    }

    /**
     * The fully qualified class name of the JNDI initial context factory used when creating LDAP contexts. Callers pass
     * it straight to JNDI as the value of the initial-context-factory environment property.
     *
     * @return the context factory class name, exactly as configured; never <code>null</code> and never blank.
     */
    static String getContextFactoryName()
    {
        return CONTEXT_FACTORY_NAME;
    }

    /**
     * The name of the JNDI environment property that enables LDAP connection pooling. Callers add it to, or remove it
     * from, the LDAP environment.
     *
     * @return the pooling property name, exactly as configured; never <code>null</code> and never blank.
     */
    static String getConnectionPoolFlag()
    {
        return CONNECTION_POOL_FLAG;
    }

    /**
     * Reads the backing resource once, from this class's package on the classpath.
     * <p>
     * The stream is closed by try-with-resources whether the parse succeeds or not. Both values are ASCII, so the
     * ISO-8859-1 decoding that {@link Properties#load(InputStream)} performs is lossless here.
     *
     * @return the parsed properties; never <code>null</code>.
     * @throws IllegalStateException
     *             if the resource is not on the classpath, or cannot be read.
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
     * Returns a mandatory value verbatim, rejecting an absent, blank or whitespace-padded entry.
     * <p>
     * The value is validated but never altered - not even trimmed. These strings are a JNDI provider name and a JNDI
     * property name whose bytes have to stay identical to the literals they replaced, so quietly normalizing one would
     * be a behavioural change. A value that merely looks blank is therefore rejected outright rather than repaired.
     * <p>
     * Surrounding whitespace is rejected for the same reason, and it is a realistic mistake rather than a theoretical
     * one: {@link Properties#load(InputStream)} discards whitespace <em>before</em> a value but keeps every character
     * after it, so a single space typed past the end of the context-factory line survives into the JNDI environment
     * and fails much later, when JNDI tries to load a class whose name has a trailing space. Catching it here turns
     * that into a startup failure that names the resource and the key. Nothing is trimmed on the caller's behalf,
     * because a loader that silently repaired the value would make two different resources behave identically and
     * hide the typo instead of reporting it.
     *
     * @param providerProperties
     *            the parsed properties.
     * @param key
     *            the key to read.
     * @return the configured value, unmodified.
     * @throws IllegalStateException
     *             if the key is absent, if its value is empty or consists only of whitespace, or if its value begins
     *             or ends with whitespace.
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
