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
* Java 17 (Eclipse Temurin, formerly AdoptOpenJDK, works well).  Java 17 is the required LTS release: the Maven build compiles at `maven.compiler.release=17`, so an earlier JDK can neither build nor run ArkCase.
* Maven 3.8+ <https://maven.apache.org>.  Maven 3.8 and later block artifact resolution over plain HTTP; the build declares only HTTPS remote repositories and local `file://` repositories.
* VirtualBox <https://www.virtualbox.org>
* Vagrant <https://www.vagrantup.com>
* Tomcat 9 <https://tomcat.apache.org>
* git <https://git-scm.com/>
* Node 20 LTS <https://nodejs.org>.  The required version is pinned in `acm-standard-applications/arkcase/src/main/webapp/resources/.nvmrc`, so `nvm use` selects it without an argument.
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

The reactor builds all of its modules in a single JVM, so the class metadata of every module has to coexist in one metaspace.  Do not cap it: a `MAVEN_OPTS` containing `-XX:MaxMetaspaceSize` set below roughly 1 GB aborts the build part-way through with nothing but `[ERROR] Metaspace`, which reads like a module failure rather than a memory ceiling.  `MAVEN_OPTS="-Xmx1400m -Xss512k"` builds the whole reactor; the GitLab pipeline uses `-XX:MetaspaceSize` (an initial size, not a limit) for the same reason.

### Clone the configuration folder

ArkCase requires a configuration folder which is housed in another GitHub repository: https://github.com/ArkCase/.arkcase; follow the instructions at this link to setup the configuration folder.

The build command above skips the integration tests, so it does not need this folder.  `mvn verify` does: the integration-test Spring contexts import `${user.home}/.arkcase/acm/encryption/spring-properties-encryption.xml` and `${user.home}/.arkcase/acm/app-config.xml` directly, read `${user.home}/.arkcase/acm/conf.yml`, and decrypt property values with the key material under `${user.home}/.arkcase/acm/private`.  Without the folder those tests fail during context initialisation with `FileNotFoundException` on a `.arkcase` path, which reads like a code failure and is not one.  Set the folder up, and start the configuration server described below, before drawing conclusions from an integration-test result.

#### DEPLOYMENT PRECONDITION — the configuration folder's security schema declarations must be updated for Spring Security 5.8

`WEB-INF/web.xml` loads `file:${user.home}/.arkcase/acm/spring-security/spring-security-config-*.xml` from the configuration folder into the same root application context as ArkCase's own security configuration.  ArkCase now runs Spring Security 5.8, whose XML namespace handler refuses to parse a document whose `xsi:schemaLocation` names an older security schema than the version on the classpath, so **every one of those files must declare the version-less schema**:

```xml
http://www.springframework.org/schema/security http://www.springframework.org/schema/security/spring-security.xsd
```

The configuration repository currently ships eight of them — `-ldap`, `-oidc`, `-okta`, `-kerberos`, `-saml`, `-external`, `-external-oidc` and `-external-saml` — declaring `spring-security-5.4.xsd`.  Deploying against an unmodified folder therefore fails at startup with

```
org.springframework.beans.factory.parsing.BeanDefinitionParsingException: Configuration problem:
  You cannot use a spring-security-2.0.xsd or ... schema with Spring Security 5.8.
  Please update your schema declarations to the 5.8 schema.
```

and every request returns HTTP 404 because the context never initialises.  Replacing `spring-security-5.4.xsd` with `spring-security.xsd` in those files is a namespace-declaration change only: it alters no `<http>`, `<intercept-url>`, `<form-login>` or method-security semantics.  ArkCase's own three declarations were changed the same way in this repository; the configuration folder lives in a separate repository and has to be updated there.

**This is a precondition of the deployment contract, not a defect in this repository, and it is stated as one so that it is satisfied deliberately rather than discovered at startup.**  The configuration folder is a separate deliverable in a separate repository, versioned and released independently of the application; it is not in this migration's file list and cannot be changed from here.  What this repository owes is that the requirement is unambiguous, that the remedy is exact, and that it is verifiable before a deployment is attempted — which is what the rest of this section provides.  Do this once per configuration folder, before starting Tomcat:

```bash
cd ${HOME}/.arkcase/acm/spring-security
grep -l 'spring-security-5\.4\.xsd' spring-security-config-*.xml     # expect the eight files named above
sed -i 's|spring-security-5\.4\.xsd|spring-security.xsd|g' spring-security-config-*.xml
grep -c 'spring-security-5\.4\.xsd' spring-security-config-*.xml     # every file must now report 0
```

The last command is the gate: while any file still reports a non-zero count the context will not initialise, and every request will return HTTP 404 for the reason quoted above rather than for any reason in the application.  The same change belongs upstream in [`ArkCase/.arkcase`](https://github.com/ArkCase/.arkcase) so that a fresh clone of the configuration folder is deployable without it; until that lands, the four commands above are the whole of the remedy.

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

This launch configuration deliberately contains no argument that opens or exports an encapsulated JDK package, and Java 17 needs none: nothing above relies on JDK internal access, which is why the table of applied exceptions in [`docs/migration/add-opens-exceptions.md`](docs/migration/add-opens-exceptions.md) is **empty**.  The register is empty because the requirement is gone, not because it was never looked for.  Five strong-encapsulation failures were measured during the migration: **two in test libraries** -- the mocking framework's class proxy factory and the reflection helper of the framework that was removed outright -- and **three in production dependencies**: the decision-table engine's ASM consequence-invoker generator reaching for the protected four-argument `ClassLoader.defineClass`, the object mapper calling `setAccessible` on `java.time` fields, and the LDAP context source holding an internal JNDI factory as a class constant in its static initialiser.  Each of the five was removed at its source by advancing or removing the library that needed it, never by opening a JDK module to the application, so none became an applied exception.  ArkCase's own reflective code only ever targets ArkCase classes, and ArkCase installs no `SecurityManager`.

`NODE_ENV=development` explicitly selects the non-production branch of the front-end build that Tomcat runs at startup: `Gruntfile.js` tests only for the exact value `production` when it decides which asset lists to render into `home.html`, so every other value — including an unset variable — follows the same development branch.  The export is therefore documentation of the intended branch rather than a strict requirement, and it is kept for that reason.  That build now installs its dependencies with `npm ci` on Node 20.

On MacOS X, you have to replace `file:${user.home}` in the above script, with the actual full path to your home folder.

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

Once you see the ArkCase login page, you can log in with the default administrator account.  User `arkcase-admin@arkcase.org`, password `@rKc@3e`.

### IDE Integration

ArkCase is a Maven project with a standard Maven folder layout.  You can load it into your chosen IDE or editor in whichever way is supported by your editor; if your IDE supports starting and launching a war file, this should work in the normal way.  Detailed steps to configure IDE integration is beyond the scope of this guide.

ArkCase developers have used IntelliJ IDEA and Eclipse.  Visual Studio Code is usable as a code editor, but you have to deploy ArkCase manually as described above; so far VS Code seems unable to deploy ArkCase from within itself.
