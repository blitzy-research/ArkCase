# ArkCase

ArkCase aims to be the leading open source case management and IT modernization platform. After supporting numerous case management and IT modernization initiatives, the team at Armedia developed a framework to accelerate these initiatives and to reduce the cost of implementation. That framework matured and is the basis for ArkCase. The platform continues to evolve as a premier foundation for IT modernization, and as a thank you to customers and the wider open source community, ArkCase is now open source.

## What is ArkCase?

ArkCase is a case management platform built on top of mature open source services. A typical deployment integrates ArkCase with Solr (search), ActiveMQ (messaging), MySQL (relational store), Alfresco (content repository), and Pentaho (reporting). The codebase is a multi-module Maven project organized around a core API, pluggable services, tool integrations, and a web user interface. It builds and runs on Java 17 with a Node 20 LTS frontend build toolchain.

## Before you deploy — one precondition lives outside this repository

ArkCase loads the `spring-security-config-*.xml` files from your `${HOME}/.arkcase` configuration folder into the same Spring context as its own security configuration. Since the move to **Spring Security 5.8**, that framework's namespace handler refuses any document declaring an older security schema than the one on the classpath, and the [`ArkCase/.arkcase`](https://github.com/ArkCase/.arkcase) repository still ships **eight** such files declaring `spring-security-5.4.xsd`.

Deploying against an unmodified configuration folder therefore fails during context initialisation with `BeanDefinitionParsingException: … You cannot use a spring-security-2.0.xsd or … schema with Spring Security 5.8`, after which **every request returns HTTP 404** — a failure that reads like a broken build and is not one. The condition, the exact remedy and the command that verifies it are on the [Developer Setup](setup.md#deployment-precondition-the-configuration-folders-security-schema-declarations-must-be-updated-for-spring-security-58) page and in `README.md`; the reasoning, and the evidence that the rejection comes from the framework's own version gate rather than from a missing schema, are in the [Dependency Change Inventory](migration/dependency-change-inventory.md). Satisfy it once per configuration folder before starting Tomcat.

## Learn More

- Project website: <https://www.arkcase.com>
- Architecture reference: <https://www.arkcase.com/developer-support/architecture/>
- Pre-built evaluation VM: <https://github.com/ArkCase/arkcase-ce>
- Java 17 / Node 20 migration notes: [Dependency Change Inventory](migration/dependency-change-inventory.md)

If you simply want to try ArkCase out, you can download a pre-built virtual machine from the `arkcase-ce` repository above and skip the developer setup. If you intend to build and run ArkCase from source, continue to the [Developer Setup](setup.md) page.
