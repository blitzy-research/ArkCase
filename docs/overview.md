# Module Overview

ArkCase is a multi-module Maven project. Each top-level directory in the repository groups related modules. Every module compiles at Java 17, and the frontend build toolchain runs on Node 20 LTS; see [Developer Setup](setup.md) for the full prerequisite list.

| Module | Description |
| --- | --- |
| `acm-core-api` | Core API definitions and interfaces shared across ArkCase modules — the foundational contract layer the rest of the platform builds against. |
| `acm-forms` | Form definitions, templates, and bindings used by ArkCase to render case and entity forms in the UI. |
| `acm-jmeter` | Apache JMeter test plans and supporting assets for load and performance testing of ArkCase services. |
| `acm-plugins` | Pluggable business modules (cases, complaints, tasks, documents, etc.) that extend the ArkCase core with domain-specific behaviour. |
| `acm-services` | Cross-cutting backend services used by the platform. Includes the **pipeline service**, which supports behaviour extensibility through the pipeline design pattern: pre- and post-entity-save handlers expose `execute()` and `rollback()` methods, are registered in order with the `PipelineManager`, and roll back in reverse order on failure. |
| `acm-standard-applications` | Top-level application assemblies, including the `arkcase` application that produces the deployable WAR file. |
| `acm-tool-integrations` | Adapters and utilities that bridge ArkCase to external tooling. Includes **`acm-pdf-utilities`** — PDF creation via Apache FOP (XSL-FO) and manipulation via Apache PDFBox — and **`acm-proxy-http`**, an HTTP proxy used to safely expose IFRAME-embedded services (Pentaho reports, Snowbound document viewer, etc.) without directly exposing them to the outside world. |
| `acm-user-interface` | Front-end resources, AngularJS modules, and UI configuration that make up the ArkCase web client. |
| `acm-web` | Web layer wiring — controllers, REST endpoints, and servlet configuration that surface ArkCase services over HTTP. |
| `arkcase-lib` | Shared library code reused across other ArkCase modules. |
