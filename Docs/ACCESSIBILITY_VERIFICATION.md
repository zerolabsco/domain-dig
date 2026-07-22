# Accessibility Verification Checklist (issue #21, Phase 6)

Manual verification for the accessibility work in phases 1–5. Everything here is
what the automated audit (`Scripts/audit-a11y.sh`) **cannot** check: VoiceOver
speech, the rotor, custom-content ordering, announcements, Voice Control,
motion/transparency/colour settings, keyboard focus order, and the two system
design languages. A green audit is necessary, not sufficient — this is what makes
it sufficient.

Each item traces to the phase that introduced it (e.g. `[P4]`) so a failure points
straight at the code. Check the box only when the **Expected** line is literally
true on the device.

---

## 0. Setup

### Devices / runtimes

The app supports **iOS 17.6+** and renders under two system design languages:
classic chrome (17.6–25) and Liquid Glass (26+). Materials, surfaces, and
contrast resolve differently between them, so visual passes need both.

- [ ] Primary device on **iOS 26+** (Liquid Glass).
- [ ] A device or simulator on the **floor** (oldest available ≥ 17.6; 18.x is
      the practical minimum since no 17.6 runtime ships). A simulator is fine for
      the visual and Dynamic Type passes; VoiceOver/Voice Control are best on
      hardware.

### Seed data — required, or half the checklist is untestable

Several items only render with tracked domains and a completed lookup. The audit
simulator has none, which is exactly why the dense rows and widget are unverified
so far. Before starting:

- [ ] Inspect tab → run a lookup on a **live** domain (e.g. `cleberg.net`), let
      all sections load.
- [ ] Run a lookup on a domain with a **weak/expiring or missing** cert and
      missing SPF/DMARC, so warning/critical tones and badges actually appear.
- [ ] Track **at least 4** domains with mixed health (one healthy, one warning,
      one critical, one unreachable) so Dashboard tiles, dense watchlist rows, and
      the widget all have content.
- [ ] Run a **Bulk** lookup on ~5 domains so `BatchResultRowView` renders.
- [ ] Add the **Domain Portfolio** widget to the Home Screen in all three sizes
      (small, medium, large).
- [ ] Force the Pro tier if needed so gated screens (Workflows, Scheduled
      Reports, Compare) are reachable.

### Settings map (paths used throughout)

| Setting | Path |
| --- | --- |
| VoiceOver | Settings → Accessibility → VoiceOver |
| Screen Curtain | VoiceOver on → triple-tap with 3 fingers |
| Voice Control | Settings → Accessibility → Voice Control |
| Larger Text / Dynamic Type | Settings → Accessibility → Display & Text Size → Larger Text |
| Bold Text | Settings → Accessibility → Display & Text Size → Bold Text |
| Increase Contrast | Settings → Accessibility → Display & Text Size → Increase Contrast |
| Differentiate Without Color | Settings → Accessibility → Display & Text Size → Differentiate Without Color |
| Smart Invert | Settings → Accessibility → Display & Text Size → Smart Invert |
| Reduce Motion | Settings → Accessibility → Motion → Reduce Motion |
| Reduce Transparency | Settings → Accessibility → Display & Text Size → Reduce Transparency |
| Full Keyboard Access (iPad) | Settings → Accessibility → Keyboards → Full Keyboard Access |
| App appearance override | In-app: Settings tab → Display → Appearance |

> Ordering note: the passes are grouped so each iOS setting is toggled **once**.
> Do them top to bottom to avoid thrashing Settings.

---

## 1. Baseline visual — Light, Dark, System `[P1][P2]`

No assistive tech on. Toggle appearance via **in-app Settings → Display →
Appearance**, then confirm the system setting is also honoured.

- [ ] **System** appearance follows the device; flipping the device Light/Dark
      flips the app.
- [ ] **Light** and **Dark** overrides hold regardless of the device setting.
- [ ] Accent is **blue** everywhere — tab bar selection, links, section titles'
      "info" accents, the Insights icons, the selected quick-filter chip. No
      leftover **cyan**. `[P1]`
- [ ] Warning tone reads as **orange**, not olive/brown — check a "Warning" or
      "Expiring" badge and the Dashboard "Warning" tile. `[P1 rebalance]`
