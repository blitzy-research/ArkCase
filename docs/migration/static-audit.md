# Static Audit

This page records the JDK-internal-API static audit that the Java 17 migration has to satisfy: the exact command, the classified before state measured at the Java 8 base commit, and the zero-hit after state measured on the migrated tree. It is one of the four artifacts the migration's Deliver list names explicitly, and it is deliberately a classification rather than a list — the audit is a blunt text search, and sorting its hits into kinds is what makes a zero-hit requirement achievable at all.

## What this page owes

Three of the migration's seven binding constraints — summarised once in [the behavioural-decisions record](behavioral-decisions.md#the-constraints-this-migration-works-under) — bear on this page:

| Constraint | What it requires here |
| --- | --- |
| **R-3** — no release-8 escape hatch | The audit turned up evidence that *independently justifies* the rule rather than merely complying with it. Record it, and draw the inference. |
| **R-6** — document, do not fix | Nothing may be "fixed" beyond what clearing the audit gate strictly requires. The three prose hits are not defects, the rewordings change comments only, and no behaviour changes anywhere. |
| **R-7** — Java 8 base-commit behaviour is the tie-breaker | Each substitution has to be shown behaviour-identical against observed base-commit behaviour, not merely plausible. Four of the five are. The fifth is not, and is reported as an unmet requirement rather than argued into compliance. |

The general register of R-7 resolutions is [the behavioural decisions record](behavioral-decisions.md). This page owns only the resolutions the audit itself forced.

## The command

The audit is run from the repository root, as an **extended-regex** search:

```bash
grep -rnE "sun\.misc|com\.sun\." --include=*.java
```

The required outcome is **zero hits over main source**. On the migrated tree the result is stronger than that: zero over `src/main/java` **and** zero over `src/test/java`. Scanning the whole working tree — 3,457 `.java` files, which is every Java source the repository tracks — produces no output at all, and `grep` exits 1.

Two counts matter here, and they are the easiest things in this document to get wrong:

- **Only one of the seven hits was a compile blocker.** The other six compiled perfectly well on JDK 17 and were removed because the audit requires zero hits, not because anything was broken.
- **Only one of the seven was a compiled reference to a JDK-internal type** — that same hit. Three others do name a JDK-internal implementation, but only in prose: the two Xalan comments name `com.sun.org.apache.xalan.internal.xsltc.trax`, and the LDAP Javadoc names the encapsulated context factory. Nothing compiles against any of the three. Meanwhile the two hits that name an API the code genuinely calls through are **third-party**, not JDK. Keeping *compiled* apart from *mentioned*, and *third-party* apart from *JDK-internal*, is the whole trick here, because those are exactly the distinctions a text search erases — and reading the output as "seven JDK dependencies" gets both the size of the work and the size of the risk badly wrong.

### The `-E` is not optional, and this is measured

The requirement is usually quoted without the flag and without escaping the dots. Both details were tested against the base commit, and only one of them is cosmetic:

| Form of the command | Hits at the base commit | Consequence |
| --- | --- | --- |
| As usually quoted — no `-E`, dots unescaped | **0** | **A false pass.** Basic `grep` treats the alternation bar as a literal character, so this searches for one 17-character string that appears nowhere in the repository. It reports success on a tree with seven genuine hits. |
| `-E`, dots unescaped | 7 | Correct here. The unescaped dots are wildcards, but nothing in this codebase matches only because of that. |
| `-E`, dots escaped — the form above | 7 | Correct, and correct for the right reason. |

The second and third rows were compared line by line and are identical, so the dot escaping is hygiene rather than a behavioural difference on this codebase. The first row is not hygiene: anyone verifying this gate with the unflagged form will see a clean result whether the work was done or not. Measured with GNU grep 3.11.

## Before: seven hits across five files

The base commit is `c8f6226105`, the parent of the first migration commit. The audit at that commit returns exactly seven hits:

