# Static Audit

This page records the JDK-internal-API static audit that the Java 17 migration has to satisfy: the exact command, the classified before state measured at the Java 8 base commit, and the zero-hit after state measured on the migrated tree. It is one of the four artifacts the migration's Deliver list names explicitly, and it is deliberately a classification rather than a list — the audit is a blunt text search, and sorting its hits into kinds is what makes a zero-hit requirement achievable at all.

## Where the rules come from

A note on provenance, because it is not discoverable from the repository. `review_rules` returns **no user rules provided**; there is no on-disk rules document for this project. The seven binding rules arrive instead through the user prompt's own RULES block, and their full verbatim text is available from the `review_prompt` tool. This page cites them by the stable identifiers **R-1** through **R-7** and deliberately does not reproduce their text — `review_prompt` is the source of record for that.

Three of the seven govern this page:

| Rule | Scope | What it requires of this page |
| --- | --- | --- |
| **R-3** | Build configuration | The audit turned up the evidence that *independently justifies* the no-release-8 rule rather than merely complying with it. Record it, and draw the inference. |
| **R-6** | All source | Nothing may be "fixed" beyond what clearing the audit gate strictly requires. The three prose hits are not defects, the rewordings change comments only, and no behaviour changes anywhere. |
| **R-7** | All behavioural decisions | The class-literal-to-name substitution has to be shown behaviour-identical against observed base-commit behaviour, not merely plausible — and the one consequence it does carry has to be stated. |

**R-7** owns a general register of its own, [the behavioral decisions record](behavioral-decisions.md). This page owns only the resolutions the audit itself forced.

## The command

The audit is run from the repository root, as an **extended-regex** search:

```bash
grep -rnE "sun\.misc|com\.sun\." --include=*.java
```

The required outcome is **zero hits over main source**. On the migrated tree the result is stronger than that: zero over `src/main/java` **and** zero over `src/test/java`. Scanning the whole working tree — 3,468 `.java` files, including the generated sources under `target/` — produces no output at all, and `grep` exits 1.

Two counts matter here, and they are the easiest things in this document to get wrong:

- **Only one of the seven hits was a compile blocker.** The other six compiled perfectly well on JDK 17 and were removed because the audit requires zero hits, not because anything was broken.
- **Only one of the seven named a JDK-internal type at all**, and it is that same hit. The two hits that named an API the code genuinely calls through are **third-party**, not JDK, so the code's real API dependencies and the migration's one compile blocker are entirely different hits. Keeping *third-party* and *JDK-internal* apart is the whole trick here, because it is exactly the distinction a text search erases — and reading the output as "seven JDK dependencies" gets both the size of the work and the size of the risk badly wrong.

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

**Test sources returned 0 hits, across all 402 test sources the base commit contains.** There was never anything to do there, before or after, and no test source is touched by this work.

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

**`MimeMessageParser.java:258`** — the cast widens to `java.io.InputStream`, which the file **already imports at line 50**, so the widening itself adds nothing: the value is handed straight to a byte-array reader on the very next line, and the removed type is a filter input stream, so reading it as an `InputStream` is exact.

That widening is not applied bare, and the reason is **R-7**. The base-commit cast rejected any part whose content was not a `BASE64DecoderStream` by throwing `ClassCastException`, and inline images are re-encoded to base64 before being embedded, so that rejection was load-bearing rather than incidental. A bare `(InputStream)` cast would have *silently accepted* quoted-printable, uuencoded and 7-bit parts that the base commit refused. The widening is therefore routed through a small private helper that first reads the part's declared content transfer encoding and raises the same `ClassCastException` unless it is base64. Observed base-commit behaviour is preserved exactly, which is what R-7 requires; the alternative would have been a quiet behavioural change hiding inside a "mechanical" cast fix.

One consequence of that choice is recorded in the change list below rather than glossed over: the guard needs `javax.mail.internet.MimePart` to read the declared encoding, so this edit adds an import where a bare widening would have added none.

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

