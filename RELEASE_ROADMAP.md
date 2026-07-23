# DomainDig Release Roadmap

Priority lens: **new user-facing features.** The inspection engine is already
deep (DNS, DNSSEC, CAA, TLS, TLSA/DANE, email security incl. BIMI/MTA-STS, RDAP,
ports, geolocation, subdomains, availability). The next several releases invest
in *reach and surfacing* — getting that data onto more iOS surfaces and into more
workflows — rather than adding raw protocol checks.

Current version: `v4.9.0`.

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
- **In-app purchases were unbuyable** — none of the four product ID constants in
  `PurchaseService` matched the auto-renewable subscriptions configured in App
  Store Connect, so `Product.products(for:)` returned nothing and `tier(for:)`
  resolved every purchase to `.free`. Product IDs are permanent once created, so
  the constants were corrected to match the store rather than the reverse.
- **Local StoreKit testing** — added `DomainDig.storekit` mirroring the App Store
  Connect group (Pro+ at level 1, Pro at level 2) and wired it into the Run
  action, so the purchase and entitlement paths can be exercised without the
  `DOMAIN_DIG_FORCE_PRO_PLUS` launch argument that bypasses StoreKit entirely.

Follow-ups filed during UAT (#8, #9, #10) were all resolved in v4.8.2.

## v4.8.2 Patch: Delivery Visibility & Build Health — ✅ shipped

Goal: close the UAT follow-ups and make failures legible instead of silent.

- **Disabled integrations no longer swallow events** (#8) — `enqueue(events:)`
  filtered to enabled targets before writing any `DeliveryRecord`, so events
  routed to a disabled integration vanished entirely. They now log a `.skipped`
  entry with a reason. `sendTest` also respects `isEnabled`, which previously
  delivered against targets that dropped every real event.
- **"Process Queue Now" forces backed-off retries** (#9) — it only restarted the
  processing task, never moving `nextAttemptAt`, so an item in backoff (up to an
  hour) stayed undue and the button appeared inert. It now pulls queued items
  forward, and reports an empty queue instead of doing nothing silently.
- **Unreachable domains report as unreachable** (#10) — when the snapshot
  fallback fired, the run compared old data against itself and claimed "No
  meaningful changes" for a domain it never reached. `MonitoringDomainResult`
  now carries `unreachableReason`, the summary says so, and a warning-severity
  `monitoringFailure` reaches configured integrations.
- **Swift 6 concurrency warnings cleared** — `SweepActivityAttributes` is
  explicitly `nonisolated` (the app target sets
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` while the widget target does not),
  and `LocalAPIService`'s logger closures capture `self` coherently. Build is
  warning-free.
- **StoreKit configuration corrected and synced** — the scheme's path was wrong,
  and the hand-authored file has been replaced by `SyncedProducts.storekit`,
  synced against App Store Connect. Registered in the project without target
  membership so it is not bundled into shipping builds.

## v4.8.3 Patch: Static Analysis Cleanup — ✅ shipped

Goal: clear the SonarCloud new-code backlog without changing behavior.

- **Dead confidence conditionals fixed** (4 bugs) —
  `DomainInspectionService`'s `confidenceFor*` helpers each returned
  `error == nil ? .low : .low`. The conditional was inert, so the unused `error`
  parameter was dropped alongside it.
- **Identical switch branches merged** — 14 sites in `DomainViewModel` handled
  `.empty(message)` and `.error(message)` with byte-identical bodies; they now
  share one `case let .empty(message), let .error(message):`.
- **Duplicate implementations consolidated** — `clearPresentedResults()` now
  delegates to `reset()`, `String.nonEmpty` was folded into `nilIfEmpty`, and
  `ExportFormat.id` derives from `fileExtension`.
- **Nested ternaries extracted** — grade-to-tone and impact-to-color mappings
  became `TLSGrade.tone`, `EmailSecurityGrade.tone`, and
  `ChangeImpactClassification.color`, replacing `ContentView`'s private
  `impactColor` and the duplicate mapping in `BatchResultsView`.
- **Remaining smells** — empty closures and singleton inits documented, unused
  protocol-conformance parameters marked `_`, `CloudSyncTrigger.import` renamed
  to `imported` (raw value preserved), `_serverTrust`/`_tlsMetadata` renamed,
  nested `if`s merged in the DER parser, and deep closure nesting flattened in
  `PortScanService` and `IntegrationService`.

Left open deliberately: `swift:S107` (initializer parameter counts on model
memberwise inits), `swift:S115` (constants mirroring DoH/ipapi JSON keys),
`swift:S1075` (false positives on `https://` literals), and two `swift:S117`
hits on SwiftUI `$binding` shorthand in `AuditModeView`, which cannot be
renamed. These want a *Won't Fix* / *Safe* resolution in SonarCloud rather than
a code change.

## v4.9.0 Minor: Accessibility, Appearance & Engineering Health — ✅ shipped

Goal: make the app usable by every iOS user — full accessibility pass (#21),
light mode, and the engineering scaffolding to keep both from regressing.

- **Semantic colour system** — every hard-coded colour replaced with adaptive
  colorsets in `Shared/Colors.xcassets` (Any/Dark + High Contrast variants),
  shared by app, widget, and share extension via the synchronized `Shared`
  group. Every status colour clears WCAG AA on its page, its card, and its
  badge surface, in both schemes; measured, not asserted. The accent is now
  blue (`#0000FF` light / `#4DA3FF` dark), split into foreground
  (`StatusInfo`), fill (`AccentFill`), and on-fill (`AppOnAccent`) roles
  because one value cannot serve as both text-on-dark and fill-behind-white.
  `AppStatusTone` pairs each status foreground with an authored surface.
- **Light mode unlocked** — the 16 scattered `.preferredColorScheme(.dark)`
  calls removed; appearance (System/Light/Dark) is applied once at the
  `WindowGroup` and exposed under Settings → Display. `.secondary` (3.29:1 on a
  light card) replaced with `AppTextSecondary` across 191 sites.
- **Dynamic Type & reflow** — `Label`-clipped empty-state titles fixed, the
  44pt tap-target floor enforced (`AppCopyButton` was 30×30;
  `controlMinHeight` was 42), `CardView`'s horizontal-scroll default flipped
  to reflow, dense rows (`WatchlistRowView`, `BatchResultRowView`,
  `PortfolioExpiryRow`) and the collapsible section headers rebuilt on
  `ViewThatFits` so badges and buttons can never letter-wrap vertically, and
  the widget clamped at `accessibility1` (fixed canvas, no scroll).
- **VoiceOver** — labels on every icon-only control (label-in-name preserved
  for Voice Control), selected-state on all toggles, badges read as one word,
  heading-rotor navigation, dense rows collapsed to one element with the
  detail on the More Content rotor (`accessibilityCustomContent`), technical
  strings (DNS records, cipher suites) spoken with punctuation, and lookup/
  sweep completion announcements. Widget rows read as a single phrase.
- **Colour independence, motion, transparency** — widget status uses the badge
  symbol vocabulary instead of colour-only dots; `differentiateWithoutColor`
  adds symbols/borders on demand; all five animation sites honour
  `reduceMotion`; the one material honours `reduceTransparency`.
- **Accessibility audit harness** — `DomainDigUITests` runs
  `performAccessibilityAudit()` over every primary screen at default and
  AccessibilityXXXL, on CI (newest runtime, clean merge-result checkout) and
  locally (`Scripts/audit-a11y.sh`, real floor runtime, wired to an opt-in
  pre-push hook). `DOMAIN_DIG_SEED_FIXTURES` seeds deterministic in-memory
  rows so the dense paths actually render under audit. The **enforcement
  ratchet is engaged**: named findings in six categories fail CI, with
  narrowly characterised, always-logged noise suppressions. Manual
  verification checklist in `Docs/ACCESSIBILITY_VERIFICATION.md`; findings
  burndown 20 → 11 with every remaining item characterised as system noise.
- **Swift 6 language mode** (#27) — all three product targets build under
  `SWIFT_VERSION = 6.0` with zero warnings. `SMTPChannel` became an actor
  (fixing a real `CheckedContinuation` double-resume hazard),
  `SweepActivityController` stores a Sendable activity id, and the remaining
  isolation issues were resolved layer by layer. The UITests target stays on
  Swift 5 (XCTest override isolation), recorded as a decision.
- **Project hygiene** — the misleading project-level deployment target
  (26.2 shadowing the real 17.6) reconciled; CI selects simulators
  floor-aware instead of first-match.

Deferred: the Phase 6 manual device passes (VoiceOver walkthrough, Voice
Control, iPad Full Keyboard Access, Liquid Glass runtime check) are tracked in
`Docs/ACCESSIBILITY_VERIFICATION.md` and #21 — they close on device, not in CI.

## v5.0.0 Major: Contract Stabilization & Engineering Health

Goal: earn long-term compatibility promises — and pay down the debt that the
feature releases above will accumulate.

- Define migration policy for persisted snapshots, backups, audits, workflows,
  and settings.
- Stabilize the public local API response contract; document compatibility
  guarantees and planned deprecations.
- **Extend the test net to the deterministic core.** v4.9.0 established
  `DomainDigUITests` (accessibility audit + enforcement gate); unit coverage of
  `DomainReportBuilder`, `DomainReportExporter`, `DomainDataPortabilityService`
  (merge/replace dedup), and `DiffService` is still needed before locking down
  external contracts.
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
