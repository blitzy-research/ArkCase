# WAR Packaging Evidence

The deployable artefact of this migration, listed and digested at the delivered revision.

This page exists because a runtime migration is only as good as the archive it produces. The reactor
compiling at release 17 and the unit suite matching its baseline are both necessary and neither is
sufficient: the classpath the application actually runs against is the one inside the WAR, and until
that is enumerated, claims about which JPA API jar is on it or whether any `jakarta`-named artefact
reached it are inferences from build files rather than observations of the artefact.

Every figure below was read out of the archive named here, with the command that produced it stated
beside it. Nothing is quoted from a build log.

## The archive

| Field | Value |
|---|---|
| Path | `acm-standard-applications/arkcase/target/arkcase-2021.03.war` |
| Reactor coordinates | `com.armedia.acm.acm-standard-applications:arkcase:2021.03` |
| Revision | `0e13c8620de59ca66bfe8d0e261c82f15acc9cfd` |
| Size | 273,548,237 bytes |
| SHA-256 | `d3cf6740a5e62ea408b2157b7f258d421791a7e4482fc18dade42523217a513c` |
| Entries | 2,576 |
| `WEB-INF/lib` jars | 635 |
| Built with | OpenJDK 17.0.19, Apache Maven 3.8.7, `mvn -B -ntp -o -pl acm-standard-applications/arkcase -am -DskipTests clean package`, BUILD SUCCESS |

```bash
W=acm-standard-applications/arkcase/target/arkcase-2021.03.war
sha256sum "$W"
unzip -Z1 "$W" > entries.txt && wc -l entries.txt
grep -c '^WEB-INF/lib/.*\.jar$' entries.txt
```

### The listing was taken from a clean source tree, and that is not a detail

A first listing of this archive reported **34,115** entries, of which **31,527** were under
`resources/node_modules/`. Those were not packaged by the build configuration; they were present
because a frontend install had been run in the source tree beforehand and the WAR packaging swept the
webapp directory as it found it. The archive above was rebuilt after removing the untracked frontend
build output — `resources/node_modules`, `resources/assets/dist` and `resources/home.html` — and the
entry count fell from 34,115 to 2,576.

The clean tree is the correct frame, and the reason is architectural rather than tidiness. The
frontend pipeline runs at **container startup**, not at Maven build time: no project file in the
reactor declares a frontend build plugin, a Node version or a Grunt or package-manager invocation.
`AngularResourceCopier` installs the dependency graph and runs the Grunt default task inside the
deployed webapp. So `node_modules` and `assets/dist` are *created by the deployment*, and a WAR
carrying a locally-installed copy of them would describe the machine that built it rather than the
artefact CI produces.

Two figures record that this is now true rather than assumed:

```bash
grep -c '^resources/node_modules/' entries.txt      # 0
grep -c '^resources/assets/dist/'  entries.txt      # 0
```

## The three newly created frontend files are packaged

The migration adds three files to the frontend tree, and all three must reach the archive or the
startup build cannot run from the lockfile it is supposed to run from.

```bash
grep -E '^resources/(package-lock\.json|\.nvmrc|profiles\.js)$' entries.txt
```

```text
resources/.nvmrc
resources/profiles.js
resources/package-lock.json
```

**No packaging descriptor change was needed for this, and that was verified rather than assumed.**
Zero of the reactor's project files declare `packagingExcludes`, `warSourceExcludes` or
`webResources`, so a new file in the webapp directory is packaged by default. Their presence here is
therefore the expected outcome, and their *absence* would have indicated a genuine packaging fault
rather than a missing exclusion edit.

The frozen contract files sit beside them, unchanged:

```text
resources/Gruntfile.js
resources/package.json
resources/config.js
resources/.jshintrc
resources/.csslintrc
```

### The superseded lockfile is gone from the archive

```bash
grep -c 'yarn.lock' entries.txt                     # 0
```

This check is worth keeping because it did not always return zero. The first listing — the one taken
over the polluted tree — returned **1**, and the single hit was
`resources/node_modules/tiny-lr/yarn.lock`: a third-party package's own lockfile, inside an installed
dependency tree, not the project's. It was never a survival of the migrated file. It is recorded here
so that a reviewer who runs this check against a tree with dependencies installed and gets a non-zero
answer knows what they are looking at.

