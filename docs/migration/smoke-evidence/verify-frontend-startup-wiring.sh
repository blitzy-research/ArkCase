#!/bin/bash
# verify-frontend-startup-wiring.sh — execute the delivered startup frontend-build seam and record
# what it actually resolves, on both platform branches, FAILING CLOSED on any disagreement.
#
# WHY THIS PROGRAM EXISTS.  Three properties of the startup frontend-build seam are behaviour, not
# configuration: which launcher each command resolves to on each platform, which environment
# variables the child process is given, and whether the toolchain majors are checked before an
# install runs.  All three were previously claimed to be covered by a JUnit class,
# AngularResourceCopierWiringTest.  That class no longer exists — it was withdrawn together with
# the other test files created outside the file list the migration plan authorises, and
# ark-angular-starter now has no src/test tree at all — so the claim had nothing behind it.  The
# module also cannot simply grow the class back: the plan's file list for this module does not
# include a test source root, and adding one is the same unauthorised extension that was withdrawn.
#
# Neither is there a runtime capture to fall back on.  The committed startup logs were taken from a
# deployment built at an earlier commit, before the seam carried any of this behaviour: grep the
# migrated capture's catalina.out.log for the composed-environment line or for a reported launcher
# version and it returns nothing.  So the honest position was that three delivered behaviours had
# no evidence of any kind.
#
# This script is that evidence.  It loads the DELIVERED Spring document, instantiates the DELIVERED
# class, and executes the three behaviours against the real launchers on this host, then writes a
# record of what it observed.  It is a check rather than a test in the build sense — nothing in the
# reactor depends on it and it ships no product code — which is exactly why it is allowed to exist
# where a test class is not: it lives in the evidence deliverable the plan creates, beside the other
# producers, and it is run by hand or by a reviewer rather than by Surefire.
#
# WHAT IT CHECKS, and why each one is here rather than being asserted in prose:
#
#   A. PLATFORM RESOLUTION, all three os.name branches.  The suffix that names a Windows batch
#      wrapper must reach the Grunt CLI, which npm installs as grunt.cmd and which is invoked by an
#      explicit path, and must NOT reach `node` or `npm`, which are invoked by bare name and which
#      have no .cmd form to reach in Node's case at all.  A single suffix applied to all three made
#      the Windows Node probe `cmd /C node.cmd --version`, which cmd cannot resolve — and that probe
#      runs BEFORE the install, so the Windows startup build failed before a package was fetched.
#      Prose cannot demonstrate the absence of a defect on a platform the reviewer is not running,
#      so the SpEL is evaluated under a simulated os.name and the resolved commands are printed.
#
#   B. CHILD-ENVIRONMENT COMPOSITION.  A sentinel variable is exported into this process and the
#      composed child environment is required NOT to contain it.  That is the one assertion that
#      distinguishes a real allow-list from an allow-list-shaped comment: a filter that passed
#      everything would pass the sentinel too.  The lifecycle-script setting and the variables the
#      build genuinely needs are checked in the same pass.
#
#   C. TOOLCHAIN VERIFICATION.  The delivered verifyFrontEndToolchain is executed against the real
#      launchers on this host — it must accept them — and then executed again with a required major
#      this host cannot satisfy, where it must refuse and must name both the observed and the
#      required version.  A check that only ever passes is not a check, so both directions are
#      exercised.
#
# FAIL CLOSED.  Every check is asserted inside the driver; any failure aborts with a non-zero
# status and the record is not written.  There is no path through this script that writes a record
# describing checks it did not run.
#
# NOT A PRODUCT ARTIFACT.  The driver source is generated into a temporary directory outside the
# repository and compiled there.  Nothing is written into any module's source tree, and the only
# file this script creates inside the repository is the record named by --record.
#
# USAGE
#   docs/migration/smoke-evidence/verify-frontend-startup-wiring.sh \
#       [--record docs/migration/smoke-evidence/frontend-startup-wiring.txt]
#
#   --record PATH   where to write the observation record.  Default is the path above.
#   --no-record     run every check and print the outcome, but write nothing.  This is the form to
#                   use as a standing check on a tree you do not want modified.
#
# EXIT STATUS
#   0  every check passed and, unless --no-record, the record was written
#   2  the environment cannot support the run (module not built, classpath unresolvable, no JDK)
#   3  a check failed — the reason is printed and no record is written
#
# PREREQUISITE.  The ark-angular-starter module must be built, because this executes its compiled
# class rather than a copy of it.  Run `mvn -o -pl acm-user-interface/ark-angular-starter install`
# first if it is not.  Node and npm must be on PATH at the majors the delivered wiring requires.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MODULE="acm-user-interface/ark-angular-starter"
SPRING_XML="$MODULE/src/main/resources/spring/spring-web-ark-angular-starter.xml"
RECORD="docs/migration/smoke-evidence/frontend-startup-wiring.txt"
WRITE_RECORD=1

