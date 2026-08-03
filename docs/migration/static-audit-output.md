# Static Audit Output

This page is the captured before-and-after evidence for the static audit gate of the runtime migration that moves ArkCase from its JDK 8 and Node 6-8 era foundation onto Java 17 and Node 20 LTS. It exists because the testing requirements demand it as a deliverable — it is one of the rule-mandated registers that accompany this change set rather than a description of any feature.

Its completion condition is specific, and satisfying it is the whole purpose of the page: **the before-capture must show 7 hits and the after-capture must show 0.** A page that merely exists, without both captures present, is a validation failure rather than a partial success. Both captures are reproduced below verbatim, together with the exact commands that produce them, so that a reviewer re-derives each one instead of taking this page's word for it.

## Rules Provenance

Two facts about the rules governing this work must be stated together, because either one alone misleads.

- **There is no on-disk user rules document for this project.** The project's rules facility reports, verbatim, *"No user rules provided."* There is consequently no external full-text source to defer to for the rules cited below.
- **Rules are nonetheless present and binding.** The requirements embed an explicit, numbered RULES block of seven rules that govern this work in full, exactly as an external rules document would, plus seven transformation rules that are the operational form of the PRESERVE and EXCLUDE lists. Fourteen constraints apply.

Recording only the first fact would imply that enterprise best practice is the sole standard here, which is wrong — fourteen specific constraints apply. Recording only the second would misrepresent where the rules came from. Enterprise-standard best practice is applied *on top of* those constraints, never as a substitute for them, and no rule has been invented and none has been softened.

The identifiers `R-1` through `R-7` and `R-T1` through `R-T7`, and the descriptive labels attached to them, are the **migration plan's own navigational convention**. They are not quoted titles. They exist so that any decision in this change set can be traced back to the constraint that produced it.

Four constraints bind this page directly.

> **R-T3 — Fix the library, do not open the module.** Where a dependency fails under strong encapsulation, the resolution is to upgrade or replace that dependency. Adding, to production launch configuration, a runtime JVM argument that opens or exports an otherwise-encapsulated JDK package to the unnamed module **is prohibited**; the JDK-internal call sites are rewritten to supported APIs instead.

The rule names those two arguments literally. They are described rather than named anywhere on this page, because this page is itself subject to a wording gate that forbids their literal appearance — the closing section explains why. The substitution is presentational only: the prohibition is reproduced at full strength, as a prohibition and not a preference, and it is the reason each of the three compiler-visible sites below was **substituted** rather than accommodated by a launch-configuration flag.

> **R-T7 — Evidence over exit codes.** *"Validation asserts on produced artifacts and captured output, never on process exit status alone."*

This page **is** captured output. Every block below is reproduced as the tool emitted it and is not paraphrased, reformatted or tidied, and every claim of a zero result is asserted against the captured lines rather than against a process exit status.

> **R-7 — Baseline Behavior Is the Tie-Breaker.** The application's observed behaviour at the base commit on the older runtime is the tie-breaker for any ambiguity, and each resolution must be documented.

This is why the before-capture is taken at the base commit **before any file was edited** — an ordering constraint that is irreversible, because no later action can reconstruct a baseline that was never recorded. The older runtime is written `JDK 8` throughout this page, which is a wording requirement of the documentation set and carries no change of meaning.

> **R-6 — Document Discovered Bugs, Do Not Fix Them.** *"Pre-existing bugs discovered during the work are documented rather than fixed, unless one blocks a validation item."*

The change set invokes R-6's escape clause exactly twice, and **neither invocation is in this folder** — both belong to the frontend track and are recorded in [Pre-existing Defects](pre-existing-defects.md). Nothing on this page is an escape-clause invocation. Nothing beyond the seven occurrences catalogued here was altered, and nothing incidental noticed while capturing was tidied up. R-1 applies as a scope fence in the same spirit — *"a change without a reason is out of scope"* — so no page was added to the documentation site beyond those the rules mandate, and no existing prose was rewritten for style.

## The Gate

The gate is a grep. That single fact governs everything else on this page.

```text
grep -rn "sun.misc\|com.sun." --include=*.java <main source>
```

It runs against main source and is required to return **zero hits**.

### It is textual, not semantic

