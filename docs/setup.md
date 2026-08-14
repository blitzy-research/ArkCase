# Developer Setup

This page documents how developers can build and run ArkCase from source. If you only want to evaluate ArkCase, use the pre-built VM described on the [home page](index.md) instead.

## Prerequisites

- At least 16 GB RAM
- At least 50 GB disk space (the Vagrant VM is roughly 11 GB)
- Java 17 (LTS). A mainstream OpenJDK 17 build such as Eclipse Temurin works well.
- Maven 3.8+ <https://maven.apache.org> (the build requires a Maven release that runs on JDK 17)
- VirtualBox <https://www.virtualbox.org>
- Vagrant <https://www.vagrantup.com>
- Tomcat 9 <https://tomcat.apache.org>
- git <https://git-scm.com/>. The frontend install needs it: every GitHub dependency in the committed `package-lock.json` is recorded as a `git+ssh` URL, so `npm ci --ignore-scripts` — and `npm install --ignore-scripts` when the lockfile is regenerated — needs git on the path together with either SSH access to github.com or these two rewrites, which is how the build hosts are configured:

    ```bash
    git config --global --add url."https://github.com/".insteadOf git+ssh://git@github.com/
    git config --global --add url."https://github.com/".insteadOf ssh://git@github.com/
    ```

    `insteadOf` is a multi-valued key and a plain `git config <key> <value>` replaces rather than appends, so `--add` is required on both: without it the second command discards the first rule and only `ssh://` URLs get rewritten.
- Node.js 20 LTS <https://nodejs.org>. The frontend declares `engines` of `node >=20.19.0 <21` and `npm >=10`, and enforces it: the project `.npmrc` sets `engine-strict=true`, so on a runtime outside that range npm **refuses** the install with `EBADENGINE` and a non-zero exit rather than warning and carrying on. The same rule applies to the deploy-time install, which runs `npm ci --ignore-scripts --engine-strict`. That is deliberate — a bundle built on a superseded runtime is the outcome this migration exists to prevent — so use Node 20 rather than working around the refusal.
- npm 10 (comes with Node 20). Install the frontend with `npm ci --ignore-scripts`; `--ignore-scripts` is not optional, because npm runs `prepare` for git dependencies and one of the locked asset repositories tries to build an ancient native module there that cannot compile on Node 20. This is the install form the deployed application runs, as `npm ci --ignore-scripts --engine-strict`.

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

## Configuration Folder

ArkCase requires a configuration folder which lives in another GitHub repository: <https://github.com/ArkCase/.arkcase>. Follow the instructions at that link to set up the configuration folder.

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

Create `bin/setenv.sh`, mark it executable, and set environment variables for `JAVA_OPTS`, `NODE_ENV`, and `CATALINA_OPTS`. **Do not check real keystore or trust-store passwords into source control — set them through environment variables or a secret manager in any non-local environment.**

```bash
#!/bin/sh

# macOS: replace ${user.home} with the actual path to your home folder.
export JAVA_OPTS="-Djava.net.preferIPv4Stack=true \
  -Duser.timezone=GMT \
  -Djavax.net.ssl.keyStorePassword=<REDACTED> \
  -Djavax.net.ssl.trustStorePassword=<REDACTED> \
  -Djavax.net.ssl.keyStore=${user.home}/.arkcase/acm/private/arkcase.ks \
  -Djavax.net.ssl.trustStore=${user.home}/.arkcase/acm/private/arkcase.ts \
  -Dspring.profiles.active=ldap \
  -Dacm.configurationserver.propertyfile=${user.home}/.arkcase/acm/conf.yml \
  -Xms1024M -Xmx1024M"

export NODE_ENV=development
export CATALINA_OPTS="$CATALINA_OPTS -Djava.library.path=(PATH TO THE TOMCAT NATIVE LIBRARY)"
export CATALINA_PID=$CATALINA_HOME/temp/catalina.pid
```

