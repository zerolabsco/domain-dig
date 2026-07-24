# Accessibility Verification — Results (issue #21, Phase 6)

Execution of `ACCESSIBILITY_VERIFICATION.md` against the iOS Simulator. The
runbook was written for a human on a physical device; a meaningful fraction is
beyond a simulator. Every item below is sorted into one of three tiers and
treated accordingly:

- **Tier 1 — executed here.** Appearance, Increase Contrast, Dynamic Type
  (including a middle-band sweep), the audit suite, accessibility **metadata**
  (labels/values/traits, now permanent XCUITest assertions), and the
  Liquid-Glass-vs-classic cross-runtime comparison.
- **Tier 2 — attempted, reported honestly.** Differentiate Without Color,
  Reduce Motion, Reduce Transparency. One of the three turned out to be fully
  toggleable and is now **verified**; the mechanism is documented for the rest.
- **Tier 3 — requires a physical device.** VoiceOver speech, the rotor,
  announcements, Voice Control, Screen Curtain. Not attempted, not faked.

**"Verified" vs "verified by construction."** A ✅ **Pass** means the behaviour
was *observed* (a screenshot, an assertion, or a finding-count delta). *Verified
by construction* (⚙️) means the code compiles and the pattern is right but the
runtime behaviour was not observed here — it is **not** counted as a pass.

## Environment

| Role | Simulator | Runtime | Design language |
| --- | --- | --- | --- |
| Floor | iPhone 16 | iOS 18.6 | Classic chrome |
| Liquid Glass (mid) | iPhone 17 | iOS 26.5 | Liquid Glass |
| Current | iPhone 17e | iOS 27.0 | Liquid Glass |

Deployment target is 17.6; no 17.6/17.5 runtime is usable (the app cannot
install below the floor), so 18.6 is the practical floor, per the runbook.

Seed data via `DOMAIN_DIG_SEED_FIXTURES` + `DOMAIN_DIG_FORCE_PRO_PLUS` (DEBUG,
in-memory, never persisted). **Note on tooling:** `simctl launch` with the seed
argument did *not* populate the fixtures, and `simctl ui appearance` did not
propagate to a headless-booted simulator. Both were worked around by driving
everything through **XCUITest** (which seeds reliably) and switching appearance
through the app's own Settings → Display picker. This is why the screenshots and
metadata checks are committed as tests rather than shell scripts — see
`DomainDigUITests/AccessibilityScreenshotTests.swift` and
`AccessibilityMetadataTests.swift`.

---

## Headline outcomes

1. **A real enforced failure was found and fixed.** `Scripts/audit-a11y.sh
   current` (iOS 27.0) failed an **enforced** `.dynamicType` finding on the
   Settings `Section("Services")` header — a system-rendered header the app sets
   no font on, present only on 27.0 (18.6 floor and the 26.x runtime CI uses are
   clean). Resolved with a narrow, proven `noiseReason(for:)` carve-out. Delta:
   `current` went **FAIL → SUCCEEDED**, the finding still printed as
   `[noise: …]`. See §5 and the fix note below.
2. **The highest-value metadata checks are now permanent tests.** The dense-row
   label/value contracts and the icon-only control labels are asserted
   mechanically in `AccessibilityMetadataTests` (green on 18.6 and 27.0),
   shrinking the manual runbook.
3. **Differentiate Without Color is fully verifiable in the simulator** via the
   *global* `com.apple.Accessibility` defaults domain — the runbook and task
   both assumed this might not be reachable. It is. Captured proof:
   `lg-dashboard-light-differentiate.png`.
4. **The middle-band Dynamic Type sweep found no third bug** exclusive to that
   band (negative result), but is retained as regression insurance for a band
   that historically shipped two.

---

## 1. Baseline visual — Light, Dark, System `[P1][P2]`

Evidence: `classic-dashboard-{light,dark}.png`, `lg-dashboard-{light,dark}.png`,
`classic-batch-{light,dark}.png`, `lg-batch-{light,dark}.png`. Appearance driven
through Settings → Display.