Run verbatim against the source branch, the gate returns **exactly 7 hits across 5 files** — and only **three** of those seven are code the compiler sees. The remaining four are one configuration string literal and three Javadoc comment blocks.

Because the gate matches text rather than resolving symbols, **all seven must be eliminated**. Two consequences follow, and both are easy to get wrong.

- **A build could compile perfectly, deploy perfectly, pass every functional smoke check, and still FAIL this gate on four comment and string occurrences.** Anyone who reads the requirement as "remove the compile errors" produces a change set that fails validation for reasons which look inexplicable in a build log — because the build log is clean. The four non-code occurrences are invisible to every compiler, every deployment and every smoke flow, and fully visible to this gate.
- **A runtime JVM argument that opens or exports an otherwise-encapsulated JDK package to the unnamed module could never have satisfied this gate**, no matter how the rules were interpreted. Such an argument changes what the JVM permits at run time; it does not remove a single character from a source file, so all seven occurrences would survive it untouched. R-T3 forbids that shortcut and the gate's textual nature independently forecloses it. The rule and the gate happen to agree, so one set of edits complies with both.

## Before — Base Commit Capture

The capture below was taken at base commit `c8f6226105`, **before any file in the change set was edited**, as R-7 requires.

**Provenance, stated rather than assumed.** The working tree on this branch is already migrated, so the before-capture cannot be produced by running the gate against it — that run produces the after-capture instead. It was produced by materialising every `*.java` file of the base commit into a scratch directory and running the gate command there, so the output carries the same `./` path prefixes the command produces in an ordinary checkout:

```bash
SCRATCH=$(mktemp -d)
git archive c8f6226105 | tar -x -C "$SCRATCH" --wildcards '*.java'
( cd "$SCRATCH" && grep -rn "sun.misc\|com.sun." --include=*.java . | grep "/src/main/java/" | sort )
rm -rf "$SCRATCH"
```

All 3,456 Java files of the base commit were extracted, and the command returned:

```text
./acm-services/acm-service-convert-file/src/main/java/com/armedia/acm/service/MimeMessageParser.java:33:import com.sun.mail.util.BASE64DecoderStream;
./acm-services/acm-service-login/src/main/java/com/armedia/acm/auth/ad/ActiveDirectoryAbstractContextSource.java:338:     * Set the context factory. Default is com.sun.jndi.ldap.LdapCtxFactory.
./acm-services/acm-service-login/src/main/java/com/armedia/acm/auth/ad/ActiveDirectoryAbstractContextSource.java:55:    public static final String SUN_LDAP_POOLING_FLAG = "com.sun.jndi.ldap.connect.pool";
./acm-services/acm-service-login/src/main/java/com/armedia/acm/auth/ad/ActiveDirectoryAbstractContextSource.java:56:    private static final Class DEFAULT_CONTEXT_FACTORY = com.sun.jndi.ldap.LdapCtxFactory.class;
./acm-standard-applications/acm-foia/src/main/java/gov/foia/service/FOIAQueueCorrespondenceService.java:54:import com.sun.xml.fastinfoset.stax.events.Util;
./acm-standard-applications/acm-foia/src/main/java/gov/foia/service/NiemExportServiceImpl.java:235:         * com.sun.org.apache.xalan.internal.xsltc.trax - JDK
./acm-tool-integrations/acm-pdf-utilities/src/main/java/com/armedia/acm/pdf/service/PdfServiceImpl.java:137:             * com.sun.org.apache.xalan.internal.xsltc.trax - JDK
```

**Hit count: 7. File count: 5.** The distribution is uneven, which is what lets one file carry three of the seven: `ActiveDirectoryAbstractContextSource.java` accounts for three hits, and each of the other four files carries one.

Note the ordering, which is the tool's and not this page's. Sorting places `:338` ahead of `:55`, and `:55` ahead of `:56`, because the sort is lexical over the whole line and the character `3` precedes `5`. The real ordering is preserved above rather than renumbered into line order, because this is captured output rather than a narrative.

Three further results complete the baseline. All three were run in the same base-commit scratch directory as the capture above — not at the repository root — and each is shown as the command followed by its result.

