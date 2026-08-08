# Backend Dependency Security

## Why this page exists

Code review raised four security findings against backend dependencies this migration touches: an advisory against the Spring Security version it targets, a second advisory against the same artifact reached through X.509 client-certificate authentication, an advisory against the Spring LDAP version it advances to, and a set of ten advisories against the Jackson line it pins. None of the four is disputed. Review then raised a fifth point that this page had answered only partially: it discussed **13 of the 40 advisories in the committed corpus** and left the remaining 27 undisclosed. That gap is closed here. Every advisory in the corpus now appears on this page, and the complete table is **generated from the corpus rather than transcribed into it**.

It is the backend counterpart of [Frontend Dependency Security](frontend-dependency-security.md) and follows the same posture: the exposure is measured, the inherited part is separated from the introduced part, and no advisory is closed by assertion.

**Every fixed-version figure below was read out of the advisory corpus committed in this repository**, at `smoke-evidence/advisory-corpus/2026-08-07-maven-osv-advisories.json`, whose own SHA-256 manifest and verification script sit beside it. Nothing here is quoted from a vendor page or recalled from a bulletin. The corpus was captured on August 7, 2026.

**Completing the disclosure changed the conclusion, which is the reason it was worth completing.** Widening from 13 advisories to 40 surfaced one position that the shortened page could not have shown: a single Low-severity advisory that this migration's own version advance **moved the deployed artifact into**, where the base commit sat outside it. Thirty-nine positions are inherited; one is not. It is [Finding 5](#finding-5-the-one-advisory-position-this-migration-entered) and it is stated before the four inherited findings in the summary table below, because a regression the change set caused is a different kind of fact from an exposure it received.

## What the complete corpus says

The corpus holds 40 advisories across 14 distinct Maven coordinate names, and **all 40 name a coordinate that is present in the built WAR's `WEB-INF/lib`** — none is a build-only or test-only artifact that never ships. The severity spread and, more importantly, the effect of this migration on each position:

| Measure | Count |
| --- | ---: |
| Advisories in the committed corpus | 40 |
| Whose coordinate is present in the deployed WAR | 40 |
| Critical / High / Moderate / Low | 2 / 14 / 18 / 6 |
| Position **carried unchanged** across the migration | 39 |
| Position **cleared** by the migration | 0 |
| Position **entered** by the migration | **1** |
| Ranges this comparison could not order | 0 |

Read the last three rows together. The migration cleared nothing, which is consistent with every version advance in it having been made for a Java 17 compatibility reason and not for a security one — R-1 permits no other motive. It entered one, which is disclosed as a finding rather than folded into the carried count. And it left no range undetermined, so the 39/0/1 split accounts for all 40 with nothing set aside as unknown.

Grouped by the artifact that actually ships, which is the form an owner triaging this needs:

| Artifact in `WEB-INF/lib` | Delivered version | Advisories | Severities |
| --- | --- | ---: | --- |
| `spring-webmvc` | `5.3.39` | 15 | High 4, Moderate 9, Low 2 |
| `jackson-databind` | `2.12.7` | 7 | High 4, Moderate 3 |
| `spring-expression` | `5.3.39` | 4 | High 2, Moderate 1, Low 1 |
| `jackson-core` | `2.12.7` | 3 | High 2, Moderate 1 |
| `spring-security-web` | `5.8.16` | 2 | Critical 1, Moderate 1 |
| `spring-core` | `5.3.39` | 2 | High 1, Low 1 |
| `spring-websocket` | `5.3.39` | 2 | Moderate 2 |
| `spring-web` | `5.3.39` | 2 | Critical 1, Moderate 1 |
| `spring-ldap-core` | `2.4.4` | 1 | High 1 |
| `spring-security-core` | `5.8.16` | 1 | Low 1 — **the entered position** |
| `spring-context` | `5.3.39` | 1 | Low 1 |

Two Spring artifacts appear in more than one row above because an advisory can name several coordinates; the per-artifact counts therefore sum to more than 40 while the advisory count is exactly 40. The generated triage carries the exact coordinate list for every row.

Grouped instead by the version property that governs each artifact, which is the form a remediation decision is actually taken in:

| Pinned property | Delivered | Advisories | Severities | Covered by |
| --- | --- | ---: | --- | --- |
| `spring.version` | `5.3.39` | 26 | Critical 1, High 7, Moderate 13, Low 5 | the enumeration below |
| `fasterxml-jackson-core.version` | `2.12.7` | 10 | High 6, Moderate 4 | Finding 4 |
| `spring.security.version` | `5.8.16` | 3 | Critical 1, Moderate 1, Low 1 | Findings 1, 2 and 5 |
| `spring.ldap.version` | `2.4.4` | 1 | High 1 | Finding 3 |

