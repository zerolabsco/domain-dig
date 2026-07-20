# DomainDig Release Roadmap

Priority lens: **new user-facing features.** The inspection engine is already
deep (DNS, DNSSEC, CAA, TLS, TLSA/DANE, email security incl. BIMI/MTA-STS, RDAP,
ports, geolocation, subdomains, availability). The next several releases invest
in *reach and surfacing* — getting that data onto more iOS surfaces and into more
workflows — rather than adding raw protocol checks.

Current version: `v4.8.1`.

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

## v4.6.0 Minor: Alerts, Glances & iPad — ✅ shipped

Goal: make monitoring and results feel first-class across contexts.

- **Sweep Live Activity** — a batch/watchlist sweep drives a Live Activity with a
  progress bar, current domain, and change/warning counts on the Lock Screen and
  in the Dynamic Island (`SweepActivityController` around the batch pipeline).
- **Share extension** (`DomainDigShareExtension`) — "Dig Domain" accepts a web URL
  from the system share sheet, extracts the host, and hands it to the app via the
  App Group inbox; the app inspects it on next activation.
- **iPad-optimized layout** — `RootTabView` renders a `NavigationSplitView`
  (sidebar + detail) in the regular size class and the tab bar in compact.
- **Actionable notifications** — per-domain `threadIdentifier` grouping, a
  "Re-inspect" action, and taps that route into the domain's detail.

Deferred: monitoring-alert Live Activities (only the sweep activity shipped) and
Lock Screen accessory widget families (carried over from v4.5.0).

## v4.7.0 Minor: Intelligence & Comparison — ✅ shipped

Goal: help users interpret and organize, not just collect.

- **Domain-vs-domain comparison** — `DiffService.compare(domainA:domainB:)`
  reuses the existing section-diff builders; `DomainCompareView` (Watchlist
  toolbar → "Compare Domains") picks two tracked domains and renders the result
  with the existing diff section UI.
- **Reputation / blocklist signals** — a new pluggable data source
  (`ExternalDataService.reputation(domain:)`, Pro+) mirroring the existing
  ownership/DNS-history/pricing enrichment pattern. Ships with no bundled
  third-party endpoint; folds a listed status into risk score/factors and
  insights, so it rides the existing report and monitoring change-severity
  pipeline rather than needing bespoke monitoring wiring.
- **Tags and saved views** for the watchlist — freeform tags per tracked
  domain, tag filter chips, and named saved filter/sort/tag presets
  (UserDefaults-backed; not yet part of backup/restore).

## v4.8.0 Minor: Reporting & Sharing — ✅ shipped

Goal: turn point-in-time snapshots into shareable, scheduled deliverables.

- **Markdown and PDF export formats** — `DomainExportFormat` gains `.markdown`
  and `.pdf` alongside text/csv/json. Markdown reuses the existing text-export
  content via a line-based transform (never drifts from the text export); PDF
  renders that Markdown via `UIGraphicsPDFRenderer`, mirroring the approach
  `AuditExporter` already used for audit sessions.
- **Scheduled report generation** — `ScheduledReportService` /
  `ScheduledReportScheduler` (Settings → Scheduled Reports): a BGTaskScheduler-
  driven daily/weekly job that builds a markdown/PDF/JSON report bundle for all
  tracked domains, writes it locally, logs the run, and notifies when ready.
  Mirrors `DomainMonitoringService`'s headless, storage-backed design; gated
  behind the same Pro `.automatedMonitoring` capability.
- **Stronger share affordances** — "Export Markdown"/"Export PDF" added to the
  single-result, batch, watchlist, and workflow export menus; generated
  scheduled reports are individually shareable from their log.
- **Export consistency verified** — the local API already serves the canonical
  `DomainReport` directly (no field allowlist), so `reputation`, `domainPricing`,
  and every other field added since v4.7.0 already flow through automatically.
  No code change was needed there.

Deferred/scoped out: scheduled-report settings and logs are UserDefaults-only
(not part of `DomainDataPortabilityService` backup/restore), same reasoning as
v4.7.0's watchlist saved views — this is local automation config, not
user-authored content.

## v4.8.1 Patch: Reporting & Sharing Fixes — ✅ shipped

Goal: fix what UAT of v4.8.0 turned up.

- **Scheduled reports were unreachable manually** — the Overview section wrapped
  every control in a single `VStack` inside one `List` row, so SwiftUI collapsed
  them into one tap target and the Cadence `Picker` captured taps meant for
  "Generate Now". Each control is now its own row.
- **Pro gate completed on that screen** — `.automatedMonitoring` previously
  disabled only the toggle, leaving both pickers and "Generate Now" interactive
  on Free where they silently no-opped against the service-side guard.
- **Markdown/PDF reports rendered `=` underlines as bullets** — the plain-text
  transform only recognized `-`, so `batchText`'s title underline and its
  48-character inter-report separators leaked through as literal list items.
- **Duplicate DNS record values** — the report concatenated apex and wildcard
  records without dedup, listing every value twice on domains with wildcard DNS.
- **Inspect tab keyboard behavior** — removed the "Dismiss Keyboard" toolbar
  button and the launch-time focus that raised the keyboard on app open.

Known open follow-ups filed during UAT: integration events to a disabled target
vanish with no delivery-log row (#8), "Process Queue Now" does not force a
backed-off retry (#9), and a monitoring snapshot fallback silently reports "No
meaningful changes" (#10).

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
persistence/entitlement seam. This project still has **no XCTest target** —
v4.5.0 through v4.7.0 all shipped without the characterization-test safety net
originally recommended before v4.7.0. That gap is now larger (comparison,
reputation, and tags/saved-views all touch persisted models with hand-written
backward-compatible decoders) and should be the very first thing v5.0.0 does,
not a later item within it.
