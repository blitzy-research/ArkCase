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

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Loader for the JNDI LDAP provider strings used by {@link ActiveDirectoryAbstractContextSource}.
 * <p>
 * The provider strings used to be compile-time literals in the context source itself. The initial context factory was
 * referenced as a class literal, which stopped compiling on Java 17: the package declaring it is contained in - but not
 * exported by - the <code>java.naming</code> module, so it is inaccessible under JEP 396 strong encapsulation. JNDI only
 * ever consumes the fully qualified class <em>name</em>, so the values are externalized to
 * <code>ldap-provider.properties</code>, loaded from this package on the classpath, and held as plain strings. The
 * values are byte-identical to the literals they replace, so the same provider and the same pooling property are used at
 * runtime.
 * <p>
 * The resource is read exactly once, when this class is initialized, and the values are immutable thereafter. Loading is
 * fail-fast: a missing or unreadable resource, or a missing or blank key, raises {@link IllegalStateException} rather
 * than letting the context source silently fall back to a null provider and fail later with an opaque JNDI error.
 */
final class LdapProviderProperties
{
    /**
     * Classpath location of the backing resource, resolved relative to this class's package.
     */
    private static final String RESOURCE_NAME = "ldap-provider.properties";

    /**
     * Key holding the fully qualified name of the JNDI initial context factory.
     */
    private static final String CONTEXT_FACTORY_KEY = "ldap.provider.contextFactory";

    /**
     * Key holding the name of the JNDI environment property that enables LDAP connection pooling.
     */
    private static final String CONNECTION_POOL_FLAG_KEY = "ldap.provider.connectionPoolFlag";

    private static final String CONTEXT_FACTORY_NAME;
    private static final String CONNECTION_POOL_FLAG;

    static
    {
        Properties properties = load();
        CONTEXT_FACTORY_NAME = requireValue(properties, CONTEXT_FACTORY_KEY);
        CONNECTION_POOL_FLAG = requireValue(properties, CONNECTION_POOL_FLAG_KEY);
    }

    /**
     * Not instantiable; the class is a holder for two classpath-supplied constants.
     */
    private LdapProviderProperties()
    {
    }

    /**
     * The fully qualified class name of the JNDI initial context factory used to create LDAP contexts.
     *
     * @return the context factory class name; never <code>null</code> or blank.
     */
    static String getContextFactoryName()
    {
        return CONTEXT_FACTORY_NAME;
    }

    /**
     * The name of the JNDI environment property that enables LDAP connection pooling.
     *
     * @return the pooling property name; never <code>null</code> or blank.
     */
    static String getConnectionPoolFlag()
    {
        return CONNECTION_POOL_FLAG;
    }

    /**
     * Reads the backing resource from this class's package on the classpath.
     *
     * @return the parsed properties.
     * @throws IllegalStateException
     *             if the resource is absent from the classpath or cannot be read.
     */
    private static Properties load()
    {
        Properties properties = new Properties();

        try (InputStream resource = LdapProviderProperties.class.getResourceAsStream(RESOURCE_NAME))
        {
            if (resource == null)
            {
                throw new IllegalStateException(
                        "Required LDAP provider resource '" + RESOURCE_NAME + "' was not found on the classpath next to "
                                + LdapProviderProperties.class.getName());
            }

            properties.load(resource);
        }
        catch (IOException e)
        {
            throw new IllegalStateException("Failed to read LDAP provider resource '" + RESOURCE_NAME + "'", e);
        }

        return properties;
    }

    /**
     * Extracts a mandatory value, rejecting absent and blank entries.
     *
     * @param properties
     *            the parsed properties.
     * @param key
     *            the key to read.
     * @return the trimmed value.
     * @throws IllegalStateException
     *             if the key is absent or its value is blank.
     */
    private static String requireValue(Properties properties, String key)
    {
        String value = properties.getProperty(key);

        if (value == null || value.trim().isEmpty())
        {
            throw new IllegalStateException(
                    "Required key '" + key + "' is missing or blank in LDAP provider resource '" + RESOURCE_NAME + "'");
        }

        return value.trim();
    }
}