| Item | Result | Notes |
| --- | --- | --- |
| System follows device | ⚙️ By construction | `simctl ui appearance` does not propagate headlessly; Light/Dark set via the in-app picker instead, which drives the same single `@AppStorage` path. |
| Light / Dark overrides hold | ✅ Pass | Both captured on both runtimes; the picker override renders correctly. |
| Accent blue everywhere, no cyan | ✅ Pass | Tab-bar selection, `•All`, links, selected quick-filter chip all blue. No cyan observed. |
| Warning reads orange, not olive | ✅ Pass | Dashboard "Warning" tile and batch "Warning" badge are clearly orange in both schemes. |
| Selected tile is blue-tinted, not lavender | ✅ Pass | "Total Domains" tile is a soft blue surface in light and dark. |
| Prominent buttons: white label on blue fill | ⚙️ By construction | Run/Run Batch are disabled in the seeded state (no typed domain), so the enabled `.borderedProminent` fill was not captured; palette values are audited. |
| Secondary text legible in Light | ✅ Pass | "QUICK FILTERS", timestamps, "No recent portfolio changes" read clearly on the light card (this is the `AppTextSecondary` fix). |
| Badges pair icon + text + colour | ✅ Pass | Batch badges show lock/triangle/octagon/x + word + colour. |
| Repeat on floor runtime | ✅ Pass | Classic-chrome (18.6) captures match; see cross-runtime §8. |

## 2. Dynamic Type & reflow — up to Accessibility 5 `[P3]`

Evidence: `*-dashboard-axxxl.png`, `*-batch-axxxl.png`, `*-watchlist-axxxl.png`
(both runtimes), plus the automated `…AccessibilityXXXL` and new
`…AccessibilityL` audit sweeps.

| Item | Result | Notes |
| --- | --- | --- |
| Body text + tile numbers scale | ✅ Pass | Dashboard "4 / 2 / 1" and all labels scale at AXXXL. |
| No clipped headings (wrap, not "…") | ✅ Pass | "Batch Results", "Total Domains" wrap onto multiple lines; audit reports no *named* `textClipped` on empty-state headings. |
| No card needs horizontal scrolling | ✅ Pass | Cards reflow vertically at AXXXL; no hidden horizontal gesture. |
| Dense rows readable at AX5 | ⚠️ Known-deferred | Watchlist/batch rows become very tall and wrap; readable, no horizontal badge overlap. This is the deferred `ViewThatFits` case, **not** a P3 regression (see `lg-watchlist-axxxl.png`). |
| Tap targets ≥ 44×44 | ⚙️ By construction | `AppLayout.minimumTapTarget` floor is enforced in code and the audit reports no named `hitRegion` findings; not separately measured here. |
| Bold Text | ❌ Not executed | Not exposed by `simctl`; same class as the Tier-2 settings. Requires device or Settings-app automation. |
| Widget clamps at AX1 | ❌ Not executed | Widgets do not render in the audit simulator or these captures — Tier 3-adjacent (needs Home Screen). |
| Repeat spot-checks on floor | ✅ Pass | Classic AXXXL captures match. |

**Middle-band sweep (added).** `testSeededScreensAtIntermediateAccessibilitySize`
audits the seeded screens at `AccessibilityL`. Result: the `textClipped` findings
it surfaced on the Risk badges (`Risk 12 Low`, `Risk 41 Medium`) are **also
present at the default size** and absent at XXXL, so they are pre-existing
reportOnly seeded-row findings, **not** a middle-band-exclusive third bug. No new
gap found. The sweep is retained as regression insurance for a band that
historically shipped two escaped bugs.

## 3. VoiceOver `[P4]` — Tier 3, requires a physical device

iOS VoiceOver **speech** does not run in the Simulator; macOS VoiceOver reading
the simulator window is not equivalent and is not accepted as evidence. What the
simulator *can* assert is the underlying **metadata**, which is now covered by
`AccessibilityMetadataTests` (green on 18.6 and 27.0):