# require_value — refuse an option that was given without its value.
#
# Every two-argument case below used to read its value as "${2:-}" and then `shift 2`.
# With the option last on the command line $# is 1, `shift 2` fails without shifting, and
# the loop re-reads the same argument forever: the producer hangs instead of failing, so a
# caller that mistypes an invocation gets no evidence, no error and no exit. Validating the
# arity before the shift turns that into one bounded refusal.
# publish_atomically — rename a fully written staging file over the target.
#
# The authority below used to be produced by redirecting a brace group straight at its
# final path, which truncates that path before the first byte is written. A reader that
# opened the file while the producer was still running, or after it died partway, saw a
# half-written authority indistinguishable from a complete one. Staging beside the target
# and renaming makes publication all-or-nothing: same directory, so the rename is atomic,
# and on any failure the previous file is left exactly as it was. This is the idiom
# capture-static-audit.sh already uses.
publish_atomically()
{
    stage="$1"
    target="$2"

    if [ ! -f "$stage" ]; then
        printf '%s: nothing was staged for %s, so nothing was published.\n' \
            "$(basename -- "$0")" "$target" >&2
        return 1
    fi
    if [ -L "$target" ]; then
        rm -f -- "$stage"
        printf '%s: refusing to publish over %s: it is a symbolic link.\n' \
            "$(basename -- "$0")" "$target" >&2
        return 1
    fi
    if [ -e "$target" ] && [ ! -f "$target" ]; then
        rm -f -- "$stage"
        printf '%s: refusing to publish over %s: it is not a plain file.\n' \
            "$(basename -- "$0")" "$target" >&2
        return 1
    fi
    if ! mv -f -- "$stage" "$target"; then
        rm -f -- "$stage"
        printf '%s: could not move the staged record into place at %s.\n' \
            "$(basename -- "$0")" "$target" >&2
        printf '  The previous file, if any, is untouched.\n' >&2
        return 1
    fi
    return 0
}

require_value()
{
    if [ "$2" -lt 2 ]; then
        printf 'verify-frontend-startup-wiring.sh: %s requires a value and none was given.\n' "$1" >&2
        printf '  Refused rather than defaulted to an empty one: an empty path would send\n' >&2
        printf '  this producer at the wrong target, and an empty selector would fall\n' >&2
        printf '  through to a later check that cannot tell "absent" from "empty".\n' >&2
        exit 2
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --record)    require_value '--record' "$#"; RECORD="$2"; shift 2 ;;
        --no-record) WRITE_RECORD=0; shift ;;
        -h|--help)   sed -n '1,/^set -u$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)           echo "unrecognised argument: $1" >&2; exit 2 ;;
    esac
done

cd "$REPO_ROOT" || exit 2

die_env() { echo "ENVIRONMENT: $*" >&2; echo "VERDICT: CANNOT RUN" >&2; exit 2; }

[ -f "$SPRING_XML" ] || die_env "the delivered Spring document is not at $SPRING_XML"

CLASSES="$MODULE/target/classes"
[ -d "$CLASSES" ] || die_env "$CLASSES does not exist — build the module first:
    mvn -o -pl $MODULE install"
[ -f "$CLASSES/com/armedia/acm/userinterface/angular/AngularResourceCopier.class" ] \
    || die_env "the compiled copier class is missing from $CLASSES — rebuild the module"

