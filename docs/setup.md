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

This block is a duplicate of the one in the upstream README, and the README is the authoritative copy. It is reproduced verbatim so the two cannot drift; the Java 17 migration changed only the paragraph that follows it, and deliberately left the command itself exactly as the README states it, including its pre-existing formatting and quoting. Pre-existing defects in it are registered in the migration notes rather than corrected here.

Create the file `bin/setenv.sh`, mark it executable, and set the contents as the following, *being careful to set the correct path to the Tomcat native library*:

```bash
#!/bin/sh

### MacOS X note: replace {user.home} with the actual path to your home folder, e.g. /Users/dmiller
export JAVA_OPTS="-Djava.net.preferIPv4Stack=true -Duser.timezone=GMT  -Djavax.net.ssl.keyStorePassword=password -Djavax.net.ssl.trustStorePassword=password -Djavax.net.ssl.keyStore=${user.home}/.arkcase/acm/private/arkcase.ks -Djavax.net.ssl.trustStore=${user.home}/.arkcase/acm/private/arkcase.ts -Dspring.profiles.active=ldap -Dacm.configurationserver.propertyfile="${user.home}/.arkcase/acm/conf.yml -Xms1024M -Xmx1024M"

export NODE_ENV=development

export CATALINA_OPTS="$CATALINA_OPTS -Djava.library.path=(PATH TO THE TOMCAT NATIVE LIBRARY)
# MacOS Example: export CATALINA_OPTS=/usr/local/opt/tomcat-native/lib"

export CATALINA_PID=$CATALINA_HOME/temp/catalina.pid
```

This launch configuration deliberately contains no argument that opens or exports an encapsulated JDK package, and Java 17 needs none: nothing above relies on JDK internal access. That is why the register of applied exceptions in [JDK Access Exceptions](migration/add-opens-exceptions.md) is empty. That page also records the two production requirements for such access that were measured during the migration -- rule compilation and JSON deserialisation of `java.time` values -- and how each was removed at its source by advancing the library that needed it, so the register's emptiness is not mistaken for an absence of the problem. Every strong encapsulation failure found during the Java 17 migration was inside a test library and was resolved by upgrading or removing that library rather than by opening a JDK module to the application; ArkCase's own reflective code only ever targets ArkCase classes, and ArkCase installs no `SecurityManager`.

`NODE_ENV=development` explicitly selects the non-production branch of the front-end build that Tomcat runs at startup: `Gruntfile.js` tests only for the exact value `production` when it decides which asset lists to render into `home.html`, so every other value — including an unset variable — follows the same development branch. The export is therefore documentation of the intended branch rather than a strict requirement, and it is kept for that reason. That build now installs its dependencies with `npm ci` on Node 20.

On MacOS X, you have to replace `file:${user.home}` in the above script, with the actual full path to your home folder.

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