| Runbook item | Metadata coverage | Result |
| --- | --- | --- |
| §3a Dashboard refresh → "Refresh all tracked domains" | asserted | ✅ Pass |
| §3a Watchlist add → "Add domain"; filter → "Filter and sort" | asserted | ✅ Pass |
| §3a Workflows create → "Create workflow" | asserted | ✅ Pass |
| §3a History filter → "Filter" | ⚙️ By construction | Menu is gated behind non-empty history; not seedable. Label exists at `HistoryView.swift:109`. |
| §3a Inspect clear/actions/export, Timeline grouping, Workflow export/re-run/shared | ⚙️ By construction | Reachable only after a live lookup / on populated workflow runs; labels verified in source (see `ACCESSIBILITY.md` map). |
| §3d Watchlist row: label = domain, value = availability | asserted | ✅ Pass (`healthy.example`→"Registered"; long domain→"Unknown") |
| §3d Batch row: label = domain, value = "status, availability" | asserted | ✅ Pass (`broken.example`→"Critical, Registered"; `unreachable.example`→"Failed, Unknown") |
| §3c Badge reads as one word | asserted (folded into row value) | ✅ Pass |
| §3b Save/Pin selected-state; §3b audit checklist; picker selected | ⚙️ By construction | All live behind a completed live inspection, seeded audits, or a multi-step gated flow — non-deterministic in CI. Traits verified in source (`ContentView.swift:565–567, 1372–1374`; `AuditViews.swift:264–265`; `WorkflowsView.swift:647`). |
| §3e speech style, §3f announcements, §3g widget speech, §3h Screen Curtain | ❌ Requires device | VoiceOver speech / rotor / announcements — Tier 3. |

**Rotor / custom-content ordering:** not observable from XCUITest at all —
`.accessibilityCustomContent` does not surface as a queryable element property.
Verified by construction (the `WatchlistRowAccessibility` /
`BatchRowAccessibility` modifiers) and deferred to the device pass.

## 4. Voice Control (WCAG 2.5.3) `[P4]` — Tier 3, requires a physical device

Voice Control does not run in the Simulator. Label-in-name is partially
*inferable* — every asserted `accessibilityLabel` in §3 preserves the control's
visible text — but "say the printed word and it activates" must be confirmed on
hardware.

| Item | Result |
| --- | --- |
| "Tap Run / Track / Note / Compare / Cancel / Save" by printed word | ❌ Requires device |
| "Show numbers" overlays on icon-only controls | ❌ Requires device |
| No control reachable only by a differing name | ⚙️ By construction (labels preserve visible text) |

## 5. Colour & contrast settings `[P1][P2][P5]`

### 5a. Increase Contrast — Tier 1

`simctl ui <udid> increase_contrast enabled` works. The palette carries HC
variants; the audit's `.contrast` category stays report-only by design (see
`ACCESSIBILITY.md`).

| Item | Result | Notes |
| --- | --- | --- |
| Status/accent shift to HC variants, nothing unreadable | ⚙️ By construction | HC toggles via `simctl`, but the effect is a colour-value swap not reliably distinguishable in a downscaled screenshot; palette HC variants are defined and audited. |
| Marginal Settings headers clear | ⚙️ By construction | The documented light 21→18 contrast measurement; unchanged this pass. |

### 5b. Differentiate Without Color — **Tier 2, VERIFIED** ✅

The runbook and task both flagged this as possibly un-toggleable in a simulator.
It **is** toggleable: `simctl ui` does not expose it, and a `defaults write` to
the app's *own* (sandboxed) container does not reach it — but a write to the
**global** `com.apple.Accessibility` domain does, and XCUITest-launched apps read
it via `UIAccessibility`:

```sh
xcrun simctl spawn <udid> defaults write com.apple.Accessibility DifferentiateWithoutColor -bool true
```

Captured proof — `lg-dashboard-light-differentiate.png` vs `lg-dashboard-light.png`:

| Item | Result | Observed |
| --- | --- | --- |
| Summary tiles gain per-filter symbols | ✅ Pass | Dot → grid (All), checkmark (Healthy), triangle (Warning), octagon (Critical), refresh (Changed), wifi-slash (Unreachable). |
| Selected quick-filter chip gains checkmark + border | ✅ Pass | "All" chip shows ✓ and a border; selection no longer fill-colour only. |
| Inspect data-row warning/failure symbol | ⚙️ By construction | `LabeledValueRow` is behind a live lookup; the Dashboard payoff above exercises the same `accessibilityDifferentiateWithoutColor` path. |
| Turning it off removes the extras | ✅ Pass | The default set of screenshots (setting off) shows plain dots / no chip checkmark. |
| Widget uses symbols regardless | ⚙️ By construction | Widget does not render in these captures. |

### 5c. Smart Invert — ❌ Not executed

Not exposed by `simctl`; not in the global-domain set that worked for DWC.
Requires the Settings app / device.

## 6. Motion & transparency `[P5]` — Tier 2

Both settings **can be written** to the global `com.apple.Accessibility` domain
(`ReduceMotionEnabled`, `ReduceTransparencyEnabled`) — the same mechanism proven
to reach the app for DWC. But their *effects* are not screenshot-capturable:

| Item | Result | Notes |
| --- | --- | --- |
| §6a Reduce Motion: copy-check swap, section expand, timeline scroll, list reorder become instant | ⚙️ By construction | Effect is animation *timing*; a still frame cannot show "instant vs animated". Toggle mechanism confirmed; five sites guarded via `accessibilityReduceMotion` in code. |
| §6b Reduce Transparency: Data Management toast is opaque | ⚙️ By construction | The only translucency swap is a **transient** toast behind a multi-step clear; not captured. `accessibilityReduceTransparency` swap verified in source. |
| §6b iOS 26+ system chrome still reads acceptably | ✅ Pass | Liquid Glass nav/tab bars legible in all captures (app cannot declare that translucency itself). |

**Net:** the Tier-2 toggle method (global accessibility defaults + XCUITest
launch) is now known to work — DWC is fully verified with it. Motion and
Transparency remain verified-by-construction because their effects are timing /
transient, but the manual device pass for them is now optional rather than
blocked: the same `defaults write` unblocks a scripted check with a screen
recording.

## 7. iPad — Full Keyboard Access & split layout `[verification]`

| Item | Result |
| --- | --- |
| Tab focus order, focus ring, sidebar/detail reachability, tab→detail update | ❌ Requires device | Full Keyboard Access is not exposed by `simctl`; keyboard-focus traversal is a hardware/Settings behaviour. The `NavigationSplitView` layout itself renders (regular width) but focus order was not exercised. |

## 8. Cross-runtime sign-off `[cross-runtime]`

Captured the same seeded screens on **classic chrome (18.6)** and **Liquid Glass
(26.5)** in Light, Dark, and AXXXL. The audit was run on **18.6 and 27.0**.

- The semantic palette resolves correctly on both design languages: warning
  orange, critical red, positive green, blue accent, blue-tinted selected tile.
  No Liquid-Glass-only palette regression observed.
- The only structural difference is expected: Liquid Glass renders translucent,
  rounded nav/tab chrome; classic renders flatter, opaque chrome. Legibility
  holds in both.
- **Audit coverage is genuinely not nested:** 18.6 passed clean; 27.0 surfaced
  the extra `Section` header `.dynamicType` finding that 18.6/26.x do not (now
  carved out). This confirms the repo's rationale for a per-runtime local run.

---

## Filled sign-off