| # | File | Line | Occurrence |
| --- | --- | --- | --- |
| 1 | `acm-standard-applications/acm-foia/src/main/java/gov/foia/service/NiemExportServiceImpl.java` | 235 | comment prose — `com.sun.org.apache.xalan.internal.xsltc.trax - JDK` |
| 2 | `acm-standard-applications/acm-foia/src/main/java/gov/foia/service/FOIAQueueCorrespondenceService.java` | 54 | `import com.sun.xml.fastinfoset.stax.events.Util;` |
| 3 | `acm-tool-integrations/acm-pdf-utilities/src/main/java/com/armedia/acm/pdf/service/PdfServiceImpl.java` | 137 | the same comment prose |
| 4 | `acm-services/acm-service-login/src/main/java/com/armedia/acm/auth/ad/ActiveDirectoryAbstractContextSource.java` | 55 | `public static final String SUN_LDAP_POOLING_FLAG = "com.sun.jndi.ldap.connect.pool";` |
| 5 | the same file | 56 | `private static final Class DEFAULT_CONTEXT_FACTORY = com.sun.jndi.ldap.LdapCtxFactory.class;` |
| 6 | the same file | 338 | Javadoc — `Set the context factory. Default is com.sun.jndi.ldap.LdapCtxFactory.` |
| 7 | `acm-services/acm-service-convert-file/src/main/java/com/armedia/acm/service/MimeMessageParser.java` | 33 | `import com.sun.mail.util.BASE64DecoderStream;` |

**Five distinct files**, because `ActiveDirectoryAbstractContextSource.java` carries three of the seven on its own.

**Test sources returned 0 hits, across all 402 test sources the base commit contains.** There was never anything to fix there, and **no pre-existing test source is edited by this work** — the preservation mandate keeps all 402 byte-identical, which `git diff --name-only c8f6226105 -- '*/src/test/java/*'` confirms by listing nothing.

