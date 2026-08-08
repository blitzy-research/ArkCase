# Developer Setup

This page documents how developers can build and run ArkCase from source. If you only want to evaluate ArkCase, use the pre-built VM described on the [home page](index.md) instead.

## Prerequisites

- At least 16 GB RAM
- At least 50 GB disk space (the Vagrant VM is roughly 11 GB)
- Java 17 (Eclipse Temurin, formerly AdoptOpenJDK, works well). Java 17 is the required LTS release: the Maven build compiles at `maven.compiler.release=17`, so an earlier JDK can neither build nor run ArkCase.
- Maven 3.8+ <https://maven.apache.org>. Maven 3.8 and later block artifact resolution over plain HTTP; the build declares only HTTPS remote repositories and local `file://` repositories.
- VirtualBox <https://www.virtualbox.org>
- Vagrant <https://www.vagrantup.com>
- Tomcat 9 <https://tomcat.apache.org>
- git <https://git-scm.com/>
- Node 20 LTS <https://nodejs.org>. The required version is pinned in `acm-standard-applications/arkcase/src/main/webapp/resources/.nvmrc`, so `nvm use` selects it without an argument.
- npm 10 (comes with Node 20)

## Build the Vagrant VM

The Vagrant VM hosts the backing services ArkCase requires: Solr, ActiveMQ, MySQL, Alfresco, and Pentaho.

1. Install all the prerequisites above.
2. Build the Vagrant VM by following the instructions in the `arkcase-ce` repository: <https://github.com/ArkCase/arkcase-ce>.

After the VM is up, the following URLs should respond from your browser. ArkCase uses a self-signed TLS certificate, so you will have to accept your browser's warning about the unrecognized certificate.

- <https://arkcase-ce.local/solr>
- <https://arkcase-ce.local/share>
- <https://arkcase-ce.local/pentaho>
- <https://arkcase-ce.local/VirtualViewerJavaHTML5> (expect a 503 error from this URL)

## Build the WAR File

Clone this repository, change into the root folder, and run:

```bash
mvn -DskipITs clean install
```

This runs the unit tests and produces the WAR file at `acm-standard-applications/arkcase/target/arkcase-<version>.war`.

**Do not cap the build metaspace.** The reactor builds all of its modules in a single JVM, so the class metadata of every module has to coexist in one metaspace. A `MAVEN_OPTS` containing `-XX:MaxMetaspaceSize` set below roughly 1 GB aborts the build part-way through with nothing but `[ERROR] Metaspace`, which reads like a module failure rather than a memory ceiling. `MAVEN_OPTS="-Xmx1400m -Xss512k"` builds the whole reactor; the GitLab pipeline uses `-XX:MetaspaceSize` — an initial size, not a limit — for the same reason.

## Configuration Folder

ArkCase requires a configuration folder which lives in another GitHub repository: <https://github.com/ArkCase/.arkcase>. Follow the instructions at that link to set up the configuration folder.

The build command above skips the integration tests, so it does not need this folder. `mvn verify` does: the integration-test Spring contexts import `${user.home}/.arkcase/acm/encryption/spring-properties-encryption.xml` and `${user.home}/.arkcase/acm/app-config.xml` directly, read `${user.home}/.arkcase/acm/conf.yml`, and decrypt property values with the key material under `${user.home}/.arkcase/acm/private`. Without the folder those tests fail during context initialisation with `FileNotFoundException` on a `.arkcase` path, which looks like a code failure and is not one. Set the folder up, and start the configuration server described below, before reading anything into an integration-test result.

### DEPLOYMENT PRECONDITION — the configuration folder's security schema declarations must be updated for Spring Security 5.8

`WEB-INF/web.xml` loads `file:${user.home}/.arkcase/acm/spring-security/spring-security-config-*.xml` from the configuration folder into the same root application context as ArkCase's own security configuration. ArkCase runs Spring Security 5.8, whose XML namespace handler refuses to parse a document whose `xsi:schemaLocation` names an older security schema than the version on the classpath, so **every one of those files must declare the version-less schema**:

```xml
http://www.springframework.org/schema/security http://www.springframework.org/schema/security/spring-security.xsd
```

The configuration repository currently ships eight of them — `-ldap`, `-oidc`, `-okta`, `-kerberos`, `-saml`, `-external`, `-external-oidc` and `-external-saml` — declaring `spring-security-5.4.xsd`. Deploying against an unmodified folder fails at startup with `BeanDefinitionParsingException: … You cannot use a spring-security-2.0.xsd or … schema with Spring Security 5.8. Please update your schema declarations to the 5.8 schema.`, and every request returns HTTP 404 because the context never initialises. Replacing `spring-security-5.4.xsd` with `spring-security.xsd` in those files is a namespace-declaration change only: it alters no `<http>`, `<intercept-url>`, `<form-login>` or method-security semantics. ArkCase's own three declarations were changed the same way in this repository; the configuration folder lives in a separate repository and has to be updated there. The reasoning, and why the version-less form was chosen over a pinned `spring-security-5.8.xsd`, are recorded in the [Dependency Change Inventory](migration/dependency-change-inventory.md) and [Ambiguity Resolutions](migration/ambiguity-resolutions.md).