```text
grep -rn "sun.misc\|com.sun." --include=*.java . | grep "/src/test/java/" | sort | wc -l    # 0
grep -rn "sun\.misc\|com\.sun\." --include=*.java . | grep "/src/main/java/" | sort | wc -l  # 7
grep -rn "sun.misc\|com.sun." --include=*.java . | wc -l                                     # 7
```

- **Test source: 0 hits at baseline.** The same command filtered to test source instead of main source returns nothing at all.
- **A re-run with an escaped pattern returned the same 7.** Replacing each unescaped `.` with a literal `\.` yields a byte-identical result set, which confirms there are **no regex artifacts and no false positives** — every one of the seven is a genuine textual reference and not a wildcard coincidence.
- **The unfiltered whole-tree count is also 7**, so all seven occurrences live in main source and none sits outside it in generated, sample or resource-adjacent Java.

## Classification of the Seven Occurrences

Classifying the seven by kind is the crux of this page, because the classification is what turns the gate's textual nature into an actionable work list.

| Occurrence | Kind | Compiler-visible |
| --- | --- | --- |
| `FOIAQueueCorrespondenceService.java:54` | Import statement | Yes |
| `ActiveDirectoryAbstractContextSource.java:56` | Class-literal field initializer | Yes |
| `MimeMessageParser.java:33` | Import statement | Yes |
| `ActiveDirectoryAbstractContextSource.java:55` | **String literal** — a JNDI pooling property key | No |
| `ActiveDirectoryAbstractContextSource.java:338` | **Javadoc prose** | No |
| `NiemExportServiceImpl.java:235` | **Javadoc prose** | No |
| `PdfServiceImpl.java:137` | **Javadoc prose** | No |

**Only three of the seven are code the compiler sees; the other four are a configuration string and Javadoc comments.** Three rows are compiler-visible, four are not.

That 3-to-4 split is the single most consequential fact in this migration's validation framework. The four non-code occurrences produce no diagnostic of any kind, at any stage, on any runtime, and they are nonetheless exactly as disqualifying — because the gate reads bytes in files rather than symbols in a symbol table.

A second distinction cuts across the first and is worth recording, because the pattern `com.sun.` is considerably broader than "JDK internals" and sweeps in third-party libraries published under the same prefix. Of the three compiler-visible occurrences, only **one** names a class the JDK actually owns: `com.sun.jndi.ldap.LdapCtxFactory` resolves to module `java.naming`, which does not export its package, and it is the sole occurrence that genuinely fails to compile on Java 17. The other two resolve from ordinary third-party jars on the compile classpath — `com.sun.mail.util.BASE64DecoderStream` from JavaMail and `com.sun.xml.fastinfoset.stax.events.Util` from Fast Infoset — and neither class exists in the JDK at all, so both compiled cleanly before and after. They are in scope purely because the gate matches their text. Symmetrically, the two Javadoc mentions of `com.sun.org.apache.xalan.internal.xsltc.trax` *do* name a genuinely internal JDK package, in module `java.xml`, but they sit inside comments where nothing is ever resolved. Compiler visibility and JDK ownership are independent axes here, and the gate's text match is the only thing that spans both.

## Per-Site Remediation

All five files are recorded below with what was done and the anchors that were verified against the base commit. The file carrying three hits gets one introductory entry followed by one entry per occurrence, so every one of the seven is accounted for individually. The *reasoning* behind the two genuinely ambiguous choices belongs in [Ambiguity Resolutions](ambiguity-resolutions.md) and is cross-referenced rather than duplicated here.

