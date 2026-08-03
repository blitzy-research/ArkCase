import com.fasterxml.jackson.databind.JsonSerializer;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.ser.PropertyWriter;

import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Enumeration;
import java.util.Iterator;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

/**
 * Dump the serialization property model Jackson resolves for every project class on the classpath:
 * the class name, then each property in the order Jackson will write it, with its declared type.
 *
 * That ordered list is what decides the shape of a serialized REST response - which fields appear,
 * under which names, in which order, at which types. Producing it under two Jackson versions and
 * diffing the two files is a per-class comparison of response shape across the whole project model
 * surface, rather than a claim about it.
 */
public final class JacksonShapeParity
{
    public static void main(String[] args) throws Exception
    {
        String classpath = System.getProperty("java.class.path");
        List<String> classNames = new ArrayList<>();

        for (String entry : classpath.split(File.pathSeparator))
        {
            if (!entry.endsWith(".jar") || !entry.replace('\\', '/').contains("/com/armedia/"))
            {
                continue;
            }
            try (JarFile jar = new JarFile(entry))
            {
                for (Enumeration<JarEntry> e = jar.entries(); e.hasMoreElements();)
                {
                    String name = e.nextElement().getName();
                    if (name.endsWith(".class") && !name.contains("$"))
                    {
                        classNames.add(name.substring(0, name.length() - 6).replace('/', '.'));
                    }
                }
            }
        }

        Collections.sort(classNames);

        ObjectMapper mapper = new ObjectMapper();
        SerializerProvider provider = mapper.getSerializerProviderInstance();
        int described = 0;
        int skipped = 0;

        try (PrintWriter out = new PrintWriter(args[0], "UTF-8"))
        {
            out.println("jackson-version=" + com.fasterxml.jackson.core.json.PackageVersion.VERSION);
            out.println("classes-considered=" + classNames.size());

            for (String className : classNames)
            {
                Class<?> type;
                try
                {
                    type = Class.forName(className, false, JacksonShapeParity.class.getClassLoader());
                }
                catch (Throwable notLoadable)
                {
                    skipped++;
                    continue;
                }

                if (type.isInterface() || type.isEnum() || type.isAnnotation() || type.isSynthetic())
                {
                    continue;
                }

                StringBuilder shape = new StringBuilder();
                try
                {
                    JsonSerializer<Object> serializer = provider.findValueSerializer(type, null);
                    for (Iterator<PropertyWriter> it = serializer.properties(); it.hasNext();)
                    {
                        PropertyWriter property = it.next();
                        shape.append(property.getName()).append(':')
                                .append(property.getType() == null ? "?" : property.getType().toCanonical())
                                .append(' ');
                    }
                    out.println(className + " -> " + serializer.getClass().getName() + " [" + shape.toString().trim() + "]");
                    described++;
                }
                catch (Throwable notDescribable)
                {
                    out.println(className + " -> UNRESOLVED " + notDescribable.getClass().getName());
                    described++;
                }
            }

            out.println("classes-described=" + described);
            out.println("classes-not-loadable=" + skipped);
        }

        System.out.println("described " + described + " classes, skipped " + skipped);
    }
}