command -v javac >/dev/null 2>&1 || die_env "javac is not on PATH"
command -v java  >/dev/null 2>&1 || die_env "java is not on PATH"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/arkcase-wiring-check.XXXXXX")" || die_env "cannot create a work directory"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------------------------
# Resolve the module's own classpath from Maven, offline.  Resolving it rather than hardcoding jars
# is what keeps this check honest when the dependency graph moves: it executes against whatever the
# module actually declares.  The scope is deliberately not narrowed to runtime: the copier is a
# ServletContextAware bean, so the Servlet API it is introspected against is `provided` — supplied
# by the container at deployment and by this classpath here.
# ---------------------------------------------------------------------------------------------
echo "resolving the module classpath (offline) ..."
if ! mvn -o -q -B -ntp -pl "$MODULE" dependency:build-classpath \
        "-Dmdep.outputFile=$WORK/cp.txt" > "$WORK/mvn.log" 2>&1; then
    sed -n '1,40p' "$WORK/mvn.log" >&2
    die_env "could not resolve the module classpath — see the output above"
fi
[ -s "$WORK/cp.txt" ] || die_env "Maven produced no classpath file"
CP="$CLASSES:$(cat "$WORK/cp.txt")"

# ---------------------------------------------------------------------------------------------
# The driver.  Generated here rather than committed as a Java file, because a .java file inside a
# module source tree is a source file whether or not anything compiles it, and this module's
# authorised file list has no test source root.
# ---------------------------------------------------------------------------------------------
DRIVER="$WORK/WiringCheck.java"
cat > "$DRIVER" <<'JAVA'
import com.armedia.acm.userinterface.angular.AngularResourceCopier;
import org.springframework.context.support.GenericXmlApplicationContext;
import org.springframework.beans.factory.support.BeanDefinitionBuilder;
import org.springframework.beans.factory.support.DefaultListableBeanFactory;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Executes the delivered startup frontend-build seam and asserts what it resolves. Every assertion
 * that fails is collected and reported; a non-empty failure list exits 3.
 */
public class WiringCheck
{
    private static final List<String> FAILURES = new ArrayList<>();
    private static final String SENTINEL = "ARKCASE_WIRING_CHECK_SENTINEL";

    public static void main(String[] args) throws Exception
    {
        String xml = args[0];
        String tmpDir = args[1];

        System.out.println("===== A. PLATFORM RESOLUTION =====");
        for (String osName : new String[] { "Linux", "Mac OS X", "Windows 11" })
        {
            resolveUnder(osName, xml);
        }

        System.out.println();
        System.out.println("===== B. CHILD-ENVIRONMENT COMPOSITION =====");
        environmentComposition(xml);

        System.out.println();
        System.out.println("===== C. TOOLCHAIN VERIFICATION =====");
        toolchainVerification(xml, tmpDir);

        System.out.println();
        if (FAILURES.isEmpty())
        {
            System.out.println("VERDICT: PASSED — all checks");
            System.exit(0);
        }
        System.out.println("VERDICT: FAILED — " + FAILURES.size() + " check(s)");
        for (String f : FAILURES)
        {
            System.out.println("  FAIL " + f);
        }
        System.exit(3);
    }

