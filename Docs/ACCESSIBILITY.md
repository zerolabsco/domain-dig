# Accessibility Audit

`DomainDigUITests` runs Apple's `performAccessibilityAudit()` across every
primary screen. The audit checks contrast, hit-region size, clipped text at
large Dynamic Type, element descriptions, trait correctness, and Dynamic Type
support — the same ground the accessibility pass tracked in
[issue #21](https://github.com/zerolabsco/domain-dig/issues/21) covers.

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

- Audits retry up to three times. Slower machines can miss the audit's internal
  deadline (`Audit failed to complete in time`, code `-56`), which is a tooling
  timeout, not an app defect. A screen that still cannot be audited is reported
  as an `XCTSkip`, never a pass — skips are visually distinct in CI, so an
  unaudited screen stays visible instead of being silently counted as clean.
- The suite launches with `DOMAIN_DIG_FORCE_PRO_PLUS` so Pro-gated screens are
  reachable. `PurchaseService` honours that argument in `DEBUG` builds only.
- Everything used is available at the iOS 17.6 deployment floor;
  `performAccessibilityAudit` is `ios(17.0)`.
