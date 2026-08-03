import org.drools.decisiontable.InputType;
import org.drools.decisiontable.SpreadsheetCompiler;

import java.io.FileInputStream;
import java.io.InputStream;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.util.List;

/**
 * Compile every tracked Drools spreadsheet decision table to its generated rule text and print one
 * SHA-256 digest per table. Running this under two Drools versions and diffing the two outputs is a
 * direct, per-table comparison of the rule text the engine will build, which is the observable output
 * of the spreadsheet compiler.
 */
public final class DecisionTableParity
{
    public static void main(String[] args) throws Exception
    {
        List<String> tables = Files.readAllLines(Paths.get(args[0]));
        String outDir = args[1];
        Files.createDirectories(Paths.get(outDir));

        try (PrintWriter digests = new PrintWriter(outDir + "/digests.txt", "UTF-8"))
        {
            digests.println("drools-version=" + org.drools.core.util.Drools.getFullVersion());
            for (String table : tables)
            {
                if (table.trim().isEmpty())
                {
                    continue;
                }
                String drl;
                try (InputStream in = new FileInputStream(table.trim()))
                {
                    drl = new SpreadsheetCompiler().compile(in, InputType.XLS);
                }
                MessageDigest sha = MessageDigest.getInstance("SHA-256");
                byte[] bytes = drl.getBytes(StandardCharsets.UTF_8);
                StringBuilder hex = new StringBuilder();
                for (byte b : sha.digest(bytes))
                {
                    hex.append(String.format("%02x", b));
                }
                digests.printf("%s  %d  %s%n", hex, bytes.length, table.trim());
                Files.write(Paths.get(outDir, table.trim().replace('/', '_') + ".drl"), bytes);
            }
        }
        System.out.println("compiled " + tables.size() + " tables");
    }
}
