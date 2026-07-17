# DomainDig Release Roadmap

Priority lens: **new user-facing features.** The inspection engine is already
deep (DNS, DNSSEC, CAA, TLS, TLSA/DANE, email security incl. BIMI/MTA-STS, RDAP,
ports, geolocation, subdomains, availability). The next several releases invest
in *reach and surfacing* — getting that data onto more iOS surfaces and into more
workflows — rather than adding raw protocol checks.

Current version: `v4.5.0`.

## v4.4.1 Patch: Release Readiness — ✅ shipped

- Consolidated Audit Mode onto the single `DomainDig/DomainDig/Audit*`
  implementation and retired the prototype files.
- Aligned `AppVersion.current`, Xcode marketing version, and build number.
- Included audit sessions in backup/restore counts, summaries, and merge behavior.
- Removed the retired `DomainDigCLI` target and refreshed README/architecture docs.

## v4.5.0 Minor: Home Screen & Shortcuts Reach — ✅ shipped

Goal: put DomainDig data and actions where the user already is.

- **App Intents / Shortcuts** — `InspectDomainIntent`, `AddToWatchlistIntent`, and
  `RunSweepIntent`, exposed via `DomainDigShortcuts` for Shortcuts, Spotlight, the
  Action button, and Siri.
- **`domaindig://` deep links** — `inspect`, `watch`, `domain` (detail), and
  `sweep`, routed in `RootTabView`.
- **WidgetKit portfolio widget** (Home Screen small/medium/large) — per-domain
  health, certificate countdowns, and portfolio health counts, shared from the app
  via an App Group; tapping a domain deep-links into its detail.

Deferred to a later minor: **Lock Screen accessory widget families** and a richer
per-widget "last change" indicator.

## v4.6.0 Minor: Alerts, Glances & iPad

Goal: make monitoring and results feel first-class across contexts.

- **Live Activities** for in-flight sweeps and active monitoring alerts
  (cert-expiry and change events at a glance).
- **Share extension**: "Dig this domain" from Safari and the system share sheet.
- **iPad-optimized layout** using `NavigationSplitView` (the app currently ships
  an iPhone-style stack on iPad); adapt watchlist/detail as a two-column layout.
- Richer, actionable notification content building on the existing
  `LocalNotificationService` triggers.

## v4.7.0 Minor: Intelligence & Comparison

Goal: help users interpret and organize, not just collect.

- **Domain-vs-domain comparison** (side-by-side), extending the existing
  time-based `DiffService` to compare two distinct domains.
- **Reputation / blocklist signals** as a new optional data source (currently
  absent); surfaced in the report and available to monitoring alerts.
- **Tags / folders and saved views** for the watchlist to organize large sets.

## v4.8.0 Minor: Reporting & Sharing

Goal: turn point-in-time snapshots into shareable, scheduled deliverables.

- Scheduled report generation (markdown/json/pdf) for tracked domains.
- Stronger share affordances for reports and audit evidence.
- Export polish and consistency across app and local API output.

## v5.0.0 Major: Contract Stabilization & Engineering Health

Goal: earn long-term compatibility promises — and pay down the debt that the
feature releases above will accumulate.

- Define migration policy for persisted snapshots, backups, audits, workflows,
  and settings.
- Stabilize the public local API response contract; document compatibility
  guarantees and planned deprecations.
- **Establish a test target.** The project currently has no XCTest target and no
  tests; add one and cover the deterministic core first — `DomainReportBuilder`,
  `DomainReportExporter`, `DomainDataPortabilityService` (merge/replace dedup),
  and `DiffService` — before locking down external contracts.
- **Decompose the god-files** behind that test net: `DomainViewModel.swift`
  (~4.7k lines) and `ContentView.swift` (~3.8k lines) into focused units
  (audit, monitoring, workflows, portability).

## Cross-cutting note

New feature surfaces (widgets, intents, extensions) each add a target and a
persistence/entitlement seam. Add at least characterization tests for
`DomainDataPortabilityService` and the report builders **before** v4.7.0, so the
v5.0.0 contract and refactor work has a safety net rather than starting from zero.