The substitution replaces a compile-time `Class` literal with the same class's fully qualified **name**, held as data. Under **R-7** that has to be shown behaviour-identical against observed base-commit behaviour, not argued to be plausible. Four observations establish it, and one consequence is disclosed rather than buried.

- **Only the name was ever consumed.** The field's sole functional use anywhere in the codebase is `env.put(Context.INITIAL_CONTEXT_FACTORY, contextFactory.getName())`, at line 429 of the base-commit file. JNDI resolves providers by name, so supplying the name directly is exactly equivalent — and the provider string itself is unchanged, so the same provider is resolved as before.
- **Nothing outside the file depends on the field.** A repository-wide search finds no reference to `getContextFactory` or `setContextFactory` outside the class; the only subclass is `ActiveDirectoryContextSource` (`:31`); and no Spring XML sets the property.
- **The public API is preserved.** `getContextFactory()` (base `:332-335`) and `setContextFactory(Class)` (base `:343-345`) keep their signatures and their `Class` types. An injected factory is still contributed through `getName()` exactly as before; the configured default name is used only when none was injected.
- **The values are byte-identical to the base-commit literals.** `ldap.provider.contextFactory=com.sun.jndi.ldap.LdapCtxFactory` and `ldap.provider.connectionPoolFlag=com.sun.jndi.ldap.connect.pool`. Nothing is renamed, normalised or trimmed.

**One consequence, recorded honestly: `SUN_LDAP_POOLING_FLAG` stops being a compile-time constant.** It is now initialised from the loader rather than from a string literal, so it can no longer be inlined by the compiler or used where a constant expression is required — in a `case` label or an annotation argument, for instance. This was verified safe rather than assumed: the constant has exactly three uses, all inside the declaring class, none of them a constant-expression context. It remains `public static final`, so its binary signature is unchanged; only its inlining behaviour is.

### The three files that carry the change

| File | Role |
| --- | --- |
| `.../auth/ad/ldap-provider.properties` | Two keys — `ldap.provider.contextFactory` and `ldap.provider.connectionPoolFlag` — whose values are byte-identical to the base-commit literals. |
| `.../auth/ad/LdapProviderProperties.java` | A package-private loader that reads the resource via `getResourceAsStream`, once, during class initialization, and fails fast with `IllegalStateException` if it is absent, unreadable, missing a key, or carrying a blank or whitespace-padded value. |
| `.../auth/ad/ActiveDirectoryAbstractContextSource.java` | Consumes both values in place of the two removed literals. |

All three land together or none of them works: the loader resolves the resource **class-relatively**, so the properties file has to stay at `com/armedia/acm/auth/ad/` on the classpath, and the context source has to have the loader. There is deliberately no hardcoded fallback for either value, because a default written into Java source would put the encapsulated provider's name straight back into a `.java` file — undoing the only thing the externalization achieved.

### What the zero-hit result does not mean

The provider's name has not left the repository, and this page should not be read as claiming it has. Both strings still exist, in `ldap-provider.properties`, where the audit's `--include=*.java` filter does not look. That is not a loophole; it is the point of the second classification row. A JNDI provider name and a JNDI property name are **configuration values**, not API dependencies — the migration relocated them out of compiled source into configuration data, and only the compiled reference, the one thing JEP 396 actually forbids, is gone. One deliberate side benefit follows: the LDAP provider is now redirectable without recompiling.

The same caveat applies more widely, and it is worth stating once so nobody mistakes the metric for the property it stands in for. The text `com.sun.` survives in this repository in places the audit was never pointed at — most visibly as a Maven **groupId**, since the reinstated activation API is published as `com.sun.activation:javax.activation`. That coordinate is a third-party vendor namespace with no relationship to the JDK, and no amount of grepping `.java` files would ever have found it. A zero-hit audit is evidence that **compiled Java source names no JDK-internal or `sun.misc` type**. It is not, and was never, a claim that the two search strings have been eradicated from the tree.

## The note that matters for anyone repeating this