**This is a precondition of the deployment contract rather than a defect in this repository.** The configuration folder is a separate deliverable in a separate repository, released independently of the application, and it is not in the migration's file list. Satisfy it once per configuration folder, before starting Tomcat:

```bash
cd ${HOME}/.arkcase/acm/spring-security
grep -l 'spring-security-5\.4\.xsd' spring-security-config-*.xml     # expect the eight files named above
sed -i 's|spring-security-5\.4\.xsd|spring-security.xsd|g' spring-security-config-*.xml
grep -c 'spring-security-5\.4\.xsd' spring-security-config-*.xml     # every file must now report 0
```

The last command is the gate: while any file still reports a non-zero count the root context will not initialise and every request returns HTTP 404. The same change belongs upstream in [`ArkCase/.arkcase`](https://github.com/ArkCase/.arkcase) so a fresh clone is deployable without it.

## Run the Configuration Server

Starting with version 3.3.1, ArkCase requires a separate configuration server based on Spring Cloud Config Server (<https://spring.io/projects/spring-cloud-config>).

1. Download the most recent `config-server.jar` from <https://github.com/ArkCase/acm-config-server/releases>.
2. Start the process:

   ```bash
   java -jar config-server-0.0.1.jar
   ```

   Replace `0.0.1` with the version you downloaded. The config server runs on port 9999 by default. To choose a different port, pass `-Dserver.port=8888` (or your desired port).

## Configure Tomcat

### Tomcat Native Connector

Make sure the Tomcat native connector library is installed.

- macOS: `brew install tomcat-native` (install Homebrew from <https://brew.sh/> first if needed).
- Windows: download from <https://tomcat.apache.org/download-native.cgi>.
- Linux: build using the instructions at the same URL.

### Tomcat TLS Configuration

In your Tomcat 9 installation, edit `conf/server.xml` and add a TLS connector below the existing port 8080 connector. See the upstream README for the full XML snippet. Note that the snippet expects keystore/truststore files under `${user.home}/.arkcase/acm/private/`.

### Tomcat `setenv.sh`

This block is a duplicate of the one in the upstream README, and the README is the authoritative copy. It is reproduced byte for byte so the two cannot drift, and both were corrected together: the version this file carried until now was reproduced from the README including three defects that made it unusable as shell — a `${user.home}` token that is a Java property placeholder rather than a shell expansion, a stray quote inside `JAVA_OPTS` that terminated the assignment early and folded `-Xms`/`-Xmx` into a property value, and an unterminated `CATALINA_OPTS` assignment containing a bare parenthesised placeholder. `sh -n` rejected it. The migration is required to deliver an updated production launch configuration, and a launch configuration a shell will not source cannot be one, so it is corrected rather than registered; the correction is recorded with its authority in the migration notes.

Create the file `bin/setenv.sh`, mark it executable, and set the contents as the following. Tomcat sources this file with `.`, so it must be valid shell; every value it needs comes from the environment and is checked before it is used.

```bash
#!/bin/sh

# Fail closed on every value this file needs and does not have.  An unset secret that is
# exported as an empty string does not announce itself: it surfaces much later as a TLS
# handshake that fails, or as a JVM that starts and then cannot read its own keystore.
: "${ARKCASE_KEYSTORE_PASSWORD:?set the ArkCase keystore password from your secret manager}"
: "${ARKCASE_TRUSTSTORE_PASSWORD:?set the ArkCase truststore password from your secret manager}"
: "${TOMCAT_NATIVE_LIB:?set the directory holding the Tomcat native library, e.g. /usr/local/opt/tomcat-native/lib}"

# ${HOME} is the shell's own variable, so nothing has to be edited by hand on any
# platform: on MacOS X it already expands to /Users/<you>.
ARKCASE_HOME="${HOME}/.arkcase"

JAVA_OPTS="-Djava.net.preferIPv4Stack=true"
JAVA_OPTS="${JAVA_OPTS} -Duser.timezone=GMT"
JAVA_OPTS="${JAVA_OPTS} -Djavax.net.ssl.keyStore=${ARKCASE_HOME}/acm/private/arkcase.ks"
JAVA_OPTS="${JAVA_OPTS} -Djavax.net.ssl.keyStorePassword=${ARKCASE_KEYSTORE_PASSWORD}"
JAVA_OPTS="${JAVA_OPTS} -Djavax.net.ssl.trustStore=${ARKCASE_HOME}/acm/private/arkcase.ts"
JAVA_OPTS="${JAVA_OPTS} -Djavax.net.ssl.trustStorePassword=${ARKCASE_TRUSTSTORE_PASSWORD}"
JAVA_OPTS="${JAVA_OPTS} -Dspring.profiles.active=ldap"
JAVA_OPTS="${JAVA_OPTS} -Dacm.configurationserver.propertyfile=${ARKCASE_HOME}/acm/conf.yml"
JAVA_OPTS="${JAVA_OPTS} -Xms1024M -Xmx1024M"
export JAVA_OPTS

export NODE_ENV=development

CATALINA_OPTS="${CATALINA_OPTS:-} -Djava.library.path=${TOMCAT_NATIVE_LIB}"
export CATALINA_OPTS

export CATALINA_PID="${CATALINA_HOME:?set CATALINA_HOME to your Tomcat installation directory}/temp/catalina.pid"
```

Supply the two passwords and the native-library directory to the account that starts Tomcat — from a secret manager, a systemd unit's `EnvironmentFile`, or your container orchestrator — and do **not** write literal values into this file.  There is no default and no shared password: a missing one stops the script with the message above rather than letting Tomcat start in a state where TLS is misconfigured.  One property of this arrangement is worth stating rather than leaving to be discovered — the JVM receives both passwords as system properties, so they are visible in the process table to anyone who can list processes on the host.  That is how ArkCase reads them and it is not changed here; treat the host accordingly and rotate the values as you would any other deployment credential.

Every path above resolves from `${HOME}`, and each of the three required variables is named in the message that reports it missing, so a first-time setup is diagnosable from the failure alone.  Checked with `sh -n` and `bash -n`.

This launch configuration deliberately contains no argument that opens or exports an encapsulated JDK package, and Java 17 needs none: nothing above relies on JDK internal access. That is why the table of applied exceptions in [JDK Access Exceptions](migration/add-opens-exceptions.md) is **empty** -- and that page records the five strong-encapsulation failures the migration measured, so the emptiness is not mistaken for an absence of the problem. **Two were in test libraries** (the mocking framework's class proxy factory, and the reflection helper of the framework removed outright) and **three were in production dependencies**: decision-table rule compilation, JSON deserialisation of `java.time` values, and the LDAP context source's internal JNDI factory constant. Each was removed at its source by advancing or removing the library that needed it, never by opening a JDK module to the application, so none became an applied exception. ArkCase's own reflective code only ever targets ArkCase classes, and ArkCase installs no `SecurityManager`.

`NODE_ENV=development` explicitly selects the non-production branch of the front-end build that Tomcat runs at startup: `Gruntfile.js` tests only for the exact value `production` when it decides which asset lists to render into `home.html`, so every other value — including an unset variable — follows the same development branch. The export is therefore documentation of the intended branch rather than a strict requirement, and it is kept for that reason. That build now installs its dependencies with `npm ci` on Node 20.

No MacOS X-specific edit is required.  The script above resolves every path from the shell's own `${HOME}`, so it works unchanged wherever the account's home directory is; an earlier revision of this file instructed the reader to substitute a literal path for a `${user.home}` token, which was never a shell expansion and would have expanded to nothing.

### Start and Stop Tomcat

```bash
$TOMCAT_HOME/bin/startup.sh
$TOMCAT_HOME/bin/shutdown.sh -force
```

## Deploy the ArkCase WAR

Copy `acm-standard-applications/arkcase/target/arkcase-<version>.war` to `$TOMCAT_HOME/webapps/arkcase.war` and watch `$TOMCAT_HOME/logs/catalina.out`. The first startup takes 5 to 10 minutes. If startup fails or `https://arkcase-ce.local/arkcase` returns 404, raise a GitHub issue.

## Trust the Self-Signed Certificate

When you first open <https://arkcase-ce.local/arkcase> your browser will warn about the self-signed certificate authority. Follow the procedure for your operating system to trust it.

## Log In to ArkCase

Once the login page loads, sign in with the default administrator account:

- User: `arkcase-admin@arkcase.org`
- Password: `<REDACTED>` (see the upstream README for the development default)

> Security note: the default administrator password is intended only for local developer evaluation. In any shared, staging, or production deployment, rotate this credential immediately and inject credentials through environment variables, Spring Cloud Config encrypted values, or a secret manager — never commit them to source control.

## IDE Integration

ArkCase is a standard Maven project, so you can import it into any IDE that understands Maven. ArkCase developers have used IntelliJ IDEA and Eclipse. Visual Studio Code works as a code editor, but you must deploy the WAR manually as described above — VS Code does not currently deploy ArkCase from within itself.
