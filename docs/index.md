# ArkCase

ArkCase aims to be the leading open source case management and IT modernization platform. After supporting numerous case management and IT modernization initiatives, the team at Armedia developed a framework to accelerate these initiatives and to reduce the cost of implementation. That framework matured and is the basis for ArkCase. The platform continues to evolve as a premier foundation for IT modernization, and as a thank you to customers and the wider open source community, ArkCase is now open source.

## What is ArkCase?

ArkCase is a case management platform built on top of mature open source services. A typical deployment integrates ArkCase with Solr (search), ActiveMQ (messaging), MySQL (relational store), Alfresco (content repository), and Pentaho (reporting). The codebase is a multi-module Maven project organized around a core API, pluggable services, tool integrations, and a web user interface. It builds and runs on Java 17 with a Node 20 LTS frontend build toolchain.

## Learn More

- Project website: <https://www.arkcase.com>
- Architecture reference: <https://www.arkcase.com/developer-support/architecture/>
- Pre-built evaluation VM: <https://github.com/ArkCase/arkcase-ce>
- Java 17 / Node 20 migration notes: [Dependency Change Inventory](migration/dependency-change-inventory.md)

If you simply want to try ArkCase out, you can download a pre-built virtual machine from the `arkcase-ce` repository above and skip the developer setup. If you intend to build and run ArkCase from source, continue to the [Developer Setup](setup.md) page.
