# DomainDig v4.4.1 Architecture

## Overview

DomainDig is a local-first inspection and audit app built around one canonical output model: `DomainReport`.

Inspection flow:

1. `LookupRuntime` coordinates the section services that gather DNS, web, TLS, ownership, reachability, redirect, email, port, and enrichment data.
2. `DomainInspectionService` normalizes live and cached results into `LookupSnapshot`.
3. `DomainReportBuilder` converts each snapshot into the canonical `DomainReport`.
4. SwiftUI screens, exports, and the local API render from `DomainReport` or data derived from it.

`LookupSnapshot` remains the internal persistence shape for raw inspection state. `DomainReport` is the stable presentation/export contract.

## App Layers

- Section services: network collection and local normalization only.
- `LookupRuntime`: orchestrates section services for a single inspection.
- `DomainInspectionService`: builds inspection snapshots with provenance, cache state, and failure metadata.
- `DomainReportBuilder`: assembles summaries, insights, risk scoring, workflow context, and report metadata.
- `DomainReportExporter`: renders TXT, CSV, and JSON output for app and local API use.
- `DomainViewModel`: coordinates SwiftUI state, persistence, audit sessions, monitoring, workflows, batch operations, imports, and exports.
- SwiftUI views: render screens and invoke view-model actions.

## Audit Mode

The app has one active Audit Mode implementation:

- Models live in `DomainDig/DomainDig/AuditModels.swift`.
- UI lives in `DomainDig/DomainDig/AuditViews.swift`.
- Export rendering lives in `DomainDig/DomainDig/AuditExporter.swift`.
- Persistence is owned by `DomainViewModel` through `DomainDataPortabilityService`.

An audit session captures:

- Domain and reviewer metadata
- Session status
- Point-in-time `HistoryEntry` and `DomainReport`
- Historical snapshot context
- Evidence asset references
- Checklist progress
- Findings with severity, status, evidence references, notes, and checklist areas
- Reviewer notes

Audit sessions are stored under the same local portability service as the rest of app data and are included in full backup/restore flows.

The older standalone prototype files, `DomainDig/AuditMode.swift` and `DomainDig/AuditModeView.swift`, are preserved in the repository for reference but excluded from synchronized target membership. They are not the release audit path.

## Data Portability

`DomainDataPortabilityService` owns backup, import, validation, lifecycle counts, and merge/replace behavior for:

- Tracked domains
- History snapshots
- Audit sessions
- Workflows
- Monitoring settings and logs
- App settings
- Local feature metadata

Backup imports support merge and replace modes. Merge mode deduplicates by stable IDs or normalized domain keys, keeps local data where appropriate, and merges audit-session reviewer notes when the same audit session appears in multiple backups.

## Feature Tiers

`FeatureAccessService`, `PremiumAccessService`, `PurchaseService`, and `UsageCreditService` provide the app's feature-gating surfaces.

The app remains local-first. Purchase and entitlement code is local app infrastructure and does not introduce a hosted DomainDig backend.

## Local API

`LocalAPIService` is an automation surface over the same inspection/reporting pipeline:

- `DomainInspectionService`
- `DomainReportBuilder`
- `DomainReportExporter`
- `LocalAPIModels`

The major-version roadmap calls for a stronger compatibility promise around this local API contract in `v5.0.0`.

## Xcode Project Structure

`DomainDig.xcodeproj` uses filesystem-synchronized groups for the `DomainDig` folder. Target membership exclusions are therefore important release metadata. Files that should remain in the tree but not compile, such as retired prototypes, must be listed in the appropriate synchronized build file exception set.

## Adding A New Data Source

1. Add the raw collection call to `LookupRuntime` or an existing section service.
2. Integrate it in `DomainInspectionService` with provenance, cache source, and normalized failures.
3. Extend `LookupSnapshot` only if the raw result must persist.
4. Add summarized representation to `DomainReportBuilder`.
5. Expose it through `DomainReportExporter` or `LocalAPIModels` when it is part of the external contract.
6. Render it in SwiftUI from `DomainReport` fields or view-model state.
7. Update backup/restore only when the data is user-authored state or long-lived app state.
