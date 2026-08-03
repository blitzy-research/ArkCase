import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;

import java.io.PrintWriter;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Report what the production message-converter mapper is configured with, and what it writes for the
 * java.time property whose reflective access is the reason this library moved at all.
 *
 * The registered module set decides value formatting, so an identical set under two library versions is
 * what allows the property-model comparison to be read as a response-shape comparison.
 */
public final class JacksonModuleParity
{
    public static void main(String[] args) throws Exception
    {
        try (PrintWriter out = new PrintWriter(args[0], "UTF-8"))
        {
            out.println("jackson-version=" + com.fasterxml.jackson.core.json.PackageVersion.VERSION);

            ObjectMapper spring = Jackson2ObjectMapperBuilder.json().build();
            List<String> ids = new ArrayList<>();
            for (Object id : spring.getRegisteredModuleIds())
            {
                ids.add(String.valueOf(id));
            }
            ids.sort(String::compareTo);
            out.println("spring-mvc-mapper-modules=" + ids);
            out.println("spring-mvc-writes-localdate=" + spring.writeValueAsString(LocalDate.of(2026, 3, 4)));
            out.println("spring-mvc-writes-holder=" + spring.writeValueAsString(new Holder()));

            ObjectMapper plain = new ObjectMapper();
            out.println("plain-mapper-modules=" + plain.getRegisteredModuleIds());

            try
            {
                out.println("plain-writes-holder=" + plain.writeValueAsString(new Holder()));
            }
            catch (Throwable failure)
            {
                out.println("plain-writes-holder=THREW " + failure.getClass().getName());
            }

            read(out, plain, "plain-reads-iso", "{\"day\":\"2026-03-04\",\"name\":\"n\"}");
            read(out, plain, "plain-reads-bean-shaped",
                    "{\"day\":{\"year\":2026,\"monthValue\":3,\"dayOfMonth\":4},\"name\":\"n\"}");
            read(out, plain, "plain-reads-without-the-time-property", "{\"name\":\"n\"}");
            read(out, Jackson2ObjectMapperBuilder.json().build(), "spring-mvc-reads-iso",
                    "{\"day\":\"2026-03-04\",\"name\":\"n\"}");
        }
        System.out.println("done");
    }

    private static void read(PrintWriter out, ObjectMapper mapper, String label, String json)
    {
        try
        {
            Holder holder = mapper.readValue(json, Holder.class);
            out.println(label + "=OK day=" + holder.getDay() + " name=" + holder.getName());
        }
        catch (Throwable failure)
        {
            out.println(label + "=THREW " + failure.getClass().getName());
        }
    }

    /** A bean shaped like the ones the failing controller tests read back: a java.time property beside a plain one. */
    public static class Holder
    {
        private LocalDate day = LocalDate.of(2026, 3, 4);
        private String name = "n";

        public LocalDate getDay()
        {
            return day;
        }

        public void setDay(LocalDate day)
        {
            this.day = day;
        }

        public String getName()
        {
            return name;
        }

        public void setName(String name)
        {
            this.name = name;
        }
    }
}
