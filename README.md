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
* git <https://git-scm.com/>. Regenerating the frontend lockfile with `npm install --ignore-scripts` needs git; installing from the committed lockfile with `npm ci --ignore-scripts` needs none at all, only outbound HTTPS to registry.npmjs.org and codeload.github.com. Both commands carry `--ignore-scripts` deliberately, and it is not optional: npm runs `prepare` for git dependencies, and one of the locked asset repositories tries to build an ancient native module there that cannot compile on Node 20. This is the install form the migration proved and the one the deployed application runs.
* Node.js 20 LTS <https://nodejs.org>. The frontend declares `engines` of `node >=20.19.0 <21` and `npm >=10`; npm reports an `EBADENGINE` warning on a runtime outside that range and continues, so run the frontend build on Node 20.
* npm 10 (comes with Node 20)

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

### ${HOME} is expanded by the shell, so this works as written on Linux and on MacOS X alike.
### The two key-store passwords are read from the environment and never written into this file.
### Supply them from your shell profile, your process manager or a secret manager; the ':?' makes
### the shell refuse to start Tomcat with either one unset instead of failing later in the handshake.
export JAVA_OPTS="-Djava.net.preferIPv4Stack=true -Duser.timezone=GMT -Djavax.net.ssl.keyStorePassword=${ARKCASE_KEYSTORE_PASSWORD:?ARKCASE_KEYSTORE_PASSWORD must be set} -Djavax.net.ssl.trustStorePassword=${ARKCASE_TRUSTSTORE_PASSWORD:?ARKCASE_TRUSTSTORE_PASSWORD must be set} -Djavax.net.ssl.keyStore=${HOME}/.arkcase/acm/private/arkcase.ks -Djavax.net.ssl.trustStore=${HOME}/.arkcase/acm/private/arkcase.ts -Dspring.profiles.active=ldap -Dacm.configurationserver.propertyfile=${HOME}/.arkcase/acm/conf.yml -Xms1024M -Xmx1024M"

export NODE_ENV=development

export CATALINA_OPTS="$CATALINA_OPTS -Djava.library.path=(PATH TO THE TOMCAT NATIVE LIBRARY)
# MacOS Example: export CATALINA_OPTS=/usr/local/opt/tomcat-native/lib"

export CATALINA_PID=$CATALINA_HOME/temp/catalina.pid
```

Replace `PATH_TO_THE_TOMCAT_NATIVE_LIBRARY` with the directory holding your Tomcat native library, and export the two credentials before starting Tomcat:

* `ARKCASE_KEYSTORE_PASSWORD` — the password of `${HOME}/.arkcase/acm/private/arkcase.ks`, chosen when that key store was created by the `arkcase-ce` provisioning you ran above.
* `ARKCASE_TRUSTSTORE_PASSWORD` — the password of `${HOME}/.arkcase/acm/private/arkcase.ts`, chosen the same way.

Everything else in the script above runs as written, since `${HOME}` is expanded by the shell.  The `${user.home}` references in the `server.xml` connector snippet earlier in this section are different: Tomcat expands those itself, so leave them as they are.  Do not commit either password to source control, and rotate both — along with any default they were provisioned with — before a deployment is reachable by anyone but you.

**Module-access flags on Java 17.**  Leave `JAVA_OPTS` exactly as it is above: on Tomcat 9 nothing needs to be added, because Tomcat's own `bin/catalina.sh` exports `--add-opens=java.base/java.lang=ALL-UNNAMED` (among others) before the JVM starts, and that is the one open ArkCase genuinely requires — two pinned libraries, Drools and Groovy, reflect into `java.lang` while the application compiles its business rules during startup.  This was measured rather than assumed: with Tomcat's flags in place the application starts and login succeeds, and with them removed the root Spring context fails with `InaccessibleObjectException` and every request returns 404.  If you launch ArkCase with anything other than Tomcat's own script, add `--add-opens=java.base/java.lang=ALL-UNNAMED` yourself and nothing else.  Do not add `--add-exports` or `--illegal-access`, and do not copy the Maven test runners' directives into a server: those are confined to forked test JVMs, are configured in the root `pom.xml`, and their per-library attribution — together with the runtime exception above — is recorded in the [module-access exceptions record](docs/migration/add-opens-exceptions.md).

#### Start Tomcat

Now you should be able to start Tomcat: `$TOMCAT_HOME/bin/startup.sh`.  

To shutdown Tomcat: `$TOMCAT_HOME/bin/shutdown.sh -force`.

### Deploy the ArkCase war file

The result of the command `mvn -DskipITs clean install` (described above) is the war file `acm-standard-applications/arkcase/target/arkcase-(version).war`, where `(version)` is the Maven version string.

Copy this file to `$TOMCAT_HOME`, rename it to `arkcase.war`, and move the `arkcase.war` to `$TOMCAT_HOME/webapps`.  Then, watch the Tomcat log file (`$TOMCAT_HOME/logs/catalina.out`).  The first startup will take 5 - 10 minutes. 

If you see any errors that prevent application startup (in other words: if after Tomcat has started, you get a 404 error from `https://arkcase-ce.local/arkcase`, raise a GitHub issue in this repository.

### Trusting the self-signed ArkCase certificate

Once you see that Tomcat has started successfully, you should be able to open `https://arkcase-ce.local/arkcase` in your browser.

When you open ArkCase in your browser, you will have to trust the self-signed cert.  The cert is signed by a self-signed ArkCase certificate authority.  Follow the right procedure for your operating system to trust this certificate.

MacOS: A good guide is here, https://www.accuweaver.com/2014/09/19/make-chrome-accept-a-self-signed-certificate-on-osx/

### Logging into ArkCase

Once you see the ArkCase login page, you can log in with the administrator account `arkcase-admin@arkcase.org`.  Its password is the one your directory provisioning set for that account — for a Vagrant VM built from the `arkcase-ce` repository, the value that repository's own provisioning assigns; for any other deployment, whatever your identity provider holds.  No password is published here, and none should be committed to source control: rotate the provisioned default before the deployment is reachable by anyone but you, and keep the working value in a secret manager or in an environment variable that only the deploying account can read.

### IDE Integration

ArkCase is a Maven project with a standard Maven folder layout.  You can load it into your chosen IDE or editor in whichever way is supported by your editor; if your IDE supports starting and launching a war file, this should work in the normal way.  Detailed steps to configure IDE integration is beyond the scope of this guide.

ArkCase developers have used IntelliJ IDEA and Eclipse.  Visual Studio Code is usable as a code editor, but you have to deploy ArkCase manually as described above; so far VS Code seems unable to deploy ArkCase from within itself.