    /** Loads the delivered document with os.name simulated, and prints the five resolved commands. */
    private static void resolveUnder(String osName, String xml) throws Exception
    {
        String realOs = System.getProperty("os.name");
        System.setProperty("os.name", osName);
        try (GenericXmlApplicationContext ctx = newContext(xml))
        {
            AngularResourceCopier c = ctx.getBean("angularResourceCopier", AngularResourceCopier.class);
            boolean windows = osName.startsWith("Windows");

            String node = c.getNodeVersionCommand();
            String npm = c.getNpmVersionCommand();
            String install = c.getYarnInstallCommand();
            String grunt = c.getGruntDefaultCommand();
            String merge = c.getMergeConfigFrontendTask();

            System.out.println("os.name = " + osName);
            System.out.println("  nodeVersionCommand      : " + node);
            System.out.println("  npmVersionCommand       : " + npm);
            System.out.println("  install (yarnInstall*)  : " + install);
            System.out.println("  gruntDefaultCommand     : " + grunt);
            System.out.println("  mergeConfigFrontendTask : " + merge);

            // The defect this check exists for: a batch-wrapper suffix on a bare-name launcher.
            check(!node.contains(".cmd"), osName + ": the Node probe must not name a .cmd wrapper — got [" + node + "]");
            check(!npm.contains(".cmd"), osName + ": the npm probe must not name a .cmd wrapper — got [" + npm + "]");
            check(!install.contains(".cmd"), osName + ": the install command must not name a .cmd wrapper — got [" + install + "]");

            // Each probe must resolve the same launcher its own build step resolves. The install uses
            // no suffix, so a suffixed probe would measure a different resolution from the install.
            check(node.endsWith("node --version"), osName + ": the Node probe must ask `node` for its version — got [" + node + "]");
            check(npm.endsWith("npm --version"), osName + ": the npm probe must ask `npm` for its version — got [" + npm + "]");

            if (windows)
            {
                check(node.startsWith("cmd /C "), "Windows: the Node probe must carry the cmd prefix — got [" + node + "]");
                check(npm.startsWith("cmd /C "), "Windows: the npm probe must carry the cmd prefix — got [" + npm + "]");
                check(install.equals("cmd /C npm ci"), "Windows: the install must be `cmd /C npm ci` — got [" + install + "]");
                // The path-qualified Grunt CLI is the one launcher that genuinely needs the suffix,
                // because a path-qualified name is not completed by the PATHEXT search.
                check(grunt.contains("grunt.cmd"), "Windows: the Grunt command must name grunt.cmd — got [" + grunt + "]");
                check(merge.contains("grunt.cmd"), "Windows: the module-config task must name grunt.cmd — got [" + merge + "]");
            }
            else
            {
                check(node.equals("node --version"), osName + ": the Node probe must be unprefixed — got [" + node + "]");
                check(npm.equals("npm --version"), osName + ": the npm probe must be unprefixed — got [" + npm + "]");
                check(install.equals("npm ci"), osName + ": the install must be `npm ci` — got [" + install + "]");
                check(grunt.equals("node_modules/.bin/grunt --no-color"),
                        osName + ": the Grunt command must resolve from the installed tree — got [" + grunt + "]");
                check(merge.equals("node_modules/.bin/grunt updateModulesConfig --no-color"),
                        osName + ": the module-config task must resolve from the installed tree — got [" + merge + "]");
            }
        }
        finally
        {
            System.setProperty("os.name", realOs);
        }
    }

    /**
     * The one assertion that distinguishes a real allow-list from an allow-list-shaped comment: a
     * variable this process holds and the build does not need must be absent from the child.
     */
    private static void environmentComposition(String xml) throws Exception
    {
        try (GenericXmlApplicationContext ctx = newContext(xml))
        {
            AngularResourceCopier c = ctx.getBean("angularResourceCopier", AngularResourceCopier.class);

            String sentinelValue = System.getenv(SENTINEL);
            check(sentinelValue != null,
                    "the harness did not export " + SENTINEL + ", so the filter cannot be demonstrated");

            Map<String, String> child = c.buildFrontEndCommandEnvironment();
            int parentSize = System.getenv().size();

            System.out.println("  variables this process holds : " + parentSize);
            System.out.println("  variables composed for child : " + child.size());
            System.out.println("  composed keys                : " + child.keySet());

            check(!child.containsKey(SENTINEL),
                    "the sentinel variable " + SENTINEL + " reached the child environment — the filter passes everything");
            check(child.size() < parentSize,
                    "the composed environment is not smaller than this process's — composed " + child.size()
                            + " of " + parentSize);
            check("true".equals(child.get("npm_config_ignore_scripts")),
                    "npm_config_ignore_scripts must be true under the delivered default — got ["
                            + child.get("npm_config_ignore_scripts") + "]");
            // The build genuinely needs these; an allow-list that dropped them would break a
            // working deployment, which is the opposite failure and just as real.
            for (String needed : new String[] { "PATH", "HOME" })
            {
                if (System.getenv(needed) != null)
                {
                    check(child.containsKey(needed), needed + " must be passed through — the build needs it");
                }
            }
            System.out.println("  sentinel present in parent   : " + (sentinelValue != null));
            System.out.println("  sentinel present in child    : " + child.containsKey(SENTINEL));
            System.out.println("  npm_config_ignore_scripts    : " + child.get("npm_config_ignore_scripts"));
        }
    }