## The namespace directive holds at the artefact level

```bash
grep -ci jakarta entries.txt                        # 0
```

Not one entry in the archive carries `jakarta` in its name, at any depth — no jar, no class, no
resource. This is the strongest form of the namespace check available, because it is made against the
deployed classpath rather than against import statements: an artefact could carry `javax`-prefixed
classes under a `jakarta`-named coordinate and pass a source-level check while failing this one.

### Exactly one JPA API jar, javax-named and javax-contented

```bash
grep -E '^WEB-INF/lib/(javax\.persistence|org\.eclipse\.persistence)' entries.txt | sort
```

```text
WEB-INF/lib/javax.persistence-2.2.1.jar
WEB-INF/lib/org.eclipse.persistence.antlr-2.7.16.jar
WEB-INF/lib/org.eclipse.persistence.asm-9.8.0.jar
WEB-INF/lib/org.eclipse.persistence.core-2.7.16.jar
WEB-INF/lib/org.eclipse.persistence.jpa-2.7.16.jar
WEB-INF/lib/org.eclipse.persistence.jpa.jpql-2.7.16.jar
WEB-INF/lib/org.eclipse.persistence.moxy-2.7.16.jar
```

Three separate decisions are visible in those seven lines, and each was made for a reason recorded in
the [Dependency Change Inventory](dependency-change-inventory.md):

- **`javax.persistence-2.2.1.jar` appears once and its content-identical `jakarta`-named twin does not
  appear at all.** The twin is a transitive of `org.eclipse.persistence.jpa:2.7.16`; it is excluded at
  the managed entry that would otherwise introduce it. Carrying both would have placed duplicate
  `javax/persistence` classes on this classpath with order-dependent resolution.
- **`org.eclipse.persistence.asm-9.8.0.jar` carries a 9.x version while its siblings carry 2.7.16.**
  That artefact publishes no 2.7.16, so the family shares two version axes rather than one; a single
  shared property would have failed resolution outright.
- **The provider is still EclipseLink**, on the last line that uses the `javax.persistence`
  namespace.

### The reinstated platform APIs are on the deployed classpath

```bash
grep -E '^WEB-INF/lib/(jaxb-api|jaxb-runtime|javax\.annotation-api|javax\.activation)-' entries.txt | sort
```

```text
WEB-INF/lib/javax.activation-1.2.0.jar
WEB-INF/lib/javax.annotation-api-1.3.2.jar
WEB-INF/lib/jaxb-api-2.3.1.jar
WEB-INF/lib/jaxb-runtime-2.3.1.jar
```

All four are the artefacts the platform removed in version 11 and that the aggregator reinstates
reactor-wide, and all four are `javax`-namespaced. The runtime is present as well as the API: the API
alone would compile the 84 consuming source files and then fail at the first marshal.

`javax.activation-1.2.0.jar` is the reference implementation rather than the API-only artefact, and
the difference is behavioural. The API-only jar omits the default MIME-type and mailcap resources,
which five of the six activation-consuming source files read; selecting it would have compiled,
deployed, and then resolved MIME types differently.

### The framework generations are the intended ones

```bash
grep -E '^WEB-INF/lib/spring-(core|context|beans|web|webmvc)-' entries.txt | sort
grep -E '^WEB-INF/lib/spring-security-(core|config|crypto)-' entries.txt | sort
```

```text
WEB-INF/lib/spring-beans-5.3.39.jar
WEB-INF/lib/spring-context-5.3.39.jar
WEB-INF/lib/spring-context-support-5.3.39.jar
WEB-INF/lib/spring-core-5.3.39.jar
WEB-INF/lib/spring-web-5.3.39.jar
WEB-INF/lib/spring-webmvc-5.3.39.jar
WEB-INF/lib/spring-security-config-5.8.16.jar
WEB-INF/lib/spring-security-core-5.8.16.jar
WEB-INF/lib/spring-security-crypto-5.8.16.jar
```

