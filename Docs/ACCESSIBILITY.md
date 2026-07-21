# Accessibility Audit

`DomainDigUITests` runs Apple's `performAccessibilityAudit()` across every
primary screen. The audit checks contrast, hit-region size, clipped text at
large Dynamic Type, element descriptions, trait correctness, and Dynamic Type
support — the same ground the accessibility pass tracked in
[issue #21](https://github.com/zerolabsco/domain-dig/issues/21) covers.

## The colour palette

Semantic colours live in `Shared/Colors.xcassets`, which is inside the `Shared`
file-system-synchronized group and therefore reaches the app, the widget, and
the share extension automatically. `AccentColor` stays in
`DomainDig/Assets.xcassets` because it is the system-wide tint resolved via
`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`.

Use the generated asset symbols — `Color(.statusCritical)`, `Color(.appSurface)`
— never a literal. `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`
is on, so these are compile-time checked; a typo will not build.

Every value clears WCAG AA (4.5:1) as text on its page, on its card, **and on
its own 16% badge tint** — the way `AppStatusBadgeView` actually draws it. The
worst of those three is shown:

| Role | Light | Dark | Worst light | Worst dark |
| --- | --- | --- | --- | --- |
| `StatusInfo` / `AccentColor` | `#0000FF` | `#4DA3FF` | 6.76 | 6.47 |
| `StatusPositive` | `#008035` | `#30D158` | 4.54 | 7.62 |
| `StatusWarning` | `#AD5100` | `#FF9F0A` | 4.59 | 7.76 |
| `StatusCritical` | `#CC0700` | `#FF6961` | 4.68 | 6.12 |
| `StatusNeutral` | `#5A5A5F` | `#A1A1A6` | 5.84 | 6.76 |

Each status foreground has a matching `…Surface` colour for the fill behind it,
paired through `AppStatusTone`.

### Contrast alone is not a palette

The first version of this palette maximised contrast and produced mud. Requiring
every foreground to clear 4.5:1 against *its own 16% tint* — the harshest
surface it ever sits on — pushed each colour ~20% darker than the common case
needed. `#7A5600` is not amber, it is olive; `#146C2E` is not green so much as
bottle-dark. Contrast passed and the UI was still hard to read, because hue
identity is what tells "warning" from "critical" at a glance.

Two fixes:

1. **Decouple the fill from the foreground.** `AppStatusTone` carries a
   `foreground` and a `surface` that are authored independently, so the
   foreground no longer has to survive a wash of itself. Every status foreground
   is now fully saturated (`S = 1.0`).
2. **Warning is orange, not yellow.** Yellow cannot stay yellow at a lightness
   low enough to clear 4.5:1 on white — it *becomes* olive. That is
   colorimetric, not a tuning problem. Orange holds its identity when darkened,
   so warning is `#AD5100` in light and `#FF9F0A` in dark.

When adding a colour, search for the most saturated value that passes, not the
darkest. The darkest is always easy and always wrong.
| `AppTextSecondary` | `#5A5A5F` | `#A1A1A6` | 6.15 | 7.50 |

`AppTextSecondary` replaces `.secondary` for body text. iOS's own `secondaryLabel`
is only **3.29:1** on a light card — below AA — which never showed while the app
was locked to dark, where the same colour reads 6.32:1. Unlocking light mode
exposed it across 191 sites.

High Contrast variants push further in the same direction. Surfaces
(`AppBackground`, `AppSurface`, `AppSurfaceElevated`, `AppSeparator`) carry no
meaning, so they get Any/Dark and, where useful, High Contrast — but no status
semantics.

Why custom values instead of the system palette: **every** system colour fails
in light mode. Measured on white — systemYellow 1.51:1, systemOrange 2.20:1,
systemGreen 2.22:1, systemCyan 2.54:1, systemRed 3.55:1. All of them pass in
dark mode, which is why the dark-locked app looked fine and why unlocking light
mode is impossible without this work.

### The accent has two roles, and they conflict

An accent used as **text on a dark background** must be light. The same accent
used as a **fill behind a white label** must be dark. One value cannot do both:
`#4DA3FF` reads at 8.00:1 as text on black, but only 2.63:1 behind white text.

So there are two colours:

- `StatusInfo` / `AccentColor` — the accent as *foreground*: text, icons,
  bordered-button labels, tab bar.
- `AccentFill` — the accent as a *filled background* behind a label, used by
  `.borderedProminent`. Stays dark in both schemes so a white label clears AA
  (8.59:1 light, 7.56:1 dark).

`AppOnAccent` is the label colour for a solid accent fill and flips by scheme —
white on the light accent, black on the dark one.

## Appearance

`AppAppearance` (System / Light / Dark) is stored in `@AppStorage` and applied in
**exactly one place** — the `WindowGroup` in `DomainDigApp`. Keep it that way. The
app previously carried 16 separate `.preferredColorScheme(.dark)` calls scattered
through view bodies, which is how light mode became unreachable without anyone
noticing; re-applying per view is what let the lock spread.

Users override it under Settings → Display.

### Known light-mode findings

| Finding | Cause | Action |
| --- | --- | --- |
| 2× `contrast failed` on Settings | The last rows of a section sit under the translucent tab bar, so the audit measures text against a blended background. Present in dark mode too, since phase 0. | None — standard iOS scroll-under behaviour |
| 3× `contrast nearly passed` on Settings | iOS-rendered `Section` headers (`TIER`, `PREFERENCES`, `SERVICES`) use the system's grey. | Not fixed. Overriding system header styling across every section to gain ~0.3:1 on decorative labels trades platform convention for very little |

Dark mode reports 18 findings and light mode 21; the three extra are the section
headers above. Everything the app actually controls passes in both schemes.

## Findings are reported, not enforced

The audit surfaces violations that exist today, so failing on all of them would
block every unrelated change until the whole pass lands. Instead, findings are
logged and attached to the result bundle tagged `[report]` or `[FAIL]`.

Enforcement is the committed constant
`AccessibilityAuditHarness.enforcedAuditTypes`. Widen it as each phase clears a
category:

| After phase | Enforce |
| --- | --- |
| 2 — semantic colors + light mode | `.contrast` |
| 3 — Dynamic Type + reflow | `.textClipped`, `.dynamicType`, `.hitRegion` |
| 4 — VoiceOver | `.elementDetection`, `.sufficientElementDescription`, `.trait` |

A constant rather than a CI setting, for two reasons. Environment variables do
not work: neither a plain `xcodebuild` env var nor a `TEST_RUNNER_`-prefixed
build setting reaches the UI test process, so the toggle silently did nothing.
And a committed value makes "when did contrast become enforced?" answerable with
`git blame` instead of CI tribal knowledge.

## Why coverage is split between local and CI

**Audit coverage is not nested across OS versions.** Each runtime reports
findings the others miss, in *both* directions. Measured on this project:

| Screen | iOS 18.6 | iOS 27.0 |
| --- | --- | --- |
| Tracked Domains | 2 (text clipped) | **6** (+ contrast ×3, element detection) |
| Settings | 2 contrast | **`dynamicType`** finding 18.6 missed |
| Dashboard @ `AccessibilityXXXL` | **hit region** + 2 clipped | 1 clipped only |

Neither runtime is a superset, so the oldest supported OS needs its own run.
This also rules out committing per-screen baseline counts as a regression guard:
no single number is correct on both.

The catch is that **GitHub's `macos-26` image ships only iOS 26.x simulator
runtimes.** It cannot test the 17.6 floor at all. A two-job CI matrix was tried
and produced two near-identical 26.x runs at double the macOS minutes.

So the work is split by what each side can uniquely do:

| | Runtime | Uniquely provides |
| --- | --- | --- |
| **CI** (`.github/workflows/build.yml`) | newest available | A clean checkout of the merge result — catches a file that was never committed, which a local run cannot. Matters here because `DomainDig.xcodeproj` is hand-edited and uses file-system-synchronized groups, where a whole missing folder still builds locally. |
| **Local** (`Scripts/audit-a11y.sh`) | oldest supported + newest | Real floor coverage, on a machine that actually has an 18.x runtime installed. |

Together they cover both ends; neither duplicates the other.

## Running it

```sh
./Scripts/audit-a11y.sh            # floor + current
./Scripts/audit-a11y.sh floor      # oldest supported only (~85s)
./Scripts/audit-a11y.sh current    # newest installed only
```

The script reads the deployment target from the project rather than hard-coding
it, and selects the oldest installed runtime **at or above** it — a runtime
below the deployment target is useless, because the app cannot install there.
If the nearest installed runtime is a major version above the target, it says
so rather than implying floor coverage it does not have.

### Pre-push hook

```sh
git config core.hooksPath .githooks
```

Runs the floor audit before a push, and only when Swift, asset, or project files
changed. Bypass with `git push --no-verify`.

Pre-push rather than pre-commit deliberately: the suite takes ~85s, and at
pre-commit that blocks every commit. A hook routinely bypassed with
`--no-verify` is worse than no hook, because it trains you to ignore it.

## Notes

- **Disabled controls are a false positive, and are suppressed.** WCAG 1.4.3
  exempts inactive components from contrast requirements, but the audit flags
  them anyway — Inspect's Run button is disabled until a domain is typed, and
  auditing the empty state reported a contrast failure that was never a real
  defect. The harness now drops contrast findings whose element reports
  `isEnabled == false`. Suppressing on the rule beats driving the UI to enable
  the control: typing raises the keyboard, which then follows the audit onto
  later screens and flags the system emoji picker's category buttons.
- **A dirty simulator inflates the burndown.** Keyboard state persists across
  runs, so a simulator left with the emoji picker open reports ~9 phantom
  hit-region findings per screen. If findings appear that name system UI
  ("Flags category", "Frequently Used category"), erase the simulator
  (`xcrun simctl erase <udid>`) and re-run before believing them.
- Audits retry up to three times. Slower machines can miss the audit's internal
  deadline (`Audit failed to complete in time`, code `-56`), which is a tooling
  timeout, not an app defect. A screen that still cannot be audited is reported
  as an `XCTSkip`, never a pass — skips are visually distinct in CI, so an
  unaudited screen stays visible instead of being silently counted as clean.
- The suite launches with `DOMAIN_DIG_FORCE_PRO_PLUS` so Pro-gated screens are
  reachable. `PurchaseService` honours that argument in `DEBUG` builds only.
- Everything used is available at the iOS 17.6 deployment floor;
  `performAccessibilityAudit` is `ios(17.0)`.