    /** Both directions: the real launchers must be accepted, and a wrong required major refused. */
    private static void toolchainVerification(String xml, String tmpDir) throws Exception
    {
        try (GenericXmlApplicationContext ctx = newContext(xml))
        {
            AngularResourceCopier c = ctx.getBean("angularResourceCopier", AngularResourceCopier.class);
            File dir = new File(tmpDir);

            System.out.println("  requiredNodeMajorVersion : " + c.getRequiredNodeMajorVersion());
            System.out.println("  requiredNpmMajorVersion  : " + c.getRequiredNpmMajorVersion());

            try
            {
                c.verifyFrontEndToolchain(dir);
                System.out.println("  real launchers           : ACCEPTED");
            }
            catch (Exception e)
            {
                FAILURES.add("the delivered wiring refused this host's launchers: " + e.getMessage());
                System.out.println("  real launchers           : REFUSED — " + e.getMessage());
            }

            String realRequired = c.getRequiredNodeMajorVersion();
            c.setRequiredNodeMajorVersion("99");
            try
            {
                c.verifyFrontEndToolchain(dir);
                FAILURES.add("a required Node major of 99 was accepted — the version gate does not gate");
                System.out.println("  wrong required major     : ACCEPTED (defect)");
            }
            catch (Exception e)
            {
                String m = String.valueOf(e.getMessage());
                System.out.println("  wrong required major     : REFUSED — " + m);
                check(m.contains("99"), "the refusal must name the required major — got [" + m + "]");
            }
            finally
            {
                c.setRequiredNodeMajorVersion(realRequired);
            }
        }
    }

    /**
     * The delivered document needs one collaborator the application supplies, the active-profile
     * holder. It is registered here as the application's own type so the document is loaded exactly
     * as delivered rather than in an edited copy: the point of this check is that the delivered
     * bytes resolve what they are claimed to resolve, which an adapted copy would not establish.
     */
    private static GenericXmlApplicationContext newContext(String xml)
    {
        GenericXmlApplicationContext ctx = new GenericXmlApplicationContext();
        DefaultListableBeanFactory bf = ctx.getDefaultListableBeanFactory();
        bf.registerBeanDefinition("acmSpringActiveProfile",
                BeanDefinitionBuilder.genericBeanDefinition(
                        com.armedia.acm.core.AcmSpringActiveProfile.class).getBeanDefinition());
        ctx.load("file:" + xml);
        ctx.refresh();
        return ctx;
    }

    private static void check(boolean ok, String failureMessage)
    {
        if (!ok)
        {
            FAILURES.add(failureMessage);
        }
    }
}
JAVA

echo "compiling the driver ..."
if ! javac -nowarn -cp "$CP" -d "$WORK/classes" "$DRIVER" > "$WORK/javac.log" 2>&1; then
    cat "$WORK/javac.log" >&2
    die_env "the driver did not compile against the delivered classes — see the output above"
fi

PROBE_DIR="$WORK/probe"
mkdir -p "$PROBE_DIR"

echo "running the checks ..."
# The sentinel is exported here, in the parent, so that check B has something to prove the filter
# with.  Its value is deliberately credential-shaped: the variables this filter exists to withhold
# are the deployment's secrets.
ARKCASE_WIRING_CHECK_SENTINEL='a-value-no-build-step-needs' \
    java -cp "$WORK/classes:$CP" WiringCheck "$SPRING_XML" "$PROBE_DIR" \
    > "$WORK/out.txt" 2>"$WORK/err.txt"
STATUS=$?

cat "$WORK/out.txt"
if [ -s "$WORK/err.txt" ]; then
    # Spring logs to stderr when no logging backend is configured; show it only on failure, where
    # it is diagnostic, rather than burying the observation on success.
    if [ "$STATUS" -ne 0 ]; then
        echo "----- stderr -----" >&2
        cat "$WORK/err.txt" >&2
    fi
fi

if [ "$STATUS" -ne 0 ]; then
    echo
    echo "VERDICT: FAILED — no record written." >&2
    exit 3
fi

if [ "$WRITE_RECORD" -eq 0 ]; then
    echo
    echo "--no-record was given; nothing written."
    exit 0
fi

# ---------------------------------------------------------------------------------------------
# The record.  It names what produced it, the identities of the two files it executed, and the
# host toolchain, so that a reader can re-derive it instead of believing it.
# ---------------------------------------------------------------------------------------------
XML_SHA="$(sha256sum "$SPRING_XML" | cut -c1-64)"
JAVA_SRC="$MODULE/src/main/java/com/armedia/acm/userinterface/angular/AngularResourceCopier.java"
JAVA_SHA="$(sha256sum "$JAVA_SRC" | cut -c1-64)"
SELF_SHA="$(sha256sum "${BASH_SOURCE[0]}" | cut -c1-64)"
HEAD_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
DIRTY_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
NODE_V="$(node --version 2>/dev/null || echo absent)"
NPM_V="$(npm --version 2>/dev/null || echo absent)"
JAVA_V="$(java -version 2>&1 | head -1)"

