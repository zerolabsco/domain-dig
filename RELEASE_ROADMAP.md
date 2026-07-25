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
  narrowly characterised, always-logged noise suppressions. Findings burndown
  20 → 11, with every remaining item characterised as system noise.
- **Phase 6 verification** — the simulator-executable half of the manual pass
  was run and converted into permanent tests: `AccessibilityMetadataTests`
  asserts the icon-only control labels, toggle selected-states, and dense-row
  label/value pairs; `AccessibilityScreenshotTests` captures both appearances
  across classic chrome and Liquid Glass. A middle-band Dynamic Type sweep was
  added after two real layout bugs turned up *between* the default and
  AccessibilityXXXL test points. The pass also caught a genuine enforced
  `.dynamicType` failure on iOS 27.0 against UIKit-rendered Settings section
  headers; the app applies no font to those, so it is carved out by exact
  header title, scoped to that one audit type.
- **Swift 6 language mode** (#27) — all three product targets build under
  `SWIFT_VERSION = 6.0` with zero warnings. `SMTPChannel` became an actor
  (fixing a real `CheckedContinuation` double-resume hazard),
  `SweepActivityController` stores a Sendable activity id, and the remaining
  isolation issues were resolved layer by layer. The UITests target stays on
  Swift 5 (XCTest override isolation), recorded as a decision.
- **Project hygiene** — the misleading project-level deployment target
  (26.2 shadowing the real 17.6) reconciled; CI selects simulators
  floor-aware instead of first-match.

Deferred — genuinely physical-device-only, since the Simulator cannot run
VoiceOver or Voice Control at all:

- **VoiceOver speech**, the More Content rotor, custom-content ordering, and the
  spoken lookup/sweep announcements. The underlying metadata (labels, values,
  selected states) *is* asserted in `AccessibilityMetadataTests`; what remains
  unverified is how it is spoken.
- **Voice Control** activation of every control by its printed label (WCAG
  2.5.3).
- **iPad Full Keyboard Access** focus order across the split layout.
- **Smart Invert**.

The Liquid Glass (iOS 26+) runtime check is **done** — it ran on simulator
alongside the classic-chrome floor.

## v5.0.0 Major: Contract Stabilization & Engineering Health — ✅ engineering complete (release cut pending)

Goal: earn long-term compatibility promises — and pay down the debt the feature
releases above accumulated. All four workstreams have landed on `main`; cutting
the release itself (version bump and submission) is the only remaining step.

- **Deterministic-core test net — done first**, as the cross-cutting note below
  required. Added `DomainDigTests`, the project's first XCTest unit target,
  hosted by the app with `@testable import`. `SnapshotFixture` builds the deep
  `LookupSnapshot`/`DomainReport` models through the real builder; 58 tests cover
  `DiffService`, `DomainReportBuilder`, `DomainReportExporter`,
  `DomainDataPortabilityService` (merge/replace dedup), the migration runner, and
  the Local API contract. Runs in CI and the pre-push hook. (#43)
- **Local API `v1` contract stabilized.** `LocalAPIContract` is the single source
  of truth for the wire version and JSON encoder; the response envelope and every
  payload are promoted to a first-class, documented contract.
  `Docs/local-api.md` documents each endpoint, the envelope, the encoding
  conventions (notably: absent optionals are omitted, not null), and a
  semantic-version compatibility policy. 16 golden structure tests pin the JSON
  shape so a renamed/removed field fails CI. (#45)
- **Versioned store-migration policy** for persisted snapshots, backups, audits,
  workflows, and settings. `DataMigrationService` became a forward-only,
  idempotent, never-downgrades runner keyed by an integer store schema version,
  replacing the one-shot boolean marker. `Docs/data-migration.md` documents the
  policy, the two independent version lines (on-device store vs. backup export),
  and when to use lenient decoding vs. a migration step; legacy-fixture tests
  cover it. (#46)
- **God-files decomposed** behind that test net, one behavior-preserving slice
  per PR (each built clean with 58/58 tests, no logic changes):
  - `DomainViewModel.swift` **4864 → 4170 lines** — audit, monitoring, export,
    workflow, and history surfaces moved to `DomainViewModel+*.swift`
    extensions. (#47–#51)
  - `ContentView.swift` **3881 → 1625 lines** — Settings screens to
    `SettingsViews.swift` and the nine result section views to
    `ResultSectionViews.swift`. (#52–#53)

  Left in place deliberately: the tightly-coupled inspection core (the section
  runners, `performLookup`/`saveHistoryEntry`, batch orchestration) and a few
  remaining `ContentView` cards/primitives. Splitting the inspection core further
  is a *design* change — extracting a collaborator object — not a mechanical move,
  so it is deferred rather than forced through visibility promotions.

Remaining to cut the release: bump `MARKETING_VERSION` 4.9.0 → 5.0.0 and
increment `CURRENT_PROJECT_VERSION`, keep `AppVersion.current` in sync, and
archive/submit.

## Cross-cutting note

New feature surfaces (widgets, intents, extensions) each add a target and a
persistence/entitlement seam. Through v4.9.0 the project had **no XCTest unit
target** — v4.5.0 through v4.7.0 all shipped without the characterization-test
safety net originally recommended before v4.7.0, and that gap only grew
(comparison, reputation, and tags/saved-views all touch persisted models with
hand-written backward-compatible decoders). v5.0.0 closed it first: the
`DomainDigTests` deterministic-core net went in before anything else, which is
what made stabilizing the external contracts and decomposing the god-files safe
to attempt.
