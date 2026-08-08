# Backend Dependency Security

## Why this page exists

Code review raised four security findings against backend dependencies this migration touches: an advisory against the Spring Security version it targets, a second advisory against the same artifact reached through X.509 client-certificate authentication, an advisory against the Spring LDAP version it advances to, and a set of ten advisories against the Jackson line it pins. None of the four is disputed. This page records each one, states what the migration's own rules permitted it to do about it, and — where the answer is nothing — says so with the evidence rather than leaving the finding unanswered.

It is the backend counterpart of [Frontend Dependency Security](frontend-dependency-security.md) and follows the same posture: the exposure is measured, the inherited part is separated from the introduced part, and no advisory is closed by assertion.

**Every fixed-version figure below was read out of the advisory corpus committed in this repository**, at `smoke-evidence/advisory-corpus/2026-08-07-maven-osv-advisories.json`, whose own SHA-256 manifest and verification script sit beside it. Nothing here is quoted from a vendor page or recalled from a bulletin. The corpus was captured on August 7, 2026.

## The one conclusion that governs all four findings

Three of the four advisories have **no fix published for the release line this migration is confined to**, and the fourth has fixes that would breach the rule under which the artifact was changed at all. That is not a convenient reading of the data; it is what the ranges say, and the ranges are reproduced below in full.

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

**Why the advisories are not cleared as well.** Clearing all ten requires `jackson-core` `2.21.4` and `jackson-databind` `3.1.4` at the top of their ranges; even the bulk of them requires `2.18.8`. R-1 directs that a compatibility-blocking library be upgraded to its **minimum Java-17-capable version**, and that floor was established by execution at `2.12.7`. Advancing nine further minor releases, or across a major boundary to `3.1.4`, would be a change without a Java 17 compatibility reason for the distance travelled — which R-1's contrapositive forbids as firmly as it forbids an unjustified omission — and would move a serialization library that shapes REST response bodies the PRESERVE list freezes.

## What an owner has to decide

Four decisions, and none of them belongs to this change set:

| # | Decision | Why it cannot be taken here |
| --- | --- | --- |
| 1 | Accept the two Spring Security advisories for the life of the 5.8 line, or fund the Spring 6 / jakarta migration that is the only published remedy | The jakarta namespace and Spring 6 are excluded absolutely by the migration plan's own scope boundary |
| 2 | Accept the Spring LDAP advisory, or fund the same jakarta move for the LDAP client | Its only fixed lines are 3.3.8 and 4.0.4, both jakarta |
| 3 | Accept the ten Jackson advisories, or authorise a Jackson advance well beyond the minimum-capable floor | R-1 permits only the minimum version that clears the compatibility failure |
| 4 | Whether the X.509 authentication path should be retired or fronted by a compensating control while the advisory is unfixed | The call site is base-commit behaviour and its removal is a functional change, which this migration excludes |

## Verification

Every figure on this page is reproducible from the committed corpus. Run from the repository root:

```bash
CORPUS=docs/migration/smoke-evidence/advisory-corpus/2026-08-07-maven-osv-advisories.json
grep -c 'GHSA-mf92-479x-3373' $CORPUS
grep -c 'GHSA-293q-567p-wmwq' $CORPUS
grep -c 'GHSA-jrv5-8w28-4265' $CORPUS
python3 -c "import json;d=json.load(open('$CORPUS'));print(json.dumps(d)[:0] or 'corpus parses')"
```

Then confirm the two claims that carry the argument, by reading the source rather than this page:

```bash
F=acm-services/acm-service-login/src/main/java/com/armedia/acm/auth/AcmBasicAndTokenAuthenticationFilter.java
grep -n 'SubjectDnX509PrincipalExtractor' $F
git show c8f6226105:$F | sha256sum
sha256sum $F
grep -n 'spring.ldap.version\|fasterxml-jackson-core.version\|spring.security.version' pom.xml | head -3
```

The first must print two lines — the import at `:44` and the construction at `:219`; the second and third must print the **same** digest, which is the whole-file identity claim above; the fourth must print `2.12.7`, `2.4.4` and `5.8.16`, the three pinned versions this page discusses.

- Confirm by reading that **no advisory on this page is described as fixed, mitigated or compensated**. Three are disclosed as unfixable within the plan's boundary and one as unchanged from baseline; there is no fourth category on this page.
- Confirm that **every fixed-version cell is either an exact release or the words "none published"**. A range with no fix is the load-bearing fact in three of the four findings, so it is never abbreviated to a dash.

## Related pages

- [Dependency Change Inventory](dependency-change-inventory.md) — the rows for the Spring Security, Spring LDAP and Jackson changes, each with its Java 17 compatibility reason
- [Ambiguity Resolutions](ambiguity-resolutions.md) — entry 20, the Spring LDAP advance and the four alternatives rejected
- [Pre-existing Defects](pre-existing-defects.md) — where exposure that predates this migration is registered
- [Frontend Dependency Security](frontend-dependency-security.md) — the npm counterpart of this page
