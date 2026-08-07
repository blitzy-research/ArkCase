import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonSerializer;
import com.fasterxml.jackson.databind.ser.PropertyWriter;
import java.io.*;
import java.nio.file.*;
import java.util.*;

/**
 * Emits, for every class named on stdin, the ordered list of properties Jackson would serialise.
 * One line per class: fully.qualified.Name<TAB>prop1,prop2,prop3
 * Classes that cannot be loaded or introspected are reported on a SKIP line so the two runs stay comparable.
 * Deliberately uses only API present in both 2.7.x and 2.12.x.
 */
public final class PropOrder
{
    public static void main(String[] args) throws Exception
    {
        List<String> names = Files.readAllLines(Paths.get(args[0]));
        ObjectMapper mapper = new ObjectMapper();
        // "deployed" reproduces the sourceObjectMapper bean configuration in
        // spring-library-object-converter.xml, mirrored by ObjectConverter.createJSONMarshallerForTests():
        // the two disabled features plus every module discoverable on the classpath.
        if (args.length > 2 && "deployed".equals(args[2]))
        {
            mapper.disable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
            mapper.disable(com.fasterxml.jackson.databind.DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
            mapper.findAndRegisterModules();
        }
        try (PrintWriter out = new PrintWriter(new BufferedWriter(new FileWriter(args[1]))))
        {
            out.println("# jackson-databind=" + versionOf(ObjectMapper.class));
            for (String n : names)
            {
                n = n.trim();
                if (n.isEmpty() || n.startsWith("#"))
                {
                    continue;
                }
                try
                {
                    Class<?> c = Class.forName(n, false, PropOrder.class.getClassLoader());
                    if (c.isInterface() || c.isEnum() || c.isAnnotation() || c.isArray()
                            || java.lang.reflect.Modifier.isAbstract(c.getModifiers()))
                    {
                        continue;
                    }
                    JsonSerializer<Object> ser = mapper.getSerializerProviderInstance()
                            .findValueSerializer(c, null);
                    Iterator<PropertyWriter> it = ser.properties();
                    StringBuilder sb = new StringBuilder();
                    int count = 0;
                    while (it.hasNext())
                    {
                        if (count++ > 0)
                        {
                            sb.append(',');
                        }
                        sb.append(it.next().getName());
                    }
                    if (count == 0)
                    {
                        continue;
                    }
                    out.println(n + "\t" + sb);
                }
                catch (Throwable t)
                {
                    out.println("# SKIP " + n + " :: " + t.getClass().getSimpleName());
                }
            }
        }
    }

    private static String versionOf(Class<?> c)
    {
        try
        {
            return c.getPackage().getImplementationVersion();
        }
        catch (Throwable t)
        {
            return "unknown";
        }
    }
}
