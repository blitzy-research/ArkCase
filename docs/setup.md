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
- git <https://git-scm.com/>. Regenerating the frontend lockfile with `npm install` needs git; installing from the committed lockfile with `npm ci` needs none at all, only outbound HTTPS to registry.npmjs.org and codeload.github.com.
- Node.js 20 LTS <https://nodejs.org>. The frontend declares `engines` of `node >=20.19.0 <21` and `npm >=10`, and its `.npmrc` sets `engine-strict`, so npm refuses to install on a runtime outside that range instead of warning and continuing.
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

# ${HOME} is expanded by the shell, so this works as written on Linux and on macOS alike.
export JAVA_OPTS="-Djava.net.preferIPv4Stack=true \
  -Duser.timezone=GMT \
  -Djavax.net.ssl.keyStorePassword=<REDACTED> \
  -Djavax.net.ssl.trustStorePassword=<REDACTED> \
  -Djavax.net.ssl.keyStore=${HOME}/.arkcase/acm/private/arkcase.ks \
  -Djavax.net.ssl.trustStore=${HOME}/.arkcase/acm/private/arkcase.ts \
  -Dspring.profiles.active=ldap \
  -Dacm.configurationserver.propertyfile=${HOME}/.arkcase/acm/conf.yml \
  -Xms1024M -Xmx1024M"

export NODE_ENV=development
export CATALINA_OPTS="$CATALINA_OPTS -Djava.library.path=PATH_TO_THE_TOMCAT_NATIVE_LIBRARY"
export CATALINA_PID=$CATALINA_HOME/temp/catalina.pid
```

Replace `PATH_TO_THE_TOMCAT_NATIVE_LIBRARY` with the directory holding your Tomcat native library; everything else runs as written, since `${HOME}` is expanded by the shell. The `${user.home}` placeholders in the `server.xml` connector snippet are different — Tomcat expands those itself — so leave them alone.

No additional JVM module-access flags are required to run ArkCase on Java 17; do not add them to production `JAVA_OPTS`. The `JAVA_OPTS` value above runs as written and grants no access to JDK internals. The module-access directives this migration did need are confined to the forked JVMs of the Maven test runners and are configured in the root `pom.xml`; their per-library attribution is deferred to the planned [module-access exceptions record](migration/add-opens-exceptions.md).

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