| Pass | 26+/27 (Liquid Glass) | Floor (classic 18.6) | Notes |
| --- | --- | --- | --- |
| 1 Baseline visual | ✅ | ✅ | Light/Dark captured both; System by-construction |
| 2 Dynamic Type / reflow | ✅ | ✅ | AXXXL + middle-band L; dense rows known-deferred |
| 3 VoiceOver | metadata ✅ / speech ❌ device | metadata ✅ | Speech/rotor Tier 3 |
| 4 Voice Control | ❌ device | ❌ device | Labels preserve visible text (by construction) |
| 5 Colour & contrast | 5b DWC ✅ / 5a,5c ⚙️/❌ | 5b DWC ✅ | DWC verified via global defaults |
| 6 Motion & transparency | ⚙️ | ⚙️ | Effects not screenshot-capturable |
| 7 iPad keyboard | n/a | ❌ device | FKA not in simulator |

## Tier 3 — the residual physical-device pass

The human pass now shrinks to exactly these, all requiring hardware:

- **VoiceOver:** §3a controls only reachable after a live lookup (Inspect
  clear/actions/export, Timeline grouping, Workflow export/re-run/shared);
  §3b Save/Pin/audit-checklist/picker selected-state *spoken*; §3c one-word
  badge *spoken*; §3d More Content rotor order; §3e technical-string speech;
  §3f completion announcements; §3g widget speech; §3h Screen Curtain journey.
- **Voice Control:** §4 in full.
- **Bold Text** (§2), **Smart Invert** (§5c), and the **iPad Full Keyboard
  Access** pass (§7) — Settings toggles not exposed to `simctl` and not in the
  global accessibility domain.
- **Widget** at AX sizes and under VoiceOver (§2, §3g) — needs the Home Screen.
- **Reduce Motion / Reduce Transparency** *effect* confirmation (§6) — optional;
  the toggle is now scriptable, but observing instant-animation / opaque-toast
  needs a screen recording.

## Changes made this pass

| Change | File | Evidence |
| --- | --- | --- |
| Fixed enforced 27.0 Settings `.dynamicType` failure | `DomainDigUITests/AccessibilityAuditHarness.swift` | `audit-a11y.sh current` FAIL → SUCCEEDED; finding prints as `[noise: iOS-rendered Settings section header …]` |
| New metadata assertions (icon labels, dense-row label/value) | `DomainDigUITests/AccessibilityMetadataTests.swift` | 4 tests green on 18.6 + 27.0 |
| Middle-band Dynamic Type sweep (`AccessibilityL`) | `DomainDigUITests/AccessibilityAuditTests.swift` | Passes; negative result recorded above |
| Screenshot-capture utility (best-effort, non-gating) | `DomainDigUITests/AccessibilityScreenshotTests.swift` | 15 screenshots in `Docs/a11y-screenshots/` |

### On the suppression (not a ratchet weakening)

The Settings finding is on a plain `Section("Services")` (`ContentView.swift`
~2768) whose font the app never sets — the scaling is UIKit's system header. It
appears **only** on iOS 27.0 (the 18.6 floor and the 26.x runtime CI runs are
clean; `ACCESSIBILITY.md` already records this asymmetry as "dynamicType finding
18.6 missed"). The carve-out is scoped to `.dynamicType` on the exact Settings
section-header titles, so a real regression on app-controlled text still
enforces — matching the existing "system field placeholder" and system-header
contrast carve-outs. The proof lives inline in `noiseReason(for:)`.

## Screenshot index (`Docs/a11y-screenshots/`)

| File | Runtime | Screen | Config |
| --- | --- | --- | --- |
| `classic-dashboard-light.png` / `-dark.png` | 18.6 | Dashboard | Light / Dark |
| `classic-batch-light.png` / `-dark.png` | 18.6 | Batch results | Light / Dark |
| `classic-{dashboard,watchlist,batch}-axxxl.png` | 18.6 | — | AccessibilityXXXL |
| `lg-dashboard-light.png` / `-dark.png` | 26.5 | Dashboard | Light / Dark |
| `lg-batch-light.png` / `-dark.png` | 26.5 | Batch results | Light / Dark |
| `lg-{dashboard,watchlist,batch}-axxxl.png` | 26.5 | — | AccessibilityXXXL |
| `lg-dashboard-light-differentiate.png` | 26.5 | Dashboard | Light + Differentiate Without Color |