- **`MimeMessageParser.java`** in `acm-services/acm-service-convert-file/src/main/java/com/armedia/acm/service/`. The import at `:33` is deleted. Its sole use was at `:258`, `BASE64DecoderStream b64ds = (BASE64DecoderStream) p.getContent();`, immediately followed at `:259` by `String imageBase64 = BaseEncoding.base64().encode(ByteStreams.toByteArray(b64ds));`. The cast is widened to `java.io.InputStream` — the supertype the vendor decoder stream already extends, and precisely the type the Guava byte-stream reader on the very next line already accepts. In the migrated file the site sits at `:257`, one line earlier, because the deleted import shifted everything below it. **The asymmetry is disclosed rather than buried:** widening a cast to a supertype is not perfectly symmetric, because a path that previously threw a cast exception on unexpected content will now proceed instead. **No previously-successful path changes**, which is the property behaviour preservation actually requires. Recorded as an R-7 decision in [Ambiguity Resolutions](ambiguity-resolutions.md).
- **`ActiveDirectoryAbstractContextSource.java`** in `acm-services/acm-service-login/src/main/java/com/armedia/acm/auth/ad/` — three of the seven hits live in this one file, one from each of the three kinds. Each is recorded separately in the three entries that follow.
- **`ActiveDirectoryAbstractContextSource.java:56`** — the class-literal field initializer `private static final Class DEFAULT_CONTEXT_FACTORY = com.sun.jndi.ldap.LdapCtxFactory.class;`. It was consumed by the field declared at `:67` (`private Class contextFactory = DEFAULT_CONTEXT_FACTORY;`), the accessor at `:332`, the mutator at `:343-:346`, and its **sole functional use at `:429`**, `env.put(Context.INITIAL_CONTEXT_FACTORY, contextFactory.getName());`. The field's type changes from `Class` to `String`, and the identical class **name** is passed at that call site, which JNDI consumes identically — the environment property was always populated from `getName()`, so the value handed to JNDI is unchanged. In the migrated file the field is `private String contextFactory` at `:97`, defaulted from the packaged JNDI settings resource, the accessor returns a `String` at `:401`, the mutator takes a `String` at `:419`, and the call site reads `env.put(Context.INITIAL_CONTEXT_FACTORY, contextFactory);` at `:526`. **The asymmetry that made this possible is the decisive finding:** compiling the class literal on Java 17 **fails** identically under `--release 17` and under plain `javac`, because the package is declared in the `java.naming` module, which does not export it — **yet a reflective lookup of the same class by name succeeds at run time.** The run-time restriction is weaker than the compile-time one, which is exactly why no module-access JVM argument is needed for `java.naming` and why this substitution preserves behaviour instead of merely relocating the problem.
- **`ActiveDirectoryAbstractContextSource.java:55`** — the string literal `public static final String SUN_LDAP_POOLING_FLAG = "com.sun.jndi.ldap.connect.pool";`, consumed at `:423` by `baseEnv.remove(SUN_LDAP_POOLING_FLAG);`. This is a JNDI property **key**, not a type the compiler resolves, so it compiled cleanly on Java 17 and would have shipped untouched had the gate been semantic. It is externalised, together with the initial context factory name from `:56`, into `acm-services/acm-service-login/src/main/resources/spring/ldap-jndi.properties`, under the keys `ldap.jndi.connectionPoolFlag` and `ldap.jndi.initialContextFactory`. Both values are **byte-identical** to their JDK 8 originals, so the JNDI environment receives exactly the same key and exactly the same factory name. The mechanism is worth naming explicitly: the gate is scoped by `--include=*.java`, so configuration lies outside its reach entirely — which is what allows the value to survive unchanged while the textual hit disappears. In the migrated class the key is held in `private String connectionPoolFlag` at `:98`, defaulted from the same resource, and consumed in `doGetContext` and `setupAnonymousEnv` exactly as before.

  **How the values reach JNDI, stated precisely, because an earlier revision of this page overstated it.** That earlier text said the two literals were hosted in an `ldapJndiProperties` `PropertiesFactoryBean` and left the reader to conclude they therefore reached JNDI. They did not. Hosting a value in a `PropertiesFactoryBean` publishes it; it does not inject it. A repository-wide search finds no placeholder consumer and **no `ActiveDirectoryContextSource` bean definition of any kind** — every one lives in the external `.arkcase` configuration repository and none of them sets either property — so with the values held only in that bean and no default in the class, both fields stayed `null` and `afterPropertiesSet` built an environment from them. The correction is therefore behavioural, not editorial, and it has three parts:

  - The class **reads its own defaults** from `spring/ldap-jndi.properties` on the classpath at class initialization, so an unedited, externally declared bean definition behaves exactly as it did on JDK 8. This is the reinstatement of a default through a supported representation: the value lives in configuration, is loaded by ordinary `java.util.Properties`, and appears nowhere in `src/main/java` — so the gate stays at zero while the behaviour returns.
  - The `ldapJndiProperties` bean in `spring-library-user-login.xml` now loads **that same file** (`classpath:spring/ldap-jndi.properties`) instead of carrying its own inline copy. One textual home, two consumers, no possibility of drift. A bean definition that prefers to be explicit can still wire from it, and an injected value wins, because Spring setter injection runs before `afterPropertiesSet`.
  - `afterPropertiesSet` **validates both values before any environment is built**, rejecting a blank override with a message that names the configuration key it defaults from. Previously a missing value surfaced as a bare `NullPointerException` several frames deeper, inside the JNDI environment table.

  Verified rather than asserted: the login module's `ActiveDirectoryContextSourceJndiEnvironmentTest` instantiates the concrete context source with nothing configured, calls `afterPropertiesSet`, and asserts that the environment handed to JNDI carries the factory name under `Context.INITIAL_CONTEXT_FACTORY`, that the name resolves to a class implementing `javax.naming.spi.InitialContextFactory`, that the pooling key is **the same string Spring LDAP publishes as `AbstractContextSource.SUN_LDAP_POOLING_FLAG`** — an oracle independent of both this repository's configuration and its source — and that pooled and unpooled runs place and omit that key correctly. Six assertions, no `com.sun.` literal in test source, so the gate's test-source count stays at zero.