- [ ] The selected Dashboard summary tile is a soft **blue-tinted** surface, not
      lavender/violet. `[P2 wash fix]`
- [ ] Prominent buttons (**Run**, **Run Batch**, **Scan**) show a **white label
      on a blue fill** that is comfortably readable in both schemes. `[P1 AccentFill]`
- [ ] Secondary/detail text (row labels, timestamps, "Monitoring off") is legible
      in **Light** — not washed-out grey. `[P2 AppTextSecondary]`
- [ ] Status badges pair an **icon + text + colour** (e.g. lock + "Valid"),
      never colour alone.
- [ ] Repeat the whole list on the **floor runtime**. Note any Liquid-Glass-only
      difference. `[cross-runtime]`

---

## 2. Dynamic Type & reflow — up to Accessibility 5 `[P3]`

Larger Text → drag to **maximum** (AX5). Walk every primary screen: Inspect
(with results), Dashboard, Audit, History, Settings, Watchlist, a tracked-domain
detail, Workflows.

- [ ] All body text **scales up** (it already did pre-P3; confirm nothing is
      pinned). The Dashboard tile numbers scale too. `[P3 fixed .system(size:)]`
- [ ] **No clipped headings.** Empty-state titles ("No Portfolio Yet", "No Audits
      Yet", "No History Yet", "No Tracked Domains", "No Batch Results Yet") **wrap
      onto multiple lines** rather than truncating with "…". `[P3 Label→HStack]`
- [ ] **No card requires horizontal scrolling.** Inspect result cards, the risk
      card, and detail rows **wrap vertically**; there is no hidden left-right
      gesture to reach content. `[P3 CardView reflow]`
- [ ] Dense rows (`BatchResultRowView`, `WatchlistRowView`) remain **readable** —
      text may be tall but must not overlap the trailing badge or clip. If it
      does, that is the deferred `ViewThatFits` work, not a P3 regression — log it.
      `[deferred]`
- [ ] Every tappable control is at least **44×44pt** at default size. Spot-check
      the **copy buttons** on data rows (the most-repeated control), the
      **collapsible section headers**, and **Run**. `[P3 tap targets]`
- [ ] Turn on **Bold Text**; confirm no layout breaks and contrast holds.
- [ ] **Widget**: at AX sizes the widget content stays readable and is **not
      truncated into nonsense** — it clamps at Accessibility 1 by design. `[P3 widget clamp]`
- [ ] Repeat the clipping/reflow spot-checks on the **floor runtime**.

---

## 3. VoiceOver `[P4]`

Enable VoiceOver. Learn the gestures if needed: swipe right = next element, swipe
up/down on the **rotor** set to "More Content" = reveal extra fields, two-finger
swipe up = read from top.

### 3a. Icon-only controls announce a purpose, not a symbol name

Focus each and confirm the spoken label. **None** should say a raw symbol name
("arrow clockwise", "square and arrow up", "bolt circle").

- [ ] Dashboard toolbar refresh → **"Refresh all tracked domains"**.
- [ ] Inspect toolbar (after a lookup): clear → **"Clear results"**; actions menu
      → **"Actions"**; export menu → **"Export"**.
- [ ] Watchlist: add → **"Add domain"**; filter → **"Filter and sort"**.
- [ ] History filter → **"Filter"**.
- [ ] Timeline grouping → **"Group timeline"**.
- [ ] Workflows: create → **"Create workflow"**; a run summary's export →
      **"Export summary"**; re-run → **"Re-run workflow"**; a shared workflow's
      person icon → **"Shared"**.

### 3b. Toggles announce their state

- [ ] Inspect **Save** (bookmark): label **"Save domain"**, value **"Not saved"**;
      activate → value becomes **"Saved"** and the element reports **selected**.
- [ ] Domain section **Pin**: label **"Pin domain"**, value toggles
      **"Pinned"/"Not pinned"** and reports **selected** when pinned.
- [ ] Audit checklist item: reports **selected** when complete, and a **hint**
      ("Marks complete" / "Marks incomplete").
- [ ] Audit area picker and Workflow domain picker rows report **selected** when
      chosen.

### 3c. Badges and headings

- [ ] A status badge reads as **one word** — "Critical", "Valid", "Secure" — not
      "icon, Critical". `[P4 badge combine]`
- [ ] Set the rotor to **Headings**. Section titles ("Summary", "Risk", "DNS",
      etc.) and the collapsible Inspect section headers are reachable as headings
      and let you **jump between sections**. `[P4 .isHeader]`
- [ ] A collapsible Inspect header announces **"Expanded"/"Collapsed"** as its
      value with a hint, and toggling it updates the value. `[P4]`
- [ ] Confirm the header's **trailing controls** (Track / Pin / Note on the Domain
      section) are still **individually focusable** — they were deliberately *not*
      merged into the header. `[P4 no combine on trailing]`

