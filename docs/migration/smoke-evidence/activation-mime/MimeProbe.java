/*
 * MimeProbe — exercises the reinstated activation framework's MIME-type mapping
 * directly, and prints what it resolved.
 *
 * WHY THIS EXISTS.  JEP 320 removed the JavaBeans Activation Framework from the
 * JDK, so it is reinstated as an ordinary Maven dependency.  Two artifacts satisfy
 * the same javax.activation API and their coordinates give no hint that the choice
 * matters: one is the reference implementation and one is API-only.  The
 * reference implementation ships META-INF/mimetypes.default and
 * META-INF/mailcap.default; the API-only jar does not.  MimetypesFileTypeMap reads
 * exactly those resources, so the API-only jar compiles, deploys, and then resolves
 * every unknown extension to the fallback type instead of to its real media type.
 * That is a silent behavioural regression, and this probe is what makes the choice
 * a measurement rather than an assertion.
 *
 * WHAT IT DOES.  It constructs one MimetypesFileTypeMap and asks it for the content
 * type of a fixed list of file names, printing "<name>\t<resolved type>" per line
 * and nothing else, so two runs on two classpaths can be compared with diff.  The
 * names are the extensions the application's own activation consumers encounter:
 * e-mail attachment extraction and the SMTP data source both resolve an attachment
 * name through this exact call, and the batch-capture listeners do the same for
 * scanned documents.
 *
 * WHAT IT DELIBERATELY DOES NOT DO.  It contacts nothing, reads no configuration
 * and writes no file.  It is not a substitute for the document round trip: that
 * flow observes storage and retrieval, and this probe observes MIME resolution.
 * The two are separate because the round trip supplies an explicit content type on
 * the request, so it never causes the activation defaults to be consulted at all.
 */
import javax.activation.MimetypesFileTypeMap;

public final class MimeProbe
{
    /**
     * The probe set.  Every entry is an extension that one of the application's
     * activation consumers can encounter on an attachment or a captured document,
     * plus two controls: a name with no extension and a name with an extension no
     * map knows, both of which MUST resolve to the fallback type on every
     * classpath and therefore prove the probe is reading a map at all.
     */
    private static final String[] NAMES = {
            "attachment.txt",
            "attachment.html",
            "attachment.xml",
            "attachment.pdf",
            "attachment.docx",
            "attachment.doc",
            "attachment.xlsx",
            "attachment.xls",
            "attachment.pptx",
            "attachment.png",
            "attachment.jpg",
            "attachment.gif",
            "attachment.tiff",
            "attachment.zip",
            "attachment.eml",
            "attachment.msg",
            "attachment.csv",
            "attachment.rtf",
            "attachment-with-no-extension",
            "attachment.thisextensionexistsnowhere"
    };

    public static void main(String[] args)
    {
        MimetypesFileTypeMap map = new MimetypesFileTypeMap();
        System.out.println("probe: javax.activation.MimetypesFileTypeMap#getContentType");
        System.out.println("implementation-class: " + map.getClass().getName());
        System.out.println("implementation-source: "
                + describeSource(map.getClass()));
        System.out.println("--- resolutions ---");
        for (String name : NAMES)
        {
            System.out.println(name + "\t" + map.getContentType(name));
        }
    }

    /**
     * Where the implementation class was actually loaded from, so the recorded
     * output names the artifact it describes instead of leaving a reader to trust
     * the classpath that was passed in.
     */
    private static String describeSource(Class<?> type)
    {
        try
        {
            java.security.CodeSource source = type.getProtectionDomain().getCodeSource();
            if (source == null || source.getLocation() == null)
            {
                return "not-reported (no code source, which is what a platform class returns)";
            }
            String location = source.getLocation().toString();
            int lastSlash = location.lastIndexOf('/');
            return lastSlash >= 0 ? location.substring(lastSlash + 1) : location;
        }
        catch (RuntimeException e)
        {
            return "not-reported (" + e.getClass().getName() + ")";
        }
    }
}