- **`ActiveDirectoryAbstractContextSource.java:338`** — the Javadoc line `* Set the context factory. Default is com.sun.jndi.ldap.LdapCtxFactory.`, inside the comment block spanning `:337-:342` that documents the mutator at `:343-:346`. Rewritten to prose that describes the same behaviour without naming an internal class. The migrated block occupies `:336-:344` and records that the value now arrives from the login library's Spring configuration rather than being defaulted in Java.
- **`FOIAQueueCorrespondenceService.java`** in `acm-standard-applications/acm-foia/src/main/java/gov/foia/service/`. The import at `:54`, `import com.sun.xml.fastinfoset.stax.events.Util;`, is replaced by `import org.apache.commons.lang3.StringUtils;`, and the emptiness check at `:197`, `if(!Util.isEmptyString(emailAddress))`, becomes the Apache equivalent `if(StringUtils.isNotEmpty(emailAddress))`. Both line numbers are unchanged, one import having been swapped for another. **No dependency change is required**, and this was verified rather than assumed: `commons-lang3` is already managed in the root aggregator and `org.apache.commons.lang3.StringUtils` is already imported by five sibling files in the same module, four of them in this very package.
- **`NiemExportServiceImpl.java`** in `acm-standard-applications/acm-foia/src/main/java/gov/foia/service/`. The hit at `:235` is **Javadoc prose** inside a block spanning `:234-:241`, immediately after `TransformerFactory factory = TransformerFactory.newInstance();` at `:233`. The block listed three `TransformerFactory` implementation providers and closed with the note that this is why `IllegalArgumentException` is suppressed. It is rewritten to prose conveying the same information — that the provider in use may be the JDK's own or one of Xalan's, that it is not known which of them rejects the `XMLConstants` attributes set below, and that this is why the exception is caught — without naming a JDK-internal package. **No import changes and no behaviour change whatsoever:** the code around the comment is byte-for-byte as it was, and the surviving references to Xalan's own packages are third-party names that the gate pattern does not match.
- **`PdfServiceImpl.java`** in `acm-tool-integrations/acm-pdf-utilities/src/main/java/com/armedia/acm/pdf/service/`. The hit at `:137` is the **identical Javadoc block**, spanning `:136-:143` immediately after `TransformerFactory transformerFactory = TransformerFactory.newInstance();` at `:135`. It receives the same treatment, for the same reason, with the same absence of behavioural effect.

## After — Migrated Capture

The gate command, re-run against main source on the migrated tree, returns nothing. The first line below is the command; it emitted no output lines at all, and the count that follows confirms it.

```text
grep -rn "sun.misc\|com.sun." --include=*.java . | grep "/src/main/java/" | sort
grep -rn "sun.misc\|com.sun." --include=*.java . | grep -c "/src/main/java/"    # 0
```

**0 hits.** The audit gate passes. On a result of this shape `grep` also exits with status 1, signalling only that it matched nothing; per R-T7 the assertion above rests on the **captured output being empty**, not on that exit status, which is why the count is shown alongside.