**Module-access flags on Java 17.** Leave `JAVA_OPTS` exactly as it is above. ArkCase's launch configuration grants no module access: add no `--add-opens`, no `--add-exports` and no `--illegal-access`, exactly as at the Java 8 base commit.

One measured observation belongs beside that, because it is a deployment fact rather than a policy: ArkCase's start-up reflects into `java.base/java.lang`. Two pinned dependencies do it while the application compiles its business rules during context initialisation — Drools 7.34.0.Final, whose `ClassGenerator` calls `setAccessible` on `ClassLoader.defineClass`, and Groovy 1.8.6, reached through AWS SDK 1.11.775, which calls `setAccessible` on `Object.finalize()`. On Tomcat 9 nothing has to be done about it: Tomcat's own `bin/catalina.sh` exports seven `--add-opens` through `JDK_JAVA_OPTIONS` before the JVM starts — including `java.base/java.lang`, alongside `java.lang.invoke`, `java.lang.reflect`, `java.io`, `java.util`, `java.util.concurrent` and `java.rmi/sun.rmi.transport` — which is why this file needs no flag. Started through a launcher that omits them, the `/arkcase` context fails to initialise with `InaccessibleObjectException` and every path returns 404.

That is recorded as an unreconciled observation rather than as a grant: opening `java.base/java.lang` to `ALL-UNNAMED` exposes the JDK's most sensitive package to every library on the classpath, not only the two that ask for it, and retiring the demand means moving off Drools and the Groovy it carries — a behaviour change this migration does not make. The measurement, both demanding dependencies with their stack frames, the two-run experiment behind it and the options a human can ratify are in the [module-access exceptions record](migration/add-opens-exceptions.md). Do not copy the Maven test runners' directives into a server: those are confined to forked test JVMs and are configured in the root `pom.xml`.

### Start and Stop Tomcat

```bash
$TOMCAT_HOME/bin/startup.sh
$TOMCAT_HOME/bin/shutdown.sh -force
```

## Deploy the ArkCase WAR

Copy `acm-standard-applications/arkcase/target/arkcase-<version>.war` to `$TOMCAT_HOME/webapps/arkcase.war` and watch `$TOMCAT_HOME/logs/catalina.out`. The first startup takes 5 to 10 minutes. If startup fails or `https://arkcase-ce.local/arkcase` returns 404, raise a GitHub issue.

### Upgrading: the front-end install property was renamed

The deploy-time front-end assembler no longer runs yarn, so the Spring property that carries its install command was renamed with it: **`yarnInstallCommand` is now `npmInstallCommand`** on `com.armedia.acm.userinterface.angular.AngularResourceCopier`. No alias is kept under the old name, because no yarn-named setter may survive the migration.

This only affects a deployment that sets the property itself — an out-of-repo extension jar, or an external Spring XML overriding the `angularResourceCopier` bean. Such a definition fails at context refresh with `NotWritablePropertyException: Invalid property 'yarnInstallCommand'`, and the `/arkcase` context does not start. Rename the property in that definition and give it an npm command; the value ArkCase itself ships is `npm ci --ignore-scripts --engine-strict`. A deployment that does not set the property needs no change.

## Trust the Self-Signed Certificate

When you first open <https://arkcase-ce.local/arkcase> your browser will warn about the self-signed certificate authority. Follow the procedure for your operating system to trust it.

## Log In to ArkCase

Once the login page loads, sign in with the default administrator account:

- User: `arkcase-admin@arkcase.org`
- Password: `<REDACTED>` (see the upstream README for the development default)

> Security note: the default administrator password is intended only for local developer evaluation. In any shared, staging, or production deployment, rotate this credential immediately and inject credentials through environment variables, Spring Cloud Config encrypted values, or a secret manager — never commit them to source control.

## IDE Integration

ArkCase is a standard Maven project, so you can import it into any IDE that understands Maven. ArkCase developers have used IntelliJ IDEA and Eclipse. Visual Studio Code works as a code editor, but you must deploy the WAR manually as described above — VS Code does not currently deploy ArkCase from within itself.
