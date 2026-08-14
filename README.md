# ArkCase

ArkCase aims to be the leading open source case management and IT modernization platform. After supporting numerous case management and IT modernization initiatives, the team at Armedia developed a framework to accelerate these initiatives and to reduce the cost of implementation.  That framework matured and is the basis for ArkCase.  We have and will continue to invest in making ArkCase a premier platform for IT modernization.  As a thank you to our customers who embarked on this journey with us and a thank you to all the software engineers that have contributed open source technologies to advance this industry, ArkCase is now open source!

## Architecture

The ArkCase architecture is described here: https://www.arkcase.com/developer-support/architecture/.  

You can visit https://www.arkcase.com for more information on ArkCase in general.

## Run ArkCase in a Standalone VM

To evaluate ArkCase, or try it out, or just see how it works; in short, to run ArkCase in a VM without having to install all the developer tools, just follow the directions here: https://github.com/ArkCase/arkcase-ce#if-you-just-want-to-download-a-pre-built-arkcase-virtual-machine-and-run-arkcase

And you can skip the Developer Setup section below.

## Developer Setup

This section documents how developers can build and run ArkCase.  (For non-developers, and anyone who just wants to run ArkCase, please read the above section; you don't need to follow the rest of this wiki).

### Prerequisites

* at least 16 GB RAM
* at least 50 GB disk space (the Vagrant VM is 11G)
* Java 17 (LTS). A mainstream OpenJDK 17 build such as Eclipse Temurin works well.
* Maven 3.8+ <https://maven.apache.org> (the build requires a Maven release that runs on JDK 17)
* VirtualBox <https://www.virtualbox.org>
* Vagrant <https://www.vagrantup.com>
* Tomcat 9 <https://tomcat.apache.org>
* git <https://git-scm.com/>. The frontend install needs it: every GitHub dependency in the committed `package-lock.json` is recorded as a `git+ssh` URL, so `npm ci --ignore-scripts` — and `npm install --ignore-scripts` when the lockfile is regenerated — needs git on the path together with either SSH access to github.com or these two rewrites, which is how the build hosts are configured:

    ```bash
    git config --global --add url."https://github.com/".insteadOf git+ssh://git@github.com/
    git config --global --add url."https://github.com/".insteadOf ssh://git@github.com/
    ```

    `insteadOf` is a multi-valued key and a plain `git config <key> <value>` replaces rather than appends, so `--add` is required on both: without it the second command discards the first rule and only `ssh://` URLs get rewritten.
* Node.js 20 LTS <https://nodejs.org>. The frontend declares `engines` of `node >=20.19.0 <21` and `npm >=10`, and enforces it: the project `.npmrc` sets `engine-strict=true`, so on a runtime outside that range npm **refuses** the install with `EBADENGINE` and a non-zero exit rather than warning and carrying on. The same rule applies to the deploy-time install, which runs `npm ci --ignore-scripts --engine-strict`. That is deliberate — a bundle built on a superseded runtime is the outcome this migration exists to prevent — so use Node 20 rather than working around the refusal.
* npm 10 (comes with Node 20).  Install the frontend with `npm ci --ignore-scripts`; `--ignore-scripts` is not optional, because npm runs `prepare` for git dependencies and one of the locked asset repositories tries to build an ancient native module there that cannot compile on Node 20.  This is the install form the deployed application runs, as `npm ci --ignore-scripts --engine-strict`.

### Build the Vagrant VM

In this section you will build the Vagrant VM which will run the services ArkCase requires.  These services include Solr, ActiveMQ, MySQL, Alfresco, and Pentaho. 

First, install all the prerequisites (see Prerequisites section above).

Next, build the Vagrant VM according to the instructions in the `arkcase-ce` repository: <https://github.com/ArkCase/arkcase-ce>.

After the box is up, the following URLs should work from your browser; be aware that ArkCase uses a self-signed TLS certificate, so you will have to accept the browser warning about the unrecognized, self-signed certificate. 

https://arkcase-ce.local/solr

https://arkcase-ce.local/share

https://arkcase-ce.local/pentaho

https://arkcase-ce.local/VirtualViewerJavaHTML5 (expect a 503 error from this URL)

### Clone the repository and build the war file

Clone this repository to a folder of your choice.

`cd` to the root folder of this repository; then run `mvn -DskipITs clean install`.  This will run the unit tests and build the war file.  It should take a few minutes.

### Clone the configuration folder

ArkCase requires a configuration folder which is housed in another GitHub repository: https://github.com/ArkCase/.arkcase; follow the instructions at this link to setup the configuration folder.

### Run the Configuration Server

Starting with version 3.3.1, ArkCase requires a separate configuration server, based on Spring Cloud Config Server (more info here: https://spring.io/projects/spring-cloud-config).  To start the config server, take these steps:

* Download the most recent config-server.jar file from here: https://github.com/ArkCase/acm-config-server/releases
* Start the server process with this command: `java -jar config-server-0.0.1.jar`, replacing `0.0.1` with the version you downloaded.

The config server runs on port 9999 by default.  To run on a different port, add the server.port option to the command, like so: `java -Dserver.port=8888 -jar config-server-0.0.1.jar`, replacing `8888` with the desired port.

### Configure Tomcat

#### Tomcat Native Connector

Make sure the Tomcat native connector library is being used.  

* MacOS: open terminal, issue the command `brew install tomcat-native`, and follow any directions you see at the end... Of course you must already have `brew`; see <https://brew.sh/> if you don't already have it.
* Windows: download from https://tomcat.apache.org/download-native.cgi. 
* Linux: Information on building for Linux is available from the same URL (https://tomcat.apache.org/download-native.cgi).

#### Tomcat TLS Configuration

In your Tomcat 9 installation, edit the `conf/server.xml` file, and add the following connector, below the existing connector for port 8080:

```xml
    <Connector port="8843"
           maxThreads="150" SSLEnabled="true" secure="true" scheme="https"
           maxHttpHeaderSize="32768"
           connectionTimeout="40000"
           useBodyEncodingForURI="true"
           address="0.0.0.0">
      <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol" />
      <SSLHostConfig protocols="TLSv1.2" certificateVerification="none">
        <Certificate certificateFile="${user.home}/.arkcase/acm/private/acm-arkcase.crt"
                    certificateKeyFile="${user.home}/.arkcase/acm/private/acm-arkcase.rsa.pem"
                    certificateChainFile="${user.home}/.arkcase/acm/private/arkcase-ca.crt"
                    type="RSA" />
      </SSLHostConfig>
    </Connector>
```

Also, search for the text `Listener className="org.apache.catalina.core.AprLifecycleListener"`, and make sure to add the `useAprConnector="true"` attribute, so it ends like this:

```xml
<Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" useAprConnector="true"/>
``` 

#### Tomcat setenv.sh file

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

On MacOS X, you have to replace `file:${user.home}` in the above script, with the actual full path to your home folder.

**Module-access flags on Java 17.** Leave `JAVA_OPTS` exactly as it is above. ArkCase's launch configuration grants no module access: add no `--add-opens`, no `--add-exports` and no `--illegal-access`, exactly as at the Java 8 base commit.

One measured observation belongs beside that, because it is a deployment fact rather than a policy: ArkCase's start-up reflects into `java.base/java.lang`. Two pinned dependencies do it while the application compiles its business rules during context initialisation — Drools 7.34.0.Final, whose `ClassGenerator` calls `setAccessible` on `ClassLoader.defineClass`, and Groovy 1.8.6, reached through AWS SDK 1.11.775, which calls `setAccessible` on `Object.finalize()`. On Tomcat 9 nothing has to be done about it: Tomcat's own `bin/catalina.sh` exports seven `--add-opens` through `JDK_JAVA_OPTIONS` before the JVM starts — including `java.base/java.lang`, alongside `java.lang.invoke`, `java.lang.reflect`, `java.io`, `java.util`, `java.util.concurrent` and `java.rmi/sun.rmi.transport` — which is why this file needs no flag. Started through a launcher that omits them, the `/arkcase` context fails to initialise with `InaccessibleObjectException` and every path returns 404.

That is recorded as an unreconciled observation rather than as a grant: opening `java.base/java.lang` to `ALL-UNNAMED` exposes the JDK's most sensitive package to every library on the classpath, not only the two that ask for it, and retiring the demand means moving off Drools and the Groovy it carries — a behaviour change this migration does not make. The measurement, both demanding dependencies with their stack frames, the two-run experiment behind it and the options a human can ratify are in the [module-access exceptions record](docs/migration/add-opens-exceptions.md). Do not copy the Maven test runners' directives into a server: those are confined to forked test JVMs and are configured in the root `pom.xml`.

#### Start Tomcat

Now you should be able to start Tomcat: `$TOMCAT_HOME/bin/startup.sh`.  

To shutdown Tomcat: `$TOMCAT_HOME/bin/shutdown.sh -force`.

### Deploy the ArkCase war file

The result of the command `mvn -DskipITs clean install` (described above) is the war file `acm-standard-applications/arkcase/target/arkcase-(version).war`, where `(version)` is the Maven version string.

Copy this file to `$TOMCAT_HOME`, rename it to `arkcase.war`, and move the `arkcase.war` to `$TOMCAT_HOME/webapps`.  Then, watch the Tomcat log file (`$TOMCAT_HOME/logs/catalina.out`).  The first startup will take 5 - 10 minutes. 

If you see any errors that prevent application startup (in other words: if after Tomcat has started, you get a 404 error from `https://arkcase-ce.local/arkcase`, raise a GitHub issue in this repository.

#### Upgrading: the front-end install property was renamed

The deploy-time front-end assembler no longer runs yarn, so the Spring property that carries its install command was renamed with it: **`yarnInstallCommand` is now `npmInstallCommand`** on `com.armedia.acm.userinterface.angular.AngularResourceCopier`. No alias is kept under the old name, because no yarn-named setter may survive the migration.

This only affects a deployment that sets the property itself — an out-of-repo extension jar, or an external Spring XML overriding the `angularResourceCopier` bean. Such a definition fails at context refresh with `NotWritablePropertyException: Invalid property 'yarnInstallCommand'`, and the `/arkcase` context does not start. Rename the property in that definition and give it an npm command; the value ArkCase itself ships is `npm ci --ignore-scripts --engine-strict`. A deployment that does not set the property needs no change.

### Trusting the self-signed ArkCase certificate

Once you see that Tomcat has started successfully, you should be able to open `https://arkcase-ce.local/arkcase` in your browser.

When you open ArkCase in your browser, you will have to trust the self-signed cert.  The cert is signed by a self-signed ArkCase certificate authority.  Follow the right procedure for your operating system to trust this certificate.

MacOS: A good guide is here, https://www.accuweaver.com/2014/09/19/make-chrome-accept-a-self-signed-certificate-on-osx/

### Logging into ArkCase

Once you see the ArkCase login page, you can log in with the default administrator account.  User `arkcase-admin@arkcase.org`, password `@rKc@3e`.

### IDE Integration

ArkCase is a Maven project with a standard Maven folder layout.  You can load it into your chosen IDE or editor in whichever way is supported by your editor; if your IDE supports starting and launching a war file, this should work in the normal way.  Detailed steps to configure IDE integration is beyond the scope of this guide.

ArkCase developers have used IntelliJ IDEA and Eclipse.  Visual Studio Code is usable as a code editor, but you have to deploy ArkCase manually as described above; so far VS Code seems unable to deploy ArkCase from within itself.