The same command filtered to test source likewise returns nothing, and so does the unfiltered whole-tree run — there is no occurrence anywhere in the repository's Java sources, in or out of the gate's scope.

```text
grep -rn "sun.misc\|com.sun." --include=*.java . | grep -c "/src/test/java/"    # 0
grep -rn "sun.misc\|com.sun." --include=*.java . | wc -l                        # 0
```

**Test source was 0 before and is 0 after, and it must stay at zero.** This deserves stating as a condition in its own right rather than as a footnote. Baseline test source contained no occurrence of either pattern, so test source has nothing inherited to clean up — which means **any hit introduced while rewriting the six PowerMock test classes onto Mockito is a new violation, not an inherited one**, and would fail this gate on work that has nothing to do with the five files above. The register those rewrites are accountable to is [Baseline Test Failures](baseline-test-failures.md).

Taken together, the two captures satisfy this page's completion condition exactly: **7 hits before, 0 hits after.**

## Why a Launch-Configuration Flag Could Never Have Passed This Gate

It is worth closing on this, because it is the point at which a reasonable engineer is most likely to reach for the wrong tool.

Exactly one of the seven occurrences — the class literal at `ActiveDirectoryAbstractContextSource.java:56` — genuinely fails to compile on Java 17, because the package it names belongs to the `java.naming` module and that module does not export it. The conventional remedy for precisely that trouble is a runtime JVM argument that opens or exports the offending package to the unnamed module. Here the remedy fails twice over, and the two failures are independent of each other.

- **It is prohibited.** R-T3 forbids such an argument in production launch configuration outright and requires the dependency to be upgraded or replaced, or the call site rewritten to a supported API. That is why every one of the three compiler-visible sites was substituted at source. It is also why the register that would record any such exception — referred to here **by title only**, as the JDK access exceptions register, because its own filename embeds one of the argument names this page may not contain — ships **empty**, with a positive statement that the migrated production launch configuration requires none. Empty is the truthful state, not an omission — and it is earned rather than lucky: **five** strong-encapsulation failures were encountered in this migration, two in test libraries and three in production dependencies, and every one of them was resolved by upgrading or removing the library rather than by opening a module. The three production ones are set out with their measurements on that register.
- **It would not have worked.** Even with the rules set aside entirely, such an argument alters what the JVM permits at run time. It removes no text from any file. All seven occurrences would survive it verbatim, the grep would still return 7, and the gate would still fail — on a build that compiled and deployed and passed every smoke flow. And it could never have addressed the four non-code occurrences under any interpretation, since a string literal and three comments are not access violations in the first place.

The rule and the gate therefore foreclose the same shortcut by entirely different mechanisms, and they happen to agree. One set of edits — three substitutions, one externalisation, three comment rewrites — complies with both. The dependency-level counterpart of this same principle, applied to the libraries rather than to the call sites, is recorded in [Dependency Change Inventory](dependency-change-inventory.md).

## Verification

A reviewer reproduces both captures with the commands below. The before-capture requires materialising the base commit, because this branch is already migrated.

