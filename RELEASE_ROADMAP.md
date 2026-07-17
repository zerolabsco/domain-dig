# DomainDig Release Roadmap

Priority lens: **new user-facing features.** The inspection engine is already
deep (DNS, DNSSEC, CAA, TLS, TLSA/DANE, email security incl. BIMI/MTA-STS, RDAP,
ports, geolocation, subdomains, availability). The next several releases invest
in *reach and surfacing* — getting that data onto more iOS surfaces and into more
workflows — rather than adding raw protocol checks.

Current version: `v4.4.1`.

## v4.4.1 Patch: Release Readiness (in progress)

Finish the audit-mode consolidation already on the working tree, then ship a
clean release candidate.

- Resolve duplicate Audit Mode implementations; retire the prototype
  `AuditMode.swift` / `AuditModeView.swift` and keep the `DomainDig/DomainDig/Audit*`
  path as the single active implementation.
- Align `AppVersion.current`, Xcode marketing version, and build number.
- Confirm audit sessions are included in backup/restore counts, summaries, and
  merge behavior.
- Refresh README and architecture docs to match the shipping surface.

Gate: clean Xcode build/archive before tagging.

## v4.5.0 Minor: Home Screen & Shortcuts Reach

Goal: put DomainDig data and actions where the user already is.

- **WidgetKit widgets** (Home Screen + Lock Screen) for pinned/watchlist domains:
  certificate expiry countdown, monitoring status, last-change indicator.
- **App Intents / Shortcuts**: "Inspect domain", "Add to watchlist", "Run sweep"
  as intents usable from Shortcuts, Spotlight, and the Action button.
- Deep links from widgets and intents into the relevant domain detail screen.
- Polished audit-mode ergonomics carried over from the prior roadmap (timeline
  presentation, checklist/finding editing, markdown/json/pdf export affordances).

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