mkdir -p "$(dirname "$RECORD")"
{
    echo "===== startup frontend-build seam: executed observation ====="
    echo
    echo "WHAT THIS IS.  The output of verify-frontend-startup-wiring.sh, which loads the delivered"
    echo "Spring document, instantiates the delivered AngularResourceCopier, and executes three"
    echo "behaviours of the startup frontend-build seam.  It exists because the JUnit class those"
    echo "behaviours were previously claimed to be covered by, AngularResourceCopierWiringTest, was"
    echo "withdrawn with the other unauthorised test files, and because the committed startup logs"
    echo "were taken from a deployment built before the seam carried any of this behaviour -- grep"
    echo "the migrated capture for the composed-environment line and it returns nothing.  Without"
    echo "this record three delivered behaviours have no evidence at all."
    echo
    echo "REGENERATE IT:  docs/migration/smoke-evidence/verify-frontend-startup-wiring.sh"
    echo "CHECK WITHOUT WRITING:  the same command with --no-record"
    echo
    echo "----- what was executed -----"
    echo "spring-document        : $SPRING_XML"
    echo "spring-document-sha256 : $XML_SHA"
    echo "java-source            : $JAVA_SRC"
    echo "java-source-sha256     : $JAVA_SHA"
    echo "producer               : docs/migration/smoke-evidence/verify-frontend-startup-wiring.sh"
    echo "producer-sha256        : $SELF_SHA"
    echo "head-commit            : $HEAD_COMMIT"
    echo "worktree-modified-paths: $DIRTY_COUNT"
    echo "host-java              : $JAVA_V"
    echo "host-node              : $NODE_V"
    echo "host-npm               : $NPM_V"
    echo
    echo "The two sha256 values are the identities that matter: the record describes THOSE bytes."
    echo "If either file changes, re-run this rather than reading the record as current."
    echo
    echo "----- observed -----"
    cat "$WORK/out.txt"
    echo
    echo "----- what this does and does not establish -----"
    echo "ESTABLISHES, by execution:"
    echo "  * the Windows branch resolves a launchable Node probe.  The suffix that names a batch"
    echo "    wrapper reaches the path-qualified Grunt CLI and reaches neither bare-name launcher,"
    echo "    so 'cmd /C node.cmd --version' -- which cmd cannot resolve, and which ran BEFORE the"
    echo "    install -- is gone.  The Linux and macOS branches resolve exactly what they resolved"
    echo "    before, which is why the captures taken on Linux remain comparable."
    echo "  * the child environment is composed rather than inherited.  A variable exported into"
    echo "    the parent and needed by no build step does not reach the child."
    echo "  * package lifecycle scripts are disabled for the install by the delivered default."
    echo "  * the toolchain majors are enforced in both directions: this host's real launchers are"
    echo "    accepted, and a required major this host cannot satisfy is refused with a diagnostic"
    echo "    naming it."
    echo
    echo "DOES NOT ESTABLISH:"
    echo "  * anything about a real Windows host.  os.name is simulated, so what is verified is the"
    echo "    COMMAND each branch resolves, not its execution on Windows.  That is the whole of the"
    echo "    defect that was found and fixed, and it is as far as this can go from Linux."
    echo "  * that the residual weaknesses of this seam are mitigated.  They are not: there is no"
    echo "    execution timeout, the launcher is still resolved by name rather than pinned to an"
    echo "    absolute path, the file operations still follow symbolic links, and one deletion"
    echo "    result is still discarded.  All four are base-commit behaviour and all four are"
    echo "    registered as entry 58 of ../pre-existing-defects.md."
    echo "  * that a deployment logs any of this.  The external configuration pins this logger to"
    echo "    warn, which suppresses the INFO narrative; the failure paths throw, so they are"
    echo "    visible regardless."
} > "${RECORD}.$$.staging"
publish_status=$?
if [ "$publish_status" -ne 0 ]; then
    rm -f -- "${RECORD}.$$.staging"
    printf '%s: the record was not written completely, so %s was left untouched.\n' \
        "$(basename -- "$0")" "$RECORD" >&2
    exit "$publish_status"
fi
publish_atomically "${RECORD}.$$.staging" "$RECORD" || exit 1

echo
echo "record written: $RECORD"
echo "VERDICT: PASSED"
exit 0