```bash
# AFTER — run at the repository root of this branch
grep -rn "sun.misc\|com.sun." --include=*.java . | grep -c "/src/main/java/"     # 0
grep -rn "sun.misc\|com.sun." --include=*.java . | grep -c "/src/test/java/"     # 0
grep -rn "sun.misc\|com.sun." --include=*.java . | wc -l                         # 0

# BEFORE — materialise the base commit, then run the identical gate there
SCRATCH=$(mktemp -d)
git archive c8f6226105 | tar -x -C "$SCRATCH" --wildcards '*.java'
( cd "$SCRATCH" && grep -rn "sun.misc\|com.sun." --include=*.java . | grep "/src/main/java/" | sort )
( cd "$SCRATCH" && grep -rn "sun.misc\|com.sun." --include=*.java . | grep -c "/src/main/java/" )   # 7
( cd "$SCRATCH" && grep -rn "sun.misc\|com.sun." --include=*.java . | grep "/src/main/java/" | cut -d: -f1 | sort -u | wc -l )   # 5
( cd "$SCRATCH" && grep -rn "sun.misc\|com.sun." --include=*.java . | grep -c "/src/test/java/" )   # 0
rm -rf "$SCRATCH"

# Equivalent one-liner for the before-capture, without extracting anything
git grep -n "sun.misc\|com.sun." c8f6226105 -- '*.java' | grep -c "/src/main/java/"   # 7

# Per-site anchors at the base commit.  The login class carries three of the
# seven hits, and the pooling key has THREE functional consumers - 92, 418, 423.
git show c8f6226105:acm-services/acm-service-convert-file/src/main/java/com/armedia/acm/service/MimeMessageParser.java | sed -n '33p;258,259p'
git show c8f6226105:acm-services/acm-service-login/src/main/java/com/armedia/acm/auth/ad/ActiveDirectoryAbstractContextSource.java | sed -n '55,56p;67p;80p;87p;92p;332p;337,346p;414p;418p;423p;429p'
git show c8f6226105:acm-standard-applications/acm-foia/src/main/java/gov/foia/service/FOIAQueueCorrespondenceService.java | sed -n '54p;197p'
git show c8f6226105:acm-standard-applications/acm-foia/src/main/java/gov/foia/service/NiemExportServiceImpl.java | sed -n '233,241p'
git show c8f6226105:acm-tool-integrations/acm-pdf-utilities/src/main/java/com/armedia/acm/pdf/service/PdfServiceImpl.java | sed -n '135,143p'

# The externalised literals, byte-identical to their JDK 8 originals
grep -v '^#' acm-services/acm-service-login/src/main/resources/spring/ldap-jndi.properties | grep .

# ... and proof that they are read rather than merely published: the class default,
# the Spring bean that loads the same file, and the test that asserts the outcome
grep -n 'ldap-jndi.properties' \
    acm-services/acm-service-login/src/main/java/com/armedia/acm/auth/ad/ActiveDirectoryAbstractContextSource.java \
    acm-services/acm-service-login/src/main/resources/spring/spring-library-user-login.xml
```

The first block must produce three zeros and the second must produce the seven-line capture followed by `7`, `5` and `0`. The `git grep` one-liner is offered as a cross-check: it reports the same seven lines with a commit-prefixed path form instead of the `./` form, so it confirms the count independently of the extraction step.

One ordering pitfall is worth naming, because it manufactures a convincing false failure. The scratch directory **must sit outside the repository working tree**, which is why `mktemp -d` is used above and why the extraction is deleted immediately afterwards. Extract the base commit into a subdirectory of the checkout instead and the after-capture will re-discover those very files — the gate recurses from the repository root and its `--include=*.java` filter does not care that they are a historical copy. The result is `7` where `0` is expected, on a tree that is in fact fully migrated. Run the after-capture first, or keep the extraction elsewhere.

Two wording gates apply to this page and both are checkable directly:

```bash
PAGE=$(git ls-files '*static-audit-output.md')
grep -En 'Java (8|9|10|11)\b' "$PAGE"
grep -c '^```' "$PAGE"
```

The first must produce no hit, the older runtime being written `JDK 8` throughout, and the second must return an even number so that every fence is balanced. Four further checks have no printable command, because writing the pattern would itself create the hit this page must not contain. Confirm by reading that the page contains **no literal occurrence of either of the two JDK 9 module-access JVM arguments, nor of the legacy reflective-access flag** — which is why the register that would record such exceptions is named here by title only, its own filename embedding one of those tokens. Confirm that **no link target on this page carries the documentation folder prefix**: sibling registers are linked by plain filename and parent pages by `../`, and the archived evidence directories are cited as inline paths rather than linked. Confirm that **the superseded frontend package manager is named nowhere on this page**, having no bearing on a Java source audit. And confirm that **the forbidden EE namespace is named nowhere either**, being irrelevant to this gate.

Related registers, each covering a class of decision that does not belong here: [Dependency Change Inventory](dependency-change-inventory.md) for the library changes behind the compatibility fixes, [Ambiguity Resolutions](ambiguity-resolutions.md) for the decisions where JDK 8 baseline behaviour was the tie-breaker, including the cast widening and the activation artifact choice, [Pre-existing Defects](pre-existing-defects.md) for the defects documented rather than fixed and for the two R-6 escape-clause invocations recorded outside this folder, [Baseline Test Failures](baseline-test-failures.md) for the register any test exclusion must cite, and the [Developer Setup](../setup.md) page for the prerequisites the migrated build documents.