Those four properties account for all 40 advisories exactly. Fourteen of them were the subject of the findings review raised; **the 26 against Spring Framework itself are the block the shortened page omitted**, and one of them is Critical.

**That Critical is named here rather than left in a table row.** `GHSA-4wrc-f8pq-fpqp` — *Pivotal Spring Framework contains unsafe Java deserialization methods*, CWE-502 — names `org.springframework:spring-web`, which ships in the WAR. Its position is **carried unchanged**: the baseline `5.3.2` and the delivered `5.3.39` are both inside the affected range, so the migration neither introduced nor cleared it. The only fixed release the corpus publishes is **`6.0.0`** — Spring Framework 6, the jakarta namespace, barred absolutely. It is therefore in the same category as Findings 1 through 4: an inherited exposure with no in-scope remedy. It is called out by name because a Critical-severity CWE-502 row deserves to be read, and because the previous revision of this page did not mention it at all.

The complete enumeration is below in [Every advisory in the corpus](#every-advisory-in-the-corpus). The four findings that follow are the ones where the analysis is load-bearing — where a call site is present in this codebase, or a remedy exists and is barred for a specific reason — and they are kept in prose because a table cannot carry that reasoning.

## The conclusion that governs the four inherited findings

Narrowing to the four findings review raised: three of them have **no fix published for the release line this migration is confined to**, and the fourth has fixes that would breach the rule under which the artifact was changed at all. That is not a convenient reading of the data; it is what the ranges say, and the ranges are reproduced below in full.

The confinement is not a preference either. The migration plan's exclusion list forbids the jakarta namespace and Spring 6 **absolutely**, at the artifact level rather than only at the import level, and R-1 forbids any dependency change that lacks a specific Java 17 or Node 20 compatibility reason. Every published fix for the three Spring advisories lies in a Spring 6 or Spring 7 line. So the remedy for each is a change this migration is not permitted to make, and making it anyway would replace four disclosed advisories with an undisclosed violation of the two constraints the whole change set is built on.

What this page therefore delivers is a **disclosure with an owner decision attached**, not a remediation.

## Finding 1 — Spring Security HTTP headers not written under some conditions

`GHSA-mf92-479x-3373`, against `org.springframework.security:spring-security-web`, the artifact family this migration advances from `5.4.2` to `5.8.16`.

| Introduced at | Fixed at |
| --- | --- |
| `0` | **none published** |
| `5.8.0` | **none published** |
| `6.0.0` | **none published** |
| `6.4.0` | **none published** |
| `6.5.0` | `6.5.9` |
| `7.0.0` | `7.0.4` |

Six ranges, and the two that carry a fix are both Spring Security 6.5 and 7.0 — jakarta-namespace lines that pair with Spring Framework 6 and 7. The `5.8.0` range that contains the delivered version has **no fixed version at all**, so there is no 5.8.x release to move to. The 5.8 line is out of open-source maintenance, which is why.

**What the migration could do: nothing, and the alternatives are worse than the disclosure.** Moving to `6.5.9` means Spring Security 6, which requires Spring Framework 6, which requires the jakarta namespace across the entire reactor — the change the plan's exclusion list forbids absolutely and which the 1,612 `javax.persistence` occurrences and 234 `javax.servlet.http` occurrences in main source would each have to follow. Staying on `5.4.2` is not an alternative either: it is not the artifact's problem, it is inside the same unfixed range, and it re-breaks the Spring Framework 5.3.39 pairing that the Java 17 auto-proxying fix requires.

**Was the exposure introduced by this migration?** No. `5.4.2` and `5.8.16` are both inside the `5.8.0`-and-below unfixed ranges — the `0` range covers every 5.x release — so the base commit carries the identical exposure. The advance changed the version and did not change the advisory position.

## Finding 2 — Spring Security user impersonation via X.509 client certificates

`GHSA-293q-567p-wmwq`, against the same artifact.

| Introduced at | Fixed at |
| --- | --- |
| `0` | **none published** |
| `5.8.0` | **none published** |
| `6.0.0` | **none published** |
| `6.4.0` | **none published** |
| `6.5.0` | `6.5.11` |

The same shape: one fixed version, in the jakarta line. The `5.8.0` range has none.

**The X.509 surface is real in this codebase and is named rather than glossed.** `AcmBasicAndTokenAuthenticationFilter.java:219` constructs a `SubjectDnX509PrincipalExtractor`, so the code path the advisory concerns is present. Two facts bound what that means here. The **whole file is byte-identical to the base commit** — SHA-256 `b6801a9049f4f2c66a3deb81…` on both sides — so this migration did not add, move or alter the call site or anything around it. And the API the fix relies on, `SubjectX500PrincipalExtractor`, **does not exist in Spring Security 5.8.x**; it is introduced in the 6.5 line, so the remediation is unavailable in the delivered line for the same reason the version bump is.

**Was the exposure introduced?** No, on both axes: the version stays inside an unfixed range that also covers the base commit's version, and the call site is unchanged.

## Finding 3 — Spring LDAP authentication bypass with empty password

`GHSA-jrv5-8w28-4265`, against `org.springframework.ldap:spring-ldap-core`, which this migration advances from `2.3.3.RELEASE` to `2.4.4`.

| Introduced at | Fixed at |
| --- | --- |
| `0` | **none published** |
| `3.2.0` | **none published** |
| `3.3.0` | `3.3.8` |
| `4.0.0` | `4.0.4` |

Both fixed lines are 3.3 and 4.0 — jakarta-namespace releases. The `0` range, which is the one containing every 2.x release including both `2.3.3.RELEASE` and `2.4.4`, has **no fixed version**.

**Why the artifact was advanced at all, since it does not clear the advisory.** The advance is a hard Java 17 compatibility fix and is recorded as such in the dependency inventory and at entry 20 of [Ambiguity Resolutions](ambiguity-resolutions.md): `2.3.3.RELEASE` holds `com.sun.jndi.ldap.LdapCtxFactory` as a **class literal in its own static initialiser**, loaded by `ldc` inside `<clinit>`, so constructing any `AbstractContextSource` subclass on Java 17 raises `IllegalAccessError` — `java.naming` does not export that package to the unnamed module. Nothing on ArkCase's side can avoid triggering a library's own static initialiser. The floor is `2.3.4.RELEASE` by bisection and `2.4.4` is the last release of the javax-namespace line, which is the cap R-T1 imposes.

**Was the exposure introduced?** No. `2.3.3.RELEASE` is inside the same unfixed `0` range, so the base commit carries it identically. The bump moved the version within one unfixed range and did not enter a new one.

**The blank-credential guard, stated precisely.** Review also asked about a blank-credential guard. The delivered `ActiveDirectoryAbstractContextSource` validates its two injected JNDI values in `afterPropertiesSet` and throws on a blank value, so a context that omits either fails loudly at startup instead of silently authenticating against a default. That is a startup-configuration guard on the **context factory and pooling key**, and it is deliberately not described as a mitigation for this advisory: the advisory concerns an empty **user password** presented at bind time, which is a different value on a different code path, and claiming otherwise would be the "unchanged is not mitigated" error this deliverable refuses elsewhere.

## Finding 4 — The ten Jackson advisories

This migration pins `com.fasterxml.jackson.*` at `2.12.7`, advanced from `2.10.3`. Ten advisories in the corpus name a Jackson artifact.

| Advisory | Artifact | Summary | Fixed versions published |
| --- | --- | --- | --- |
| `GHSA-3wrr-7qpf-2prh` | `jackson-databind` | jackson-databind: Deeply nested JsonNode throws StackOverflowError for toString() | `2.14.0` |
| `GHSA-5jmj-h7xm-6q6v` | `jackson-databind` | jackson-databind has case-insensitive deserialization bypasses per-property @JsonIgnoreProperties | `2.18.9`, `2.21.5`, `2.22.1`, `3.1.4` |
| `GHSA-h46c-h94j-95f3` | `jackson-core` | jackson-core can throw a StackoverflowError when processing deeply nested data | `2.15.0` |
| `GHSA-hgj6-7826-r7m5` | `jackson-databind` | jackson-databind: InetSocketAddress deserialization triggers eager DNS resolution (SSRF) | `2.18.8`, `2.21.4`, `3.1.4` |
| `GHSA-j3rv-43j4-c7qm` | `jackson-databind` | jackson-databind has a PolymorphicTypeValidator bypass via generic type parameters that allows arbitrary class instant | `2.18.8`, `2.21.4`, `3.1.4` |
| `GHSA-jjjh-jjxp-wpff` | `jackson-databind` | Uncontrolled Resource Consumption in Jackson-databind | `2.12.7.1`, `2.13.4.2` |
| `GHSA-r7wm-3cxj-wff9` | `jackson-core` | jackson-core: Async parser maxNumberLength bypass via chunked digit accumulation (incomplete fix for GHSA-72hv-8253-57 | `2.18.8`, `2.21.4` |
| `GHSA-rgv9-q543-rqg4` | `jackson-databind` | Uncontrolled Resource Consumption in FasterXML jackson-databind | `2.12.7.1`, `2.13.4` |
| `GHSA-rmj7-2vxq-3g9f` | `jackson-databind` | jackson-databind has an array subtype allowlist bypass in BasicPolymorphicTypeValidator (allowIfSubTypeIsArray) | `2.18.8`, `2.21.4`, `3.1.4` |
| `GHSA-wf8f-6423-gfxg` | `jackson-core` | Jackson-core Vulnerable to Memory Disclosure via Source Snippet in JsonLocation | `2.13.0` |

**The decisive measurement, and it points the opposite way from what a reader might expect.** Every one of the ten ranges covers the baseline `2.10.3` **and** the delivered `2.12.7`:

| | Advisories covering it |
| --- | ---: |
| Baseline `2.10.3` | **10 of 10** |
| Delivered `2.12.7` | **10 of 10** |
| Cleared by the `2.10.3` → `2.12.7` advance | **0** |

So the advance neither improved nor worsened the advisory position. It was not made for security and this page does not claim it was: it was made because `2.10.3` **cannot build a bean deserializer for any type carrying a `java.time` property on Java 17** — `ClassUtil.checkAndFixAccess` calls `setAccessible` on `LocalDate`'s private fields and `java.base` does not open `java.time` to the unnamed module — and that failure is not test-only, since portal request submission reads types carrying `LocalDateTime` properties through a plain object mapper on an unchecked path.

**Why the advisories are not cleared as well — and one correction to how far the remedy actually is.** Eight of the ten need a substantial advance: `jackson-core` `2.21.4` and `jackson-databind` `3.1.4` at the top of their ranges, and `2.18.8` for the bulk of them. R-1 directs that a compatibility-blocking library be upgraded to its **minimum Java-17-capable version**, and that floor was established by execution at `2.12.7`. Advancing nine further minor releases, or across a major boundary to `3.1.4`, would be a change without a Java 17 compatibility reason for the distance travelled — which R-1's contrapositive forbids as firmly as it forbids an unjustified omission — and would move a serialization library that shapes REST response bodies the PRESERVE list freezes.

**Two of the ten are different, and an earlier revision of this page obscured that by grouping them with the rest.** `GHSA-jjjh-jjxp-wpff` and `GHSA-rgv9-q543-rqg4`, both High, both uncontrolled resource consumption, are fixed at **`jackson-databind` `2.12.7.1`** — a micro-patch on the very line this build already ships. The delivered `2.12.7` is named explicitly in both advisories' affected-versions lists, and `2.12.7.1` is the release immediately after it. That is a remediation distance of one patch release, not nine minors, and stating it as "requires 2.18.8" would have been wrong.

It is still not taken here, for two reasons that are worth separating because only the first is a rule:

- **R-1 bars it.** `2.12.7.1` is a security patch. R-1 admits a dependency change only for a specific Java 17 or Node 20 compatibility reason, and this one has none — `2.12.7` already clears the `java.time` accessibility failure that justified the Jackson advance. A change made for security alone is exactly the unjustified bump R-1's contrapositive forbids, and this page is not willing to violate a rule quietly in order to close a row.
- **It is not a one-line change, which an owner taking it needs to know.** The single property `fasterxml-jackson-core.version` governs **six** artifacts in `dependencyManagement` — `jackson-core`, `jackson-databind`, `jackson-annotations`, `jackson-datatype-jsr310`, `jackson-module-jsonSchema` and `jackson-datatype-hibernate5`. `2.12.7.1` is published for `jackson-databind` **only**; the corpus lists no fourth-component release anywhere on the `jackson-core` `2.12` line. Moving the shared property would therefore fail to resolve the other five. Clearing these two advisories requires **separating `jackson-databind` onto its own version axis** — structurally the same remedy the plan already applies to the EclipseLink ASM companion, whose 2.x line stops short of the version its siblings use. Small, well-understood, and a deliberate change to the dependency graph rather than a version-string edit.

So the accurate statement is: eight of the ten are far from a fix and barred by R-1's minimum-version direction; **two are one patch release from a fix and barred by R-1's requirement that a change have a compatibility reason.** Both are disclosures rather than remediations, but they are not the same disclosure, and the decision below is split accordingly.

## Finding 5 — The one advisory position this migration entered

This finding was not raised by review. It was found by completing the disclosure review asked for, and it is the reason completing it mattered.

`GHSA-vxf7-qj7q-83fh` — Low, CWE-208, *Spring Security Vulnerable to User Attribute Enumeration when Using DaoAuthenticationProvider* — names `org.springframework.security:spring-security-core`, which ships in the WAR. Unlike every other advisory on this page, **the base commit was not exposed to it and the delivered build is.**

The corpus publishes six affected ranges for it. Set against the two versions that matter:

| Affected range in the corpus | Baseline `5.4.2` | Delivered `5.8.16` |
| --- | :---: | :---: |
| `5.7.0` ≤ v ≤ `5.7.22` | outside | outside |
| `5.8.0` ≤ v ≤ `5.8.24` | outside | **inside** |
| `6.3.0` ≤ v ≤ `6.3.15` | outside | outside |
| `6.4.0` ≤ v ≤ `6.4.15` | outside | outside |
| `6.5.0` → fixed `6.5.10` | outside | outside |
| `7.0.0` → fixed `7.0.5` | outside | outside |

The baseline `5.4.2` falls below the lowest range and is therefore in none of them. The delivered `5.8.16` falls inside the second, and the corpus's own explicit affected-versions list for that range names `5.8.16` — so this is not an inference from range arithmetic, it is a listed version. **The Spring Security advance from `5.4.2` to `5.8.16` entered this advisory.**

**Why the advance was made anyway, and why it stands.** `5.4.2` is not a safe alternative on this runtime. The Spring Security line has to pair with the Spring Framework line, and Framework `5.3.39` is required for the JDK 17 auto-proxying fix that arrived in `5.3.9`; `5.8.16` is the last Spring Security release that pairs with Framework 5.3 without crossing into the jakarta namespace. Reverting to `5.4.2` to avoid one Low-severity enumeration advisory would reintroduce the Java 17 compatibility failure the migration exists to fix, and would do so while the two Spring Security advisories in Findings 1 and 2 — one of them **Critical** — remain present at `5.4.2` as well, since both cover it. Trading a Critical-bearing broken runtime for a Low-severity fix is not an improvement.

**Why it is not fixed.** The only fixed releases published for it are `6.5.10` and `7.0.5`. Both are Spring Security 6/7, which require Spring Framework 6, which requires the jakarta namespace across the reactor — barred absolutely by the plan's exclusion list, at the artifact level and not merely at the import level. **The 5.8 line has no fixed release at all**, so there is no in-scope remedy: not a patch, not a configuration change, not a same-line advance.

**What it actually exposes.** CWE-208 is an observable timing discrepancy. The advisory concerns `DaoAuthenticationProvider` revealing, through response timing, whether a submitted username corresponds to an existing user — user *enumeration*, not authentication bypass and not privilege escalation. It is rated Low for that reason. This page does not restate that as harmless: on a deployment whose user directory is itself sensitive, enumeration is the exposure. It states the scope precisely so the owner decision below is made against what the advisory says rather than against its identifier.

**How it is prevented from being quietly re-absorbed.** The triage producer treats an entered position as a gate failure, not a statistic, and it fails unless the entered set is **exactly** the set named in `smoke-evidence/advisory-corpus/acknowledged-entered-advisories.txt`. That is deliberately set equality in both directions: a newly entered advisory fails the gate because it is absent from that file, and an acknowledgement that no longer describes the build fails too, because a stale acknowledgement is a claim about the build that is no longer true. A blanket accept-flag was rejected for the obvious reason — it would silence the next one as well.

## Every advisory in the corpus

All 40, severity then identifier. This table is **generated** by `smoke-evidence/advisory-corpus/triage-advisory-corpus.sh`, which reads the corpus JSON and the built WAR and writes `smoke-evidence/advisory-corpus/advisory-triage.txt`; the rows below are that output rendered as a table. Regenerating it is a single command, given under [Verification](#verification). "Position" is the effect of this migration on the advisory, computed by comparing the baseline and delivered versions against every affected range, not asserted.

Where a fixed release exists it is the exact version string from the corpus. Where the corpus publishes no fix for any line, the cell reads **none published** rather than a dash, because a range with no fix at all is the load-bearing fact in several rows and abbreviating it would hide the point.

| # | Severity | Advisory | Artifact in `WEB-INF/lib` | Delivered | Position across the migration | Fixed release published in the corpus |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Critical | `GHSA-4wrc-f8pq-fpqp` | `spring-web` | `5.3.39` | carried | 6.0.0 |
| 2 | Critical | `GHSA-mf92-479x-3373` | `spring-security-web` | `5.8.16` | carried | 6.5.9, 7.0.4 |
| 3 | High | `GHSA-3chg-m5w7-qfv5` | `spring-webmvc` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 4 | High | `GHSA-775g-4xr8-78h8` | `spring-expression` | `5.3.39` | carried | **none published** |
| 5 | High | `GHSA-cx7f-g6mp-7hqm` | `spring-webmvc` | `5.3.39` | carried | 6.1.13 |
| 6 | High | `GHSA-g5vr-rgqm-vf78` | `spring-webmvc` | `5.3.39` | carried | 6.1.14 |
| 7 | High | `GHSA-h46c-h94j-95f3` | `jackson-core` | `2.12.7` | carried | 2.15.0 |
| 8 | High | `GHSA-j3rv-43j4-c7qm` | `jackson-databind` | `2.12.7` | carried | 2.18.8, 2.21.4, 3.1.4 |
| 9 | High | `GHSA-jjjh-jjxp-wpff` | `jackson-databind` | `2.12.7` | carried | 2.12.7.1, 2.13.4.2 |
| 10 | High | `GHSA-jmp9-x22r-554x` | `spring-core` | `5.3.39` | carried | 6.2.11 |
| 11 | High | `GHSA-jrv5-8w28-4265` | `spring-ldap-core` | `2.4.4` | carried | 3.3.8, 4.0.4 |
| 12 | High | `GHSA-r5w3-xv2f-j59q` | `spring-expression` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 13 | High | `GHSA-r7wm-3cxj-wff9` | `jackson-core` | `2.12.7` | carried | 2.18.8, 2.21.4, 3.1.4 |
| 14 | High | `GHSA-rgv9-q543-rqg4` | `jackson-databind` | `2.12.7` | carried | 2.12.7.1, 2.13.4 |
| 15 | High | `GHSA-rmj7-2vxq-3g9f` | `jackson-databind` | `2.12.7` | carried | 2.18.8, 2.21.4, 3.1.4 |
| 16 | High | `GHSA-x23c-287f-qqv5` | `spring-webmvc` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 17 | Moderate | `GHSA-293q-567p-wmwq` | `spring-security-web` | `5.8.16` | carried | 6.5.11 |
| 18 | Moderate | `GHSA-3wrr-7qpf-2prh` | `jackson-databind` | `2.12.7` | carried | 2.14.0 |
| 19 | Moderate | `GHSA-4773-3jfm-qmx3` | `spring-webmvc` | `5.3.39` | carried | 6.2.17, 7.0.6 |
| 20 | Moderate | `GHSA-4gc7-5j7h-4qph` | `spring-context` | `5.3.39` | carried | 6.1.14 |
| 21 | Moderate | `GHSA-5jmj-h7xm-6q6v` | `jackson-databind` | `2.12.7` | carried | 2.18.9, 2.21.5, 2.22.1, 3.1.4 |
| 22 | Moderate | `GHSA-6p4f-wcwh-5vvm` | `spring-webmvc` | `5.3.39` | carried | 6.2.18, 7.0.7 |
| 23 | Moderate | `GHSA-72pg-x5f8-j25j` | `spring-webmvc` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 24 | Moderate | `GHSA-7fch-4f2f-jcgm` | `spring-websocket` | `5.3.39` | carried | 6.2.12 |
| 25 | Moderate | `GHSA-957g-f97v-vppc` | `spring-webmvc` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 26 | Moderate | `GHSA-cjpg-rgq5-fr37` | `spring-webmvc` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 27 | Moderate | `GHSA-h3qp-gqrc-q736` | `spring-webmvc` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 28 | Moderate | `GHSA-hgj6-7826-r7m5` | `jackson-databind` | `2.12.7` | carried | 2.18.8, 2.21.4, 3.1.4 |
| 29 | Moderate | `GHSA-mq64-j8f9-9gcj` | `spring-webmvc` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 30 | Moderate | `GHSA-q723-847q-5g8g` | `spring-websocket` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 31 | Moderate | `GHSA-r936-gwx5-v52f` | `spring-webmvc` | `5.3.39` | carried | 6.2.10 |
| 32 | Moderate | `GHSA-w3c8-7r8f-9jp8` | `spring-webmvc` | `5.3.39` | carried | 5.3.42 |
| 33 | Moderate | `GHSA-wf8f-6423-gfxg` | `jackson-core` | `2.12.7` | carried | 2.13.0 |
| 34 | Moderate | `GHSA-wxpp-56q6-5pcg` | `spring-expression` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 35 | Low | `GHSA-4wp7-92pw-q264` | `spring-context` | `5.3.39` | carried | 6.1.20, 6.2.7 |
| 36 | Low | `GHSA-659m-px2c-25wj` | `spring-core` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 37 | Low | `GHSA-6hcq-hmm3-jj3c` | `spring-webmvc` | `5.3.39` | carried | 6.2.17, 7.0.6 |
| 38 | Low | `GHSA-9f52-rjqv-25qv` | `spring-expression` | `5.3.39` | carried | 6.2.19, 7.0.8 |
| 39 | Low | `GHSA-vxf7-qj7q-83fh` | `spring-security-core` | `5.8.16` | **ENTERED** | 6.5.10, 7.0.5 |
| 40 | Low | `GHSA-wg35-8jpf-2xv3` | `spring-webmvc` | `5.3.39` | carried | 6.2.18, 7.0.7 |

Reading the fixed-release column against the delivered column is the whole disclosure in compressed form: **every fixed release published for a Spring row is on a 6.x or 7.x line**, which is Spring 6/7 and therefore the jakarta namespace the plan excludes absolutely; `spring-expression`'s `GHSA-775g-4xr8-78h8` has no published fix on any line; and the only fixes reachable without crossing a major boundary are the two `jackson-databind` `2.12.7.1` rows analysed in Finding 4. There is no row where an in-scope remedy was available and declined for convenience.

## What an owner has to decide

Six decisions, and none of them belongs to this change set. The first is new and is the one this page most wants read:

| # | Decision | Why it cannot be taken here |
| --- | --- | --- |
| 1 | **Accept `GHSA-vxf7-qj7q-83fh`, the one advisory this migration entered**, for the life of the 5.8 line — or fund the Spring 6 / jakarta migration | Its only published fixes are `6.5.10` and `7.0.5`; the 5.8 line has **no** fixed release, and reverting to `5.4.2` reintroduces the Java 17 auto-proxying failure while leaving a Critical advisory in place |
| 2 | Whether to take **`jackson-databind` `2.12.7.1`**, which clears two High advisories one patch release away, by separating databind onto its own version axis | R-1 admits a dependency change only for a specific Java 17 or Node 20 compatibility reason; `2.12.7` already clears the compatibility failure, so a security-motivated patch is out of scope for this change set even though it is small |
| 3 | Accept the two Spring Security advisories in Findings 1 and 2 for the life of the 5.8 line, or fund the Spring 6 / jakarta migration that is the only published remedy | The jakarta namespace and Spring 6 are excluded absolutely by the migration plan's own scope boundary |
| 4 | Accept the Spring LDAP advisory, or fund the same jakarta move for the LDAP client | Its only fixed lines are 3.3.8 and 4.0.4, both jakarta |
| 5 | Accept the remaining eight Jackson advisories, or authorise a Jackson advance well beyond the minimum-capable floor | R-1 permits only the minimum version that clears the compatibility failure |
| 6 | Whether the X.509 authentication path should be retired or fronted by a compensating control while the advisory is unfixed | The call site is base-commit behaviour and its removal is a functional change, which this migration excludes |
| 7 | Accept the **26 advisories against Spring Framework artifacts** — 1 Critical, 7 High, 13 Moderate, 5 Low — for as long as the reactor stays on Spring Framework 5.3 | Every published fix for them is on a 6.x or 7.x line, and `GHSA-775g-4xr8-78h8` has no published fix at all |

**One limitation of this page, stated rather than left for a reader to discover.** The corpus is a **point-in-time capture, dated August 7, 2026**, and nothing in this repository re-queries it. Advisories published after that date do not appear here, and a fixed release published after that date will not appear in a fixed-versions cell — including, potentially, a fix on the 5.8 or 2.12 lines that would change decisions 1 and 2 above. Every count on this page is a count over that capture and is honest only about it. Re-running the capture script is the only way to move the date, and it needs network access the validation environment does not have; the corpus verification script therefore checks the capture's integrity against its SHA-256 manifest, not its freshness.

## Verification

Every figure on this page is reproducible from the committed corpus, and the complete table is not merely reproducible but **generated**. Run from the repository root:

```bash
bash docs/migration/smoke-evidence/advisory-corpus/triage-advisory-corpus.sh
sed -n '/===== totals/,/===== rows/p' docs/migration/smoke-evidence/advisory-corpus/advisory-triage.txt
```

Or run the whole offline gate, which additionally checks that regenerating the triage does not change its committed body — the condition in which a figure quoted on this page has silently stopped being true:

```bash
bash docs/migration/smoke-evidence/advisory-corpus/verify-advisory-corpus.sh --offline
```

That must exit `0` and print the seven counts quoted in [What the complete corpus says](#what-the-complete-corpus-says): 40 advisories, 40 whose coordinate is in the WAR, `CRITICAL=2 HIGH=14 MODERATE=18 LOW=6`, 39 carried, 0 cleared, 1 entered, 0 undetermined — followed by `entered-and-acknowledged : 1` and `entered-and-NOT-acknowledged : 0`.

The gate behind that last pair is the claim most worth testing, because a disclosure that cannot fail is not a control. Both directions must break it:

```bash
: > /tmp/ack-empty.txt
bash docs/migration/smoke-evidence/advisory-corpus/triage-advisory-corpus.sh \
     --acknowledged /tmp/ack-empty.txt --out /tmp/t1.txt; echo "exit=$?"

printf 'GHSA-vxf7-qj7q-83fh\nGHSA-wg35-8jpf-2xv3\n' > /tmp/ack-stale.txt
bash docs/migration/smoke-evidence/advisory-corpus/triage-advisory-corpus.sh \
     --acknowledged /tmp/ack-stale.txt --out /tmp/t2.txt; echo "exit=$?"
```

The first must exit `1` reporting an ENTERED position that is **not acknowledged** — this is what a newly entered advisory would do. The second must exit `1` reporting an acknowledged position that is **no longer entered** — a stale acknowledgement. Neither run may modify the committed `advisory-triage.txt`.

Then confirm Finding 5's range arithmetic directly against the corpus, since it is the one row where this page reports a regression:

```bash
CORPUS=docs/migration/smoke-evidence/advisory-corpus/2026-08-07-maven-osv-advisories.json
python3 - "$CORPUS" <<'EOP'
import json,sys
d=json.load(open(sys.argv[1]))
for a in d['advisories']:
    if (a.get('id') or a.get('ghsa_id')) != 'GHSA-vxf7-qj7q-83fh': continue
    for aff in a.get('affected',[]):
        vs=set(aff.get('versions') or [])
        print(aff['ranges'][0]['events'], '| 5.4.2 listed:', '5.4.2' in vs, '| 5.8.16 listed:', '5.8.16' in vs)
EOP
```

Exactly one line must print `5.8.16 listed: True`, and **no** line may print `5.4.2 listed: True`. That is the entered position, read out of the corpus rather than out of this page.

Confirm Finding 4's correction the same way — that `2.12.7.1` is published for `jackson-databind` and for nothing else on the 2.12 line, which is what makes the remedy an axis split:

```bash
grep -n 'fasterxml-jackson-core.version' pom.xml | head -1
grep -c 'fasterxml-jackson-core.version}' pom.xml
unzip -l acm-standard-applications/arkcase/target/arkcase-2021.03.war \
  | grep -oE 'jackson-(core|databind|annotations)-[0-9][^ ]*\.jar' | sort -u
```

The first must print `2.12.7`; the second must print `6`, the number of managed artifacts sharing that one property and therefore the reason the property cannot simply be moved to a databind-only release; the third must print `jackson-annotations-2.12.7.jar`, `jackson-core-2.12.7.jar` and `jackson-databind-2.12.7.jar`, confirming all three ship at the shared version.

Then confirm the two claims that carry Finding 2, by reading the source rather than this page:

```bash
F=acm-services/acm-service-login/src/main/java/com/armedia/acm/auth/AcmBasicAndTokenAuthenticationFilter.java
grep -n 'SubjectDnX509PrincipalExtractor' $F
git show c8f6226105:$F | sha256sum
sha256sum $F
grep -n 'spring.ldap.version\|fasterxml-jackson-core.version\|spring.security.version' pom.xml | head -3
```

The first must print two lines — the import at `:44` and the construction at `:219`; the second and third must print the **same** digest, which is the whole-file identity claim above; the fourth must print `2.12.7`, `2.4.4` and `5.8.16`, three of the four pinned versions this page discusses.

- Confirm by reading that **no advisory on this page is described as fixed, mitigated or compensated**. Thirty-nine are disclosed as inherited and unfixable within the plan's boundary, and one as entered and unfixable within it; there is no third category.
- Confirm that **every fixed-version cell is either an exact release or the words "none published"**. A range with no fix is the load-bearing fact in several rows, so it is never abbreviated to a dash.
- Confirm that the advisory count on this page equals the corpus count. Both of these must print **40**, and a page that discusses a subset while claiming to cover the corpus is the finding this section exists to prevent recurring:

```bash
grep -cE '^\| [0-9]+ \| (Critical|High|Moderate|Low) \| `GHSA-' docs/migration/backend-dependency-security.md
awk -F': *' '/^advisories-in-corpus /{ print $2 }' docs/migration/smoke-evidence/advisory-corpus/advisory-triage.txt
```

## Related pages

- [Dependency Change Inventory](dependency-change-inventory.md) — the rows for the Spring Security, Spring LDAP and Jackson changes, each with its Java 17 compatibility reason
- [Ambiguity Resolutions](ambiguity-resolutions.md) — entry 20, the Spring LDAP advance and the four alternatives rejected
- [Pre-existing Defects](pre-existing-defects.md) — where exposure that predates this migration is registered
- [Frontend Dependency Security](frontend-dependency-security.md) — the npm counterpart of this page