### 3d. Dense rows — combine + More Content rotor (the flagship)

On the **Watchlist** and a **Bulk** result list, with the rotor on **More Content**:

- [ ] Each row is **one VoiceOver stop**, not eight. `[P4]`
- [ ] The row's **label is the domain**; its **value is the status** (e.g.
      "Registered" / "Critical, Registered").
- [ ] Swiping up/down on More Content reveals the extra fields **in order**:
      - Watchlist row: **Certificate** (spoken first, high importance),
        Monitoring, Updated, Pinned.
      - Batch row: **Risk** (high importance), IP address, Checked, Source,
        Impact/Status.
- [ ] Risk and Certificate are spoken **without** needing the rotor (high
      importance); the rest wait for the swipe.

### 3e. Speech for technical strings

- [ ] Focus a **DNS record value** (Inspect → DNS section) and an SSL **Cipher
      Suite** (Web section). Punctuation (`;`, `~`, `_`, `-`) is **spoken**, and
      the string reads character/token-sensibly rather than as garbled prose.
      `[P4 speechStyle .technical]`
- [ ] Focus a plain prose value (e.g. Issuer common name) and confirm it is **not**
      spelled out awkwardly — only technical rows get the treatment.

### 3f. Completion announcements

- [ ] Run a **single lookup**. On completion VoiceOver speaks **"Lookup complete
      for `<domain>`. `<availability>`."** without you moving focus. `[P4]`
- [ ] Run a **sweep / Check All**. On completion it speaks **"Sweep complete. N
      domains, X changed, Y warnings."** `[P4]`
- [ ] The announcements do **not** fire per-domain during a long sweep (would
      flood the queue) — only once at the end.

### 3g. Widget under VoiceOver

- [ ] A medium/large widget domain row reads as one phrase, e.g. **"example.com,
      critical, certificate expires in 12 days"** (or "pinned", or "certificate
      expired"). `[P4]`
- [ ] The small widget's count pills read **"N healthy"**, **"N warning"**,
      **"N critical"** — not a bare number. `[P4]`

### 3h. Full walkthrough with Screen Curtain

Turn on Screen Curtain (triple-tap, 3 fingers — screen goes black). Complete the
core journey **without looking**:

- [ ] Inspect a domain → hear the sections → **Save** it → open **Watchlist** →
      open its **detail** → back out. Every step is discoverable and every control
      announces a purpose and state. Log anything that leaves you stuck.

---

## 4. Voice Control — label-in-name (WCAG 2.5.3) `[P4]`

Enable Voice Control. Say the **printed** text of controls. Every visible-text
control must respond to its visible name (this is why labels preserve visible
text rather than replacing it).

- [ ] "Tap **Run**" runs the lookup (not broken by a relabel).
- [ ] "Tap **Track**", "Tap **Note**", "Tap **Compare**", "Tap **Cancel**",
      "Tap **Save**" each work by their printed word.
- [ ] Say **"Show numbers"**; confirm the icon-only controls get numbered overlays
      and are operable (they have labels, so they also respond to "Show names").
- [ ] No control is reachable *only* by a name that differs from its visible text.

---

## 5. Colour & contrast settings `[P1][P2][P5]`

### 5a. Increase Contrast

- [ ] Enable. Status colours and the accent shift to their **high-contrast**
      variants; nothing becomes unreadable in either scheme. `[P1 HC variants]`
- [ ] The Settings section headers that were marginal now clear — this is the one
      the audit already measured (light 21 → 18). `[P2]`