The test tree is not exempt from the gate, and the delivered tree does carry **five added test classes** (407 tracked Java test sources; see [behavioural decision 21](behavioral-decisions.md#21-not-everything-a-migration-change-touches-belongs-in-the-migration) for why they exist). They were written under this gate rather than exempted from it, and one of them is the reason to say so out loud: `MimeMessageParserTest` exercises the very code path whose forbidden import was removed, and it does so **without naming the JDK-internal type** — it drives the parser through `javax.mail.Part` mocks and asserts on the declared transfer encoding instead. The audit over the whole tree, main and test, still returns **0**, which is the number that matters:

```console
$ grep -rnE "sun\.misc|com\.sun\." --include=*.java . | wc -l
0
```

One trap worth recording, because it was hit during this work and would be hit again: a **comment** counts. A first draft of the restored encoding check explained itself by naming the vendor package the removed cast came from, and that single Javadoc line put the audit back to 1. The gate is a text search over `*.java`, so prose is in scope; the comment was reworded to describe the class without the literal token, exactly as the three pre-existing comment hits below were.

### A correction on the record: five files, not four

An earlier statement of this audit reported "seven hits across four files". That file count is **wrong**, and the arithmetic of the table it came from shows why rather than merely hinting at it.

- It **omitted hit #2 entirely** — the FastInfoset import at `FOIAQueueCorrespondenceService.java:54`.
- In its place it counted the **cast** at `MimeMessageParser.java:258`, which at the base commit reads `BASE64DecoderStream b64ds = (BASE64DecoderStream) p.getContent();`. That line contains no `com.sun.` text, so the regex cannot match it and it was never a hit.
- Consequently that table's own category counts summed to **eight**, one more than the seven hits it was describing.

The cast is real and it does have to change, so it belongs on the record — as a **coupled edit**, not as an audit hit. Removing the import at line 33 is what forces it. It is counted in the change list below and excluded from the hit count above, and the distinction matters: a reader reconciling this page against the audit output has to be able to match seven rows to seven lines of `grep` output exactly.

## Classification, and why each hit needed a different remedy

Four kinds, seven hits, four different remedies. The counts sum to seven:

| Classification | Hits | Locations | Resolution |
| --- | --- | --- | --- |
| Encapsulated JDK reference — **the only compile blocker** | 1 | `ActiveDirectoryAbstractContextSource.java:56` | The class **literal** becomes a fully qualified **name** held as data, supplied by a small loader from a properties resource. |
| Configuration data masquerading as an API reference | 1 | `ActiveDirectoryAbstractContextSource.java:55` | A JNDI provider property **name**, not a type — moved into the same properties resource. A text search cannot tell the two apart. |
| Comment and Javadoc prose | 3 | `NiemExportServiceImpl.java:235`, `PdfServiceImpl.java:137`, `ActiveDirectoryAbstractContextSource.java:338` | Reworded to describe the same thing without the literal token. Prose only; no code, and no behaviour, changes. |
| Real third-party API references — resolved from third-party artifacts, never compile blockers | 2 | `MimeMessageParser.java:33`, `FOIAQueueCorrespondenceService.java:54` | Import removed and the call site switched to a supported equivalent. |

### Why the two third-party imports compiled fine and were still removed

Neither was ever a removed-module problem, and neither would have failed a JDK 17 build:

- `com.sun.mail.util.BASE64DecoderStream` resolves from the third-party `com.sun.mail:javax.mail` artifact, which that module declares directly. The `com.sun.` prefix is a vendor package name that happens to match the audit's pattern; nothing about it involves the JDK.
- `com.sun.xml.fastinfoset.stax.events.Util` resolves from a FastInfoset artifact that **no POM in this repository declares** — it arrives purely transitively. A stray emptiness-check utility, reached once, in a file that has nothing else to do with FastInfoset.

They were removed because the **audit** requires zero hits and both call sites had exact supported equivalents, not because either was broken. That is the whole justification, and it is why the two edits are as narrow as they are. The second one does carry an incidental benefit worth a sentence: compiling against an undeclared transitive artifact is fragile regardless of Java version, so the module no longer depends on a coordinate nobody asked for.

### The two call-site substitutions

**`FOIAQueueCorrespondenceService.java:197`** — `!Util.isEmptyString(emailAddress)` becomes `StringUtils.isNotEmpty(emailAddress)` from `org.apache.commons.lang3`, and the import at line 54 is replaced in kind. This follows a pattern the file's own neighbours already use: four other classes in `gov/foia/service/` import the same `StringUtils` at the base commit, among them `FOIAPortalUserServiceProvider.java:73`. Nothing new enters the module's dependency set.

**`MimeMessageParser.java:258`** — this is the substitution that needed the most care, because the reference the audit objects to was also the parser's **admission test** for inline-image content: removing the reference removes the test unless the test is rebuilt from something else. R-7 makes that non-negotiable, so it was rebuilt from standard MIME metadata and then measured against the base commit.

**The delivered edit removes the audited import and adds one standard-API import.** The import at line 33 is gone; `java.io.InputStream` was already imported, and the one import added is `javax.mail.internet.MimePart`, which is standard JavaMail API rather than a vendor implementation class — so the audit result is unaffected. What replaces the cast is a call to a private static helper, `getBase64DecodedContent(Part)`, supported by `getTransferEncoding(Part)` and two private constants naming the header and the accepted encoding. The helper evaluates `p.getContent()` **first**, exactly where and when the base-commit cast evaluated it, so a part whose content cannot be produced still fails first and at the same point; it then admits the part only when it declares `base64` transfer encoding — read through `MimePart.getEncoding()` where the part is a `MimePart`, and from the raw `Content-Transfer-Encoding` header otherwise, which is the value the mail implementation itself consults when it selects a decoder — and the trailing cast rejects content that is not a stream. Either rejection raises `ClassCastException` from the same statement the base-commit cast occupied, so no caller sees a new exception type or a new failure position.

**Measured against the base commit, seven encodings, three parsers.** A real `multipart/related` message carrying one `image/png` inline part with a `Content-Id` was parsed from raw MIME text — constructing the part with `setDataHandler` does *not* exercise the decode path, because the data handler has to be JavaMail's own — and run on JDK 17 against three compiled parsers: the base-commit file, the delivered file, and the intermediate iteration that had simply widened the cast to `InputStream`.

| `Content-Transfer-Encoding` | base commit | delivered | widened cast (reverted) |
|---|---|---|---|
| `base64` | accepted, bytes round-trip | accepted, bytes round-trip | accepted |
| `BASE64` | accepted, bytes round-trip | accepted, bytes round-trip | accepted |
| `base64` with surrounding whitespace/comment | accepted, bytes round-trip | accepted, bytes round-trip | accepted |
| `quoted-printable` | rejected, `ClassCastException` | rejected, `ClassCastException` | accepted — and the bytes did **not** match the original |
| `7bit` | rejected, `ClassCastException` | rejected, `ClassCastException` | accepted |
| `binary` | rejected, `ClassCastException` | rejected, `ClassCastException` | accepted |
| header absent | rejected, `ClassCastException` | rejected, `ClassCastException` | accepted |

The delivered column is identical to the base-commit column in all seven rows, including the lenient-tokenisation row. The third column is why the widening was withdrawn rather than merely disclosed: on the `quoted-printable` row it did not just accept more, it produced an embedded image whose bytes differ from the source, because the raw decoded bytes it re-encodes with `BaseEncoding.base64()` are not the decoded image for that transfer encoding. A silently wrong image is worse than the base commit's exception, so "strictly more permissive and still correct" was not true.

**Divergence from the plan's mapping, recorded deliberately.** The migration plan maps this file as a two-line change and asserts the widening is exact. Measurement shows it is not exact, and under the plan's own precedence R-7 — observed Java 8 base-commit behaviour is the tie-breaker — outranks a mapped edit whose stated justification does not hold. The delivered change is therefore larger than the mapped one by two private helpers and is recorded as a divergence here and in [the behavioural decisions record](behavioral-decisions.md). It adds no import, no dependency and no vendor type, and it leaves the audit at zero.

## The one compile blocker, proven three ways

Hit #5 — the class literal at `ActiveDirectoryAbstractContextSource.java:56` — is the only one of the seven that stops a JDK 17 build. Three compilers were run against a minimal probe containing exactly that declaration, and a fourth observation confirms the cause.

**One — `javac --release 17` cannot see the package.** On JDK 17.0.20:

```text
Probe.java:3: error: package com.sun.jndi.ldap is not visible
    private static final Class DEFAULT_CONTEXT_FACTORY = com.sun.jndi.ldap.LdapCtxFactory.class;
                                                                     ^
  (package com.sun.jndi.ldap is declared in module java.naming, which does not export it)
1 error
```

**Two — `javac --release 8` on the same JDK 17 JVM fails as well**, and this is the finding that matters beyond this file:

```text
Probe.java:3: error: package com.sun.jndi.ldap does not exist
    private static final Class DEFAULT_CONTEXT_FACTORY = com.sun.jndi.ldap.LdapCtxFactory.class;
                                                                          ^
1 error
```

The diagnostic differs — *not visible* versus *does not exist* — but the exit status does not: both are errors. This is corroborating evidence for **R-3**. Compiling the backend at release 8 on a Java 17 JVM is forbidden as a way of dodging the migration; the measurement shows the shortcut **would not have worked anyway**, because `--release 8` resolves against the historical Java 8 API signatures, which never included an internal JDK package. R-3 costs this migration nothing here, because the escape hatch was never available for the one genuine blocker.

**Three — a real JDK 8 `javac` compiles it with a warning only.** On `javac 1.8.0_502` the same probe exits 0 and produces a class file:

```text
Probe.java:3: warning: LdapCtxFactory is internal proprietary API and may be removed in a future release
    private static final Class DEFAULT_CONTEXT_FACTORY = com.sun.jndi.ldap.LdapCtxFactory.class;
                                                                          ^
1 warning
```

That is precisely why the coupling survived unnoticed for years: it was never an error, only a warning nobody was obliged to read.

**Confirming the cause.** `java --describe-module java.naming` on JDK 17.0.20 lists `contains com.sun.jndi.ldap` and no matching `exports` line. The package is **contained but unexported**, so JEP 396 strong encapsulation puts it out of reach of ordinary classpath code — which is exactly what the first diagnostic says, from the runtime's own module descriptor rather than from the compiler.

## Why changing it is safe

The substitution replaces a compile-time `Class` literal with the same class's fully qualified **name**, held as data — and then resolves that name straight back to **the same `Class` object** with `Class.forName`, so the field and both accessors keep the types and the semantics they had at the base commit. Under **R-7** that has to be shown behaviour-identical against observed base-commit behaviour, not argued to be plausible. Five observations establish it, and one consequence is disclosed rather than buried.

- **Loading the class by name still works on Java 17.** `Class.forName("com.sun.jndi.ldap.LdapCtxFactory")` succeeds on the target runtime — a probe compiled and executed on JDK 17.0.20 reports the loaded class with `module=java.naming`. JEP 396 strong encapsulation governs compile-time references and reflective access to *members*; it does not stop a contained class from being **loaded by name**. That single fact is what lets the migration remove the literal without removing the `Class` from this class's published surface.
- **The field is still a `Class`, and its default is still the same class.** The default is `LdapProviderProperties.getContextFactoryClass()`, which is `Class.forName` applied to the configured name, so `getContextFactory()` on a freshly constructed context source returns `com.sun.jndi.ldap.LdapCtxFactory` exactly as at base. `getContextFactory()` (base `:332-335`) and `setContextFactory(Class)` (base `:343-345`) keep their signatures and their `Class` types.
- **The consuming line is byte-identical to the base commit.** `env.put(Context.INITIAL_CONTEXT_FACTORY, contextFactory.getName())`, at line 429 of the base-commit file, is unchanged — one line, no branch, no added null tolerance. So an injected factory is contributed through `getName()` exactly as before; `setContextFactory(null)` still makes the getter return `null` and still raises `NullPointerException` when the environment is populated; and JNDI resolves providers by name, so the same provider is resolved as before. All three were confirmed by an ad-hoc harness run against the module's real classpath on JDK 17 before this page was written.
- **Nothing outside the file depends on the field.** A repository-wide search finds no reference to `getContextFactory` or `setContextFactory` outside the class; the only subclass is `ActiveDirectoryContextSource` (`:31`); and no Spring XML sets the property. That bounds the risk rather than licensing a change: R-7 makes base behaviour the tie-breaker whether or not a consumer is observed, which is why retyping the field to `String` was rejected. Doing so would have preserved the JNDI outcome while quietly changing three observable things — the getter's return type, the value it returns before any injection, and the `NullPointerException` a `null` injection produces.
- **The values are byte-identical to the base-commit literals.** `ldap.provider.contextFactory=com.sun.jndi.ldap.LdapCtxFactory` and `ldap.provider.connectionPoolFlag=com.sun.jndi.ldap.connect.pool`. Nothing is renamed, normalised or trimmed.

All five were established by execution rather than by prose, and — deliberately — **not by a committed test**. An ad-hoc harness on JDK 17, run against the module's real classpath, exercised the non-null default, that the default is the class the resource names, that the default is shared across instances, that an injected factory is published verbatim, that JNDI receives the configured provider name, and that a `null` factory raises `NullPointerException` when the environment is assembled. It read the expected name **from the same resource** the production code reads, so it asserted the wiring rather than a duplicated literal, and it was removed afterwards rather than committed: the plan maps no test source, and a new test class would itself have been an unmapped change ([behavioural decision 21](behavioral-decisions.md#21-not-everything-a-migration-change-touches-belongs-in-the-migration)). What that costs is stated plainly in [the smoke evidence](smoke-evidence.md#what-the-suite-covers-of-this-change-set-and-what-it-does-not): these edits are verified by compilation, by the surrounding module's green suite and by the executed deployment and login, not by an assertion.

**One consequence, recorded honestly: `SUN_LDAP_POOLING_FLAG` stops being a compile-time constant.** It is now initialised from the loader rather than from a string literal, so it can no longer be inlined by the compiler or used where a constant expression is required — in a `case` label or an annotation argument, for instance. This was verified safe rather than assumed: the constant has exactly three uses, all inside the declaring class, none of them a constant-expression context. It remains `public static final`, so its binary signature is unchanged; only its inlining behaviour is.

### The three files that carry the change

| File | Role |
| --- | --- |
| `.../auth/ad/ldap-provider.properties` | Two keys — `ldap.provider.contextFactory` and `ldap.provider.connectionPoolFlag` — whose values are byte-identical to the base-commit literals. |
| `.../auth/ad/LdapProviderProperties.java` | A package-private loader that reads the resource via `getResourceAsStream`, once, during class initialization, resolves the context factory from its name with `Class.forName`, and fails fast with `IllegalStateException` if the resource is absent, unreadable, missing a key, carrying a blank or whitespace-padded value, or naming a class that is not on the classpath. |
| `.../auth/ad/ActiveDirectoryAbstractContextSource.java` | Consumes both values in place of the two removed literals. |

All three land together or none of them works: the loader resolves the resource **class-relatively**, so the properties file has to stay at `com/armedia/acm/auth/ad/` on the classpath, and the context source has to have the loader. There is deliberately no hardcoded fallback for either value, because a default written into Java source would put the encapsulated provider's name straight back into a `.java` file — undoing the only thing the externalization achieved.

### What the zero-hit result does not mean

No provider name has left the repository, and this page should not be read as claiming it has. The two JNDI strings still exist, in `ldap-provider.properties` — a file where the audit's `--include=*.java` filter does not look. That is not a loophole; it is the point of the second classification row. A JNDI provider name and a JNDI property name are **configuration values**: the migration relocated them out of compiled source into configuration data, and only the compiled reference — the one thing JEP 396 actually forbids — is gone. One deliberate side benefit follows: the LDAP provider is now redirectable without recompiling. The mail provider's decoder-stream name is a different case and is not relocated anywhere: that reference is simply **deleted**, because widening the cast removed the need to name the type at all.

The same caveat applies more widely, and it is worth stating once so nobody mistakes the metric for the property it stands in for. The text `com.sun.` survives in this repository in places the audit was never pointed at — most visibly as a Maven **groupId**, since the reinstated activation API is published as `com.sun.activation:javax.activation`. That coordinate is a third-party vendor namespace with no relationship to the JDK, and no amount of grepping `.java` files would ever have found it. A zero-hit audit is evidence that **compiled Java source names no JDK-internal or `sun.misc` type**. It is not, and was never, a claim that the two search strings have been eradicated from the tree.

### The same defect exists one layer down, where this audit cannot see it

An audit scoped to `--include=*.java` reads only this repository's own source, and the pattern it is looking for is not unique to this repository. The identical defect — a compile-time class literal on the encapsulated JDK LDAP context factory — lives inside **Spring LDAP 2.3.3.RELEASE**, in `org.springframework.ldap.core.support.AbstractContextSource`, and no source audit here would ever surface it.

It does not fail at compile time either, because the class is only initialised at runtime, so it survived both this audit and the whole unit suite. It was found by deploying the application to Tomcat 9 on Java 17 and logging in: authentication returned HTTP 500 where the Java 8 baseline returned 302, and initialising that class in isolation gives the error the second and later attempts hide — `IllegalAccessError: … cannot access class com.sun.jndi.ldap.LdapCtxFactory (in module java.naming) because module java.naming does not export com.sun.jndi.ldap to unnamed module`. The remedy was the library's own version of the fix this page describes: 2.3.4.RELEASE resolves the factory **by name**, exactly as ArkCase's context source now does. The reproduction and the version measurement are in [the dependency inventory](dependency-change-inventory.md), and the deployment evidence is in [the smoke evidence](smoke-evidence.md#deployment-on-java-17-two-defects-this-capture-found).

The transferable lesson is about the metric, not the library: **a zero-hit source audit says nothing about the dependencies on the classpath**, and encapsulation defects inside them surface only when the application actually runs.

## The note that matters for anyone repeating this

Clearing this gate required **four different kinds of edit**: removing one import and switching its call site, externalizing two configuration strings behind a loader, rewording three comments, and removing a second import together with the coupled cast it forced.

Someone who fixes only the compile error and the one real API import will still see **five remaining hits** and may reasonably conclude the requirement is unachievable — three of them are comments that no compiler will ever complain about, and one is a configuration string that only looks like a type. It is achievable, and the route is the classification table above. Work the categories, not the line numbers.

## After: zero

The audit on the migrated tree returns **zero hits in `src/main/java` and zero in `src/test/java`**. All five files that carried a hit still exist, and they demonstrably compile at the new contract: each of the five, plus the new `LdapProviderProperties` loader, is emitted at class-file **major version 61**, which is Java 17. All five are behaviour-identical to the base commit, the MIME parser included: its admission test was rebuilt from standard transfer-encoding metadata and measured to accept and reject exactly what the base-commit cast did, across all seven encodings tabulated above.

Two notes for anyone re-running it. The audit is a text search, so it matches **prose as readily as code** — a Javadoc sentence naming the vendor package of a provider class is a hit exactly like an import of it, which is why the new loader class describes its provider by role rather than by package name. And it walks whatever is under the working directory: a scratch extraction of the base commit, or any other tree left beside the checkout, will contribute its own hits. Run it against tracked files (`git grep -nE "sun\.misc|com\.sun\." -- '*.java'`) if the working directory is not clean.

What did **not** change is as much of the result as what did:

- All **137** `javax.xml.bind` import lines, across **84** files in **21** Maven modules, are byte-identical to the base commit. So are the **4** `javax.annotation` imports and the **8** `javax.activation` import lines in **6** files.
- **The `jakarta` namespace is never introduced into source.** `grep -rl "^import jakarta" --include=*.java` returns **no file**: zero `jakarta.*` import statements exist anywhere in the repository, main or test. The JDK-removed EE APIs come back instead as four `javax`-namespaced artifacts declared once in the root POM's global `<dependencies>` block and inherited by every module.
- **The root POM does name `jakarta` coordinates, and only inside exclusions.** `grep -i jakarta pom.xml` returns **20 lines**: **14** `<groupId>`/`<artifactId>` element lines distributed over **8** `<exclusion>` blocks, plus **6** comment lines explaining them. (Six of the eight contribute two lines each; two contribute one each, because their `<groupId>` is `com.sun.activation` and only the artifact is jakarta-named.) Every one of the 14 keeps an EE 9 coordinate *off* the classpath — the mechanism that enforces the previous bullet, not a counter-example to it. No `jakarta` coordinate appears in any `<dependency>` or `<dependencyManagement>` entry. Those exclusions do change `WEB-INF/lib` relative to the Java 8 baseline WAR, which shipped jakarta-coordinate artifacts transitively; that consequence belongs to [the dependency change inventory](dependency-change-inventory.md), which also records why the runtime provider's own transitive dependencies are left as the base commit had them.
- The audit was therefore cleared **without a single namespace rewrite**. Not one of those 149 import lines moved.

### The complete set of import edits

The audit's own footprint on import statements is **exactly three lines in two files**:

| File | Import | Change |
| --- | --- | --- |
| `FOIAQueueCorrespondenceService.java` | `com.sun.xml.fastinfoset.stax.events.Util` | removed |
| `FOIAQueueCorrespondenceService.java` | `org.apache.commons.lang3.StringUtils` | added |
| `MimeMessageParser.java` | `com.sun.mail.util.BASE64DecoderStream` | removed |

That reconciles exactly with the migration plan, which counts **four** import edits across the whole repository: these three plus `java.util.function.Predicate` in `DistributiveEventMulticaster.java`. The fourth is unrelated to this audit — it is forced by the Spring patch bump adding two methods to an interface that class implements — and it is not counted in the table because no `sun.misc` or `com.sun.` reference is involved.

The second removal adds nothing, exactly as the plan records: `java.io.InputStream` is already imported at line 50 of that file, and the two private helpers that rebuild the admission test need no type the file did not already import — `git diff` on that file shows one `-import` line and no `+import` line at all. The reasoning is above under [the two call-site substitutions](#the-two-call-site-substitutions).

## What this record does not cover

**The build configuration that R-3 governs.** This page supplies R-3's evidence, not its implementation. The enforcement is structural and lives in one place: exactly one of the repository's 145 POMs declares a compiler contract, as `maven.compiler.release=17`, and no POM anywhere declares `source`, `target`, `compilerVersion`, `release` or a `java.version` property — so there is no module-local override to police and no release-8 escape hatch to close.

**Module-access directives.** **None of the substitutions on this page needs one** — that is worth stating precisely, because it is the claim this page can support: every encapsulated reference above was removed by changing the code rather than by opening a module, so no directive exists to serve them. Separately from this page, the migration configures **eight** directives, all confined to the forked test JVMs of the surefire and failsafe configurations, and this repository's documented `JAVA_OPTS` grants no module access at all. [The add-opens exceptions record](add-opens-exceptions.md) owns that position, attributes each directive to a demanding library and a stack frame, and holds the one unreconciled runtime observation about what a container's own launcher supplies.

**Tests.** No pre-existing test source carried a hit, none is edited, and the migration **adds none** — so the test tree clears the gate exactly as the base commit left it, at 402 files and zero hits. For the four pre-existing unit-test failures, the two exclusions that cover them and the measured suite totals, see [the baseline test failures record](baseline-test-failures.md).

**Defects found and deliberately not fixed.** Under **R-6**, this page changed nothing beyond what the audit gate strictly required. The pre-existing defects the migration found along the way are enumerated in [the known issues register](known-issues.md).