Clearing this gate required **four different kinds of edit**: removing one import and switching its call site, externalizing two configuration strings behind a loader, rewording three comments, and removing a second import together with its coupled cast.

Someone who fixes only the compile error and the one real API import will still see **five remaining hits** and may reasonably conclude the requirement is unachievable — three of them are comments that no compiler will ever complain about, and one is a configuration string that only looks like a type. It is achievable, and the route is the classification table above. Work the categories, not the line numbers.

## After: zero

The audit on the migrated tree returns **zero hits in `src/main/java` and zero in `src/test/java`**. All five files that carried a hit still exist and are unchanged in behaviour, and they demonstrably compile at the new contract: each of the five, plus the new loader class, is emitted at class-file **major version 61**, which is Java 17.

What did **not** change is as much of the result as what did:

- All **137** `javax.xml.bind` import lines, across **84** files in **21** Maven modules, are byte-identical to the base commit. So are the **4** `javax.annotation` imports and the **8** `javax.activation` import lines in **6** files.
- **The `jakarta` namespace is never introduced.** Zero `jakarta.*` import statements exist anywhere in the repository. The JDK-removed EE APIs come back instead as four `javax`-namespaced artifacts declared once in the root POM's global `<dependencies>` block and inherited by every module — and the three `jakarta`-coordinate artifacts the JAXB runtime would otherwise have dragged onto every classpath are explicitly excluded there, so the reinstated EE surface stays `javax`-only. See [the dependency change inventory](dependency-change-inventory.md).
- The audit was therefore cleared **without a single namespace rewrite**. Not one of those 149 import lines moved.

### The complete set of import edits

The audit's own footprint on import statements is **exactly four lines in two files**:

| File | Import | Change |
| --- | --- | --- |
| `FOIAQueueCorrespondenceService.java` | `com.sun.xml.fastinfoset.stax.events.Util` | removed |
| `FOIAQueueCorrespondenceService.java` | `org.apache.commons.lang3.StringUtils` | added |
| `MimeMessageParser.java` | `com.sun.mail.util.BASE64DecoderStream` | removed |
| `MimeMessageParser.java` | `javax.mail.internet.MimePart` | added |

The fourth row is a **documented deviation from the original plan**, which expected the second removal to add nothing at all. That expectation went with a bare cast widening; the implemented change keeps the widening to the already-imported `java.io.InputStream` but guards it, and the guard needs `MimePart` to read the part's declared encoding. The plan's import count was right about the mechanism it described and wrong about the mechanism that was actually needed to preserve base-commit behaviour. Behaviour won, and the extra import is the price — recorded here rather than left for a reader to discover in a diff.

Two further import edits exist elsewhere in the migration and are **unrelated to this audit**: `java.util.function.Predicate` in `DistributiveEventMulticaster.java`, forced by the Spring patch bump adding two methods to an interface that class implements, and several imports in the Track B deploy driver `AngularResourceCopier.java`. Neither touches a `sun.misc` or `com.sun.` reference, and neither is counted above.

## What this record does not cover

**The build configuration that R-3 governs.** This page supplies R-3's evidence, not its implementation. The enforcement is structural and lives in one place: exactly one of the repository's 145 POMs declares a compiler contract, as `maven.compiler.release=17`, and no POM anywhere declares `source`, `target`, `compilerVersion`, `release` or a `java.version` property — so there is no module-local override to police and no release-8 escape hatch to close.

**Module-access directives.** None are needed for anything on this page, and none reach production. The migration's eight directives are all confined to the forked test JVMs of the surefire and failsafe configurations; each is attributed to a demanding library and a stack frame in [the add-opens exceptions record](add-opens-exceptions.md).

**Tests.** No test source carried a hit and none is edited. For the four pre-existing unit-test failures, the two exclusions that cover them and the measured suite totals, see [the baseline test failures record](baseline-test-failures.md).

**Defects found and deliberately not fixed.** Under **R-6**, this page changed nothing beyond what the audit gate strictly required. The pre-existing defects the migration found along the way are enumerated in [the known issues register](known-issues.md).