### 5b. Differentiate Without Color — the P5 payoff

Enable. This is the pass that validates most of Phase 5.

- [ ] **Dashboard summary tiles**: the small dot becomes a **per-filter symbol**
      (grid, checkmark, triangle, octagon, refresh, clock, wifi-slash). `[P5]`
- [ ] **Selected quick-filter chip** gains a **checkmark + border** — selection no
      longer depends on fill colour alone. `[P5]`
- [ ] **Inspect data rows** with a warning/failure value show a **leading symbol**
      (triangle / octagon) before the value. `[P5 LabeledValueRow]`
- [ ] Turning the setting **off** removes those extras (no permanent clutter). `[P5]`
- [ ] **Widget** status already uses symbols regardless of this setting — confirm
      each row shows checkmark/triangle/octagon, not a bare dot. `[P5]`

### 5c. Smart Invert

- [ ] Enable. UI inverts sensibly; images/icons that should stay un-inverted do.
      Text stays legible. Note anything that inverts wrongly. `[verification]`

---

## 6. Motion & transparency `[P5]`

### 6a. Reduce Motion

Enable. Confirm each animated transition becomes an **instant** state change (no
slide/fade):

- [ ] Copy button check-mark swap (tap a copy button) — flips instantly. `[P5]`
- [ ] Collapsible Inspect section expand/collapse — no ease animation. `[P5]`
- [ ] Timeline scroll-to-section — jumps, no scroll animation. `[P5]`
- [ ] Watchlist list reorder (change sort/filter) — no reflow animation. `[P5]`

### 6b. Reduce Transparency

- [ ] Enable. Trigger the **Data Management** success toast (Settings → Data
      Management → perform a clear). Its pill background is an **opaque surface**,
      not a blur. `[P5]`
- [ ] On **iOS 26+**, confirm system-composited chrome (nav/tab bars) still reads
      acceptably — the app can't declare that translucency itself. `[cross-runtime]`

---

## 7. iPad — Full Keyboard Access & split layout `[verification]`

On iPad (regular width, so `RootTabView` shows the `NavigationSplitView`
sidebar + detail). Enable Full Keyboard Access; attach or use the software
alternative.

- [ ] **Tab** moves focus in a **logical order** — sidebar → detail, top → bottom,
      no traps.
- [ ] The blue **focus ring** is visible on every focusable control.
- [ ] Sidebar tab selection and detail controls are all reachable and operable by
      keyboard.
- [ ] Switching tabs via keyboard updates the detail pane correctly.

---

## 8. Cross-runtime sign-off `[cross-runtime]`

- [ ] Sections 1, 2, 5, 6 re-checked on the **floor runtime** (classic chrome).
- [ ] Sections 1, 2, 5, 6 checked on **iOS 26+** (Liquid Glass).
- [ ] Any behaviour that differs between the two is logged below with the runtime
      noted.

---

## Sign-off

| Pass | 26+ (Liquid Glass) | Floor (classic) | Notes |
| --- | --- | --- | --- |
| 1 Baseline visual |  |  |  |
| 2 Dynamic Type / reflow |  |  |  |
| 3 VoiceOver | n/a-runtime |  | do once on hardware |
| 4 Voice Control | n/a-runtime |  | do once on hardware |
| 5 Colour & contrast |  |  |  |
| 6 Motion & transparency |  |  |  |
| 7 iPad keyboard | n/a |  | iPad only |

## Defect log

Record failures here; each becomes an issue or a fix commit.

| # | Pass / item | Device / runtime | Observed | Expected | Traces to |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |

---

## Known-deferred (not defects — expected gaps)

- **`ViewThatFits` dense-row reflow** was not implemented (unverifiable in the
  audit sim). If §2 shows dense rows overlapping/truncating at AX5 with real data,
  that is this gap surfacing — file it against the deferred item, don't treat it
  as a P3 regression.
- **Live Activity / Dynamic Island** custom accessibility was intentionally not
  added (ActivityKit exposes the labelled `ProgressView` already). Sanity-check a
  running sweep's Live Activity reads acceptably, but a finding here is
  enhancement, not regression.
- **Localization** — all strings are English literals by design for now; a11y
  strings were written `LocalizedStringKey`-compatible for a future catalog.