Forty-two Spring jars in total, every framework jar on 5.3.39 and every security jar on 5.8.16 — the
tail of the 5.3 line and the security line that pairs with it. No Spring 6 jar and no Boot starter is
present.

### The bytecode-layer fixes reached the archive

```text
WEB-INF/lib/asm-9.8.jar
WEB-INF/lib/mvel2-2.4.15.Final.jar
```

The expression language at 2.4.15.Final is the highest-impact runtime fix in the backend track: the
version it replaces throws a verification error from its own bytecode-generating accessor optimiser,
and it is reached from 43 live decision tables through a rule compiler that declares it with no
version of its own.

### No test-scope artefact leaked into the deployable

```bash
for a in powermock easymock mockito junit- hamcrest; do
    printf '%-14s %s\n' "$a" "$(grep -c "^WEB-INF/lib/${a}" entries.txt)"
done
```

Every one returns **0**. The mocking-stack changes — the removed framework, the removed class
extension, the advanced core and the added inline mock maker — are confined to test scope, which is
where the accessibility failures that motivated them were.

## An observed pre-existing condition, registered and not repaired

**Two providers of the `org/objectweb/asm` package are on the deployed classpath**, and this page
records it rather than leaving it to be found:

```bash
grep 'asm' entries.txt | grep '\.jar$' | sort
```

```text
WEB-INF/lib/asm-3.3.1.jar
WEB-INF/lib/asm-9.8.jar
WEB-INF/lib/org.eclipse.persistence.asm-9.8.0.jar
WEB-INF/lib/subethasmtp-smtp-1.2.jar
```

`asm-3.3.1.jar` is the old `asm:asm` coordinate and `asm-9.8.jar` is `org.ow2.asm:asm`. Extracting
both and comparing their entries gives **20 overlapping class names**, `ClassReader` among them —
and ASM 3.3.1 cannot read a class file at major version 61.

It is nonetheless **not a migration regression**, and that was established by measurement rather than
by argument:

- The old coordinate arrives transitively and only transitively, through
  `chemistry-opencmis-client-impl:1.1.0` → `cxf-rt-frontend-jaxws:3.0.12`. Neither of those versions
  changed in this migration; the content-management client is explicitly out of scope for version
  change.
- **The same overlap existed at the base commit.** There the reactor pinned `org.ow2.asm:asm` at
  5.0.3, and 5.0.3 against 3.3.1 overlaps **21** class names — one more than the pair overlaps today.
- Neither the base project file nor the delivered one excludes `asm:asm` from that chain; the count
  of that exclusion is identical in both, at two occurrences, and both belong to a different artefact
  family.

So the condition is inherited, its severity did not increase, and the rule governing discovered
pre-existing defects requires it to be documented rather than repaired. It is registered in
[Pre-existing Defects](pre-existing-defects.md). What the migration *did* change on this path is
strictly an improvement: the provider the reactor pins can now read the class files the reactor
produces, where the version it replaced could not read them at all.

## What this page does not claim

- **It is not a deployment result.** It establishes what is inside the archive. Whether the
  application initialises from it, and what its startup log contains, is a separate observation
  recorded under `smoke-evidence/`.
- **It is not a statement about the extra plugins.** `acm-personnel-security-plugin` is a reactor
  member but is not a dependency of this WAR, so the standalone scripting engine that module declares
  at runtime scope is correctly absent from this listing. A reviewer searching this archive for that
  engine will find nothing, and that is the expected result rather than evidence that the declaration
  does not reach a runtime; the module is deployed as an extension alongside the application, and the
  reasoning for the declaration is recorded at the version property in the root project file and in
  the module's own.
- **The digest is of this build, not of every build.** The archive embeds jar manifests and entry
  timestamps, so two builds of the same source do not produce the same bytes. The digest identifies
  the archive that was listed here; it is not a reproducibility claim, and the frontend track's
  byte-identity criterion — which *is* one — is asserted over the five built asset artefacts instead.

Related registers: [Dependency Change Inventory](dependency-change-inventory.md),
[Baseline Test Failures](baseline-test-failures.md), [Pre-existing Defects](pre-existing-defects.md),
[Surefire Evidence Archive](surefire-evidence-archive.md).
