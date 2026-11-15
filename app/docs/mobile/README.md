# Kallo on the phone

> Status: **the compact phone shell is built to this plan** (see `app/lib/design/mobile.dart`, `views/mobile/`, `widgets/mobile/`); the desktop studio is unchanged, and every desktop golden passes.
>
> Boards: [workflow](board-1.png) · [printing and the two rooms](board-2.png) · [empty states and settings](board-3.png) · [interactive HTML](mockups.html)
>
> The phone shell as built: [current-select.png](current-select.png)

---

## 0. The direction in one sentence

**Do not shrink the desktop studio. Put the darkroom in a pocket.**

The desktop is organised as two rooms, a drying rack and an instrument panel on the right; the phone should not press that furniture into 390 pt at the same proportions. It should become:

> One subject (a photograph or a sheet of paper), one instrument deck (the 2–3 controls of the current step), and a strip of steps (Select / Develop / Print).

Three rooms, still; three steps, still. What changes is that they no longer appear at once. **The screen answers one question at a time.**

---

## 1. Why the phone is wrong today

The compact branch today is not a phone layout; it is the desktop layout with things taken away:

- `Studio` keeps 56 pt of top chrome and a 52 pt bottom bar at width `< 700`, and takes the sidebar away (`app/lib/views/studio.dart:109`, `:190`, `:330`).
- `SelectStage` turns the desktop work area and inspector into two stacked blocks: the photograph above, `_materials(stacked: true)` below, with the panel taking 46% of the screen height (`app/lib/views/select_stage.dart:105–119`).
- `DevelopStage` / `PrintStage` likewise press the inspector into a bottom panel at 46% / 50% (`app/lib/views/develop_stage.dart:553–561`, `app/lib/views/print_stage.dart:379–389`).
- So a phone holds all of these at once: the status bar, a 56 pt top bar, the content area, a second scrolling panel, and a 52 pt bottom navigation. **The content rarely takes more than half the screen.**

| Problem | What it looks like | Consequence |
|---|---|---|
| Two levels of navigation | a step pill at the top + "Darkroom / Drying rack / Gallery / Settings" at the bottom | the same thing said twice; 56 pt of top bar to hold one pill |
| The panel is the desktop inspector | a fixed 46% / 50% height, scrolling inside | the photograph is small, the controls hide in a second scroll; "To the developer" is not on the first screen |
| Touch targets are too small | buttons 30–36 pt, steppers ± 28 pt, chips about 24 pt, switches 30 pt | below iOS's 44 pt; one-handed taps miss |
| The type sizes are desktop sizes | body 13, small 11.5, caption 10.5; tab bar 10.5 | on a phone it reads like a desktop view scaled down |
| Choosing materials is a "shelf" | all 24 films plus paper laid out flat as chips, wedged into the 46% scroll area | a long scroll to find one film; selection is just an orange chip |
| Landscape falls back to the desktop | the breakpoint only looks at width `< 700`; an iPhone in landscape is 844 pt | a 232 pt sidebar + a 304 pt inspector, leaving about 300 pt of content |
| The rack and gallery are desktop geometry | gallery margins of 40 pt, one huge 35 mm frame per row; the rack fits at most one per row | one per screen; ten prints means ten screens of swiping |
| A loupe that only works on hover | `Gallery._lookAt` brings out the glass on hover; a touch has no hover | the phone's Loupe switch does nothing |
| Settings are a drawer pressed over the workbench | the compact branch is still "horizontal tab rail + page" | not an iOS settings page, and it covers the work being done |
| Changing materials silently clears the strip | `_chooseFilm` / `_choosePaper` / `_setTemperature` replace the strip outright | change film, paper or temperature with prints present and the strip vanishes, with no confirmation |

None of this is fixed by changing a few colours. It all comes from one premise: **the desktop's spatial relations were taken for the product's structure**. The phone needs a structure of its own.

---

## 2. Design principles

1. **One subject.** On Select the subject is the original; on Develop it is the test print being developed; on Print it is the finished print; on the drying rack it is paper; in the gallery it is film. The subject takes most of the screen, and the controls give way.
2. **Two levels of navigation at most.** A room is a bottom tab; a step is a top segmented control; a task is a sheet. Never again a room pill plus a room in the bottom bar.
3. **The main action is always under the thumb.** Each working page has one filled CTA, pinned above the bottom safe area, never hidden in a scrolling panel.
4. **Controls ≥ 44 pt, body ≥ 15 pt.** This is a phone, not a 27-inch display. Desktop type sizes do not enter the compact shell.
5. **Progressive disclosure.** Time, exposure, filters and curves are not piled up on one screen. Curves, material parameters and paper data go into a Details sheet; the main screen keeps only the controls that are present.
6. **Apple's semantics, Kallo's materials.** Use iOS's navigation bar, tab bar, segmented control, sheet, grouped list, 44 pt rows and Dynamic Type; but the colours stay safelight orange, paper warm white and film black, the type stays Inter, and there is never any Material.
7. **An empty state is a door.** Every empty room says what this is, where to go next, and offers one action; empty is not an error.
8. **Destructive actions are said out loud.** Changing the film, paper, temperature or photograph starts a new strip; with prints on the strip, confirm first and say how many will be lost.
9. **The desktop is untouched.** All phone code goes through its own compact shell; the desktop goldens do not change.

---

## 3. Information architecture

```text
Kallo
├─ Darkroom (bottom tab)
│  ├─ Select        ← original + materials
│  ├─ Develop       ← test print + time + strip
│  └─ Print         ← finished print + time/exposure/balance/glass
├─ Drying rack (bottom tab)
│  └─ Print viewer (full screen, no tabs)
├─ Gallery (bottom tab)
│  └─ Frame viewer (full screen, no tabs)
└─ Settings (gear, a whole page as a modal)
   ├─ Appearance
   ├─ Language
   ├─ Library
   ├─ Colour
   └─ About
```

- **Three rooms, not four.** Settings is not a room; it is a whole page opened from the gear, and the bottom bar holds three places only. The tab labels are the short names: `Darkroom` / `Rack` / `Gallery` in English (`Rack`, not `Drying rack`), and two characters each in Chinese rather than the rooms' longer names — the rooms are the same; only the label is shortened so three fit under a thumb.
- **Three steps, not three page stacks.** The segmented control switches steps, and state stays where it is. Come back to the Darkroom from the Gallery and you are still on the step you left.
- **Tasks are sheets.** Film picker, paper picker, temperature, Details, print options, export, confirmation — all sheets; the desktop inspector is not pushed back into the main screen.
- **Viewing is full screen.** Tapping a print on the rack or a frame in the gallery opens a tab-less full-screen viewer; going back keeps the scroll position.
- **Back hierarchy (Android back button / iOS edge swipe):** close the sheet first → then one step back (Print → Develop → Select) → finally leave the Darkroom; a viewer or Settings closes itself first and does not leave the app.

---

## 4. Layout system

### 4.1 Breakpoints

| Shell | Condition | Layout |
|---|---|---|
| **compact (phone)** | `shortestSide < 600`, or a mobile platform with `shortestSide < 700` | this plan; one column, bottom tabs |
| **medium (tablet / narrow window)** | `700 ≤ shortestSide < 1100` | one column, content at most 600 wide, bottom tabs; no sidebar comes back |
| **expanded (desktop)** | `shortestSide ≥ 1100` | the existing desktop studio, completely untouched |

So an iPhone in landscape (844 × 390, shortestSide 390) is still judged a phone shell; v1 also locks phones to portrait (see 4.3) until the landscape workbench lands. An iPad in portrait (768) enters the phone/medium shell, and the two panes (232 + 304) no longer squeeze the content out; a 1280 desktop stays as it is.

> The existing `width < 700` breakpoint falls straight back to the desktop in iPhone landscape. That is the first thing to fix.

### 4.2 The vertical skeleton (390 × 844)

```text
┌──────────────────────────────┐
│ status 47                    │  safe top
├──────────────────────────────┤
│ nav 52  KALLO │ Select/… │ ⚙ │  compact navigation
├──────────────────────────────┤
│                              │
│                              │
│         stage (flex)         │  the subject: photograph / paper / wall
│                              │
│                              │
├──────────────────────────────┤
│ instrument deck 192–236      │  the controls of this step
├──────────────────────────────┤
│ tab bar 49 + safe 34         │  the three rooms
└──────────────────────────────┘
```

- **nav 52**: a 34 pt three-way segmented control, centred; the KALLO wordmark at 9.5 pt on the left; a 44 × 44 gear on the right. No room-name pill.
- **tab bar 49 + 34 safe**: icons 24, labels 10.5; selected is safelight orange, unselected `inkFaint`; a 0.5 pt hairline on top, no shadow. Three tabs, equal.
- **deck 192–236**: not the desktop inspector. Develop is 236 (strip + time ruler), Print is 192 (a 2×2 of controls). Only the controls the step must have; the CTA is pinned to the deck's bottom.
- **stage**: `Expanded`, not 46%. The photograph uses `BoxFit.contain`; paper follows the sheet's proportions; the photograph itself is never cropped.
- **margins 16**: content, cards and CTA are all 16; 24 between sections; 14–16 inside a card.

### 4.3 Landscape (a phone held sideways, second phase)

**The current build locks portrait first**: a landscape window 390 pt tall cannot hold a vertical stage + deck, and dropping the phone back to the desktop's two columns is worse. `main()` on iOS/Android sets
`SystemChrome.setPreferredOrientations([portraitUp, portraitDown])`; the desktop is unaffected. The landscape workbench is the next stage; its structure is already written here:

```text
[nav 44]
[ stage 55% ][ deck 45% ]   ← picture left, controls right
[ tab bar 49 + safe ]       ← kept, icon + label
```

The deck becomes a column on the right, and the strip scrolls horizontally; if the height is short, the deck scrolls inside itself, but the CTA stays pinned to the bottom right. When it lands, the portrait lock comes off.

### 4.4 Sizes and safe areas

- Measure against 390 × 844 (iPhone 12/13/14); check 375 × 667 (SE), 393 × 852, 430 × 932.
- Use the system safe area at the top; the bottom tab bar eats the 34 pt home indicator itself, so the content adds nothing.
- When the keyboard appears: sheets move up; the main screen is not squeezed by the keyboard (all input lives in sheets).
- Status bar icon brightness follows the current stage: light over the darkroom's Develop/Print and viewers, dark over light pages; Android is edge-to-edge, with forced contrast off.

---

## 5. Visual language

### 5.1 Colour

Both sets of values in `KalloColors` are kept; the phone adds only three usage roles — bar, stage, paper — and no brand colour.

| Role | Light | Dark | Use |
|---|---|---|---|
| `ground` | `#F2F2F7` | `#000000` | page / group background |
| `stage` | photo mat `#0B0A09` | same | the black card under originals and the developing table |
| `card` | `#FFFFFF` | `#1C1C1E` | material cards, deck, sheets, settings groups |
| `fill` | `#ECECF0` | `#2C2C2E` | control backgrounds, search field, segmented track |
| `hairline` | `#D6D6DB` | `#38383A` | 0.5 pt dividers |
| `ink` | `#1D1D1F` | `#F5F5F7` | primary text |
| `inkMuted` | `#6E6E73` | `#AEAEB2` | secondary text (the smallest body uses it) |
| `inkFaint` | `#8E8E93` | `#8E8E93` | decoration / non-critical only; 3.26:1 on white, never for required reading |
| `accent` | `#C2410C` | `#FF9F0A` | the only emphasis: primary button, selection, time pointer |
| `accentSoft` | `#FBE9DE` | `#3A2A12` | selected row / selected chip background |
| `paper` | `#FFFCF7` | `#F7F2E9` | paper, always warm white |
| `film` | `#0B0A09` | same | film rebate |

- **bar**: `card` 86% + `BackdropFilter(blur 18, saturate 160%)`, a 0.5 pt hairline at the bottom. No shadow.
- **stage**: the original goes on black card; Develop/Print go on paper, and paper has an object shadow; the page itself is neutral ground. Photographs and paper are objects in the room and may cast a shadow; panels and navigation are flat and cast none.
- **accent does three things only**: the primary CTA, selection, the time pointer. The selected tab is also it. Do not use orange for borders, headings or icon backgrounds.
- **Dark is not one flat black**: nav and tab use 86% black glass, the deck uses `#1C1C1E`; paper stays warm white in the dark.

### 5.2 Type

Still **Inter** (bundled; the goldens use it), no SF Pro, no new face. The phone gets its own closed compact type ramp; the desktop `KalloType` is untouched.

| Role | Size / line height | Weight | Use |
|---|---|---|---|
| `largeTitle` | 32 / 38 | 600, -0.8 | drying rack, gallery, settings |
| `title` | 22 / 28 | 600, -0.4 | sheet titles, empty-state titles |
| `headline` | 17 / 22 | 600, -0.2 | CTAs, list rows, buttons |
| `body` | 17 / 24 | 400 | body text, note paragraphs |
| `callout` | 15 / 20 | 400/500 | material names, control values |
| `subhead` | 14 / 19 | 400 | secondary information, row subtitles |
| `footnote` | 13 / 18 | 400 | required notes (the smallest body) |
| `caption` | 11 / 14 | 500 | tab labels, thumbnail times (not required reading) |
| `plate` | 32 / 36 | 600, tabular | the develop clock |
| `data` | 15 / 20 | 400, tabular | temperature, EV, CC, pixels |
| `micro` | 9.5 / 12 | 600, +1.1 uppercase | film edge text, the smallest metadata |

Rules:

- Only **section headers** and **film-edge text** are uppercase and letter-spaced; buttons, row titles and control labels are sentence case (Chinese takes no capitals).
- All numbers (time, EV, temperature, CC, pixels, print count) are tabular, so the layout does not move when a value changes.
- Dynamic Type up to 1.3×; `largeTitle` may shrink to 1.15× so it does not break the nav; body must reflow, never truncate.
- With Chinese and English set together, give the Chinese a line height of 1.5×; English is looser, and the English must not squeeze the Chinese into two lines.

### 5.3 Spacing, radii, control heights

| Item | Value | Note |
|---|---|---|
| Spacing | 4 / 8 / 12 / 16 / 20 / 24 / 32 | no loose values such as 6, 10 or 14 any more |
| Screen margin | 16 | cards, CTA and content agree |
| Card radius | 16 | material cards, deck, settings groups |
| Control radius | 10 | segmented, chip, search field |
| Action radius | 14 | the 50 pt CTA |
| Sheet radius | 28 | the top two corners |
| Pill | 999 | temperature pill, tags |
| nav | 52 | includes the 34 pt segmented |
| tab bar | 49 + safe | iOS standard |
| CTA | 46–50 | full width, 12 from the deck's bottom; Develop/Print may use 46 |
| Row | 56 | material / film rows; 44 minimum |
| Control | 44 × 44 | steppers, icon buttons, close |
| Thumbnail | 44–58 | strip, time rail |
| Segment | 32 | thirds, 44 pt touch area |

### 5.4 Icons

- The room and step marks keep the existing `_DarkroomMark`, `_RackMark`, `_GalleryMark`, enlarged to 24 pt, stroke 1.6, round caps.
- System symbols (chevron, gear, xmark, search, sun, back, share, check, info) are drawn by hand on the same 24 grid, 1.6 stroke, round caps; no Material Icons, and no relying on SF Symbols.
- An icon always travels with a word (tabs excepted); nothing is left to be guessed.

### 5.5 Materials and depth

- **Navigation / tab**: glass + hairline; no shadow.
- **deck**: card fill + 0.5 hairline; no shadow. It is a control surface, not a floating card.
- **Paper**: the `paper` object shadow is allowed (the existing `KalloShadowBox` paper shadow), because it is paper in a room, not a level of the layout.
- **Rack cards**: paper + a light object shadow + wire + clip; allowed, because it is paper hanging in the air.
- **Film frame**: black rebate, sprocket holes, edge text; kept on the gallery and rack.
- **Segmented selection**: `card` fill + 0.5 hairline, no projection; in the dark, `fillStrong`.

### 5.6 Motion and haptics

| Event | Motion | Haptic |
|---|---|---|
| Step switch | segmented thumb, 160 ms `enter` | selection |
| Open sheet | 240 ms slide up + 32% scrim | light |
| Close sheet | 160 ms slide down | light |
| Choose film / paper | selected row, 90 ms background | selection |
| Drag time | the pointer follows the finger; a slight snap at the ticks | selection (no tick every 0.5 min; only ticks and whole numbers) |
| Development done | the new test print pops in from the bottom, 120 ms fade | success |
| Print done | CTA → toast at the top "Printed" + View | success |
| Error | red text in the row, no dialog | warning |
| Lamp switch | 240 ms change in light level | light |

- Reduce motion: under `MediaQuery.disableAnimations`, drop the sheet offset and the print pop-in, and keep the cross-fade only.
- No looping decorative animation; progress is a 2 pt line or text inside the CTA, never a full-screen spinner.

---

## 6. Screen by screen

### 6.1 Select: the photograph is the page

```text
status 47
nav 52    KALLO      [Select|Develop|Print]      ⚙
stage     ┌──────────────────────────────┐
          │                              │ 320
          │        original              │
          │        (contain)             │
          └──────────────────────────────┘
          IMG_2048.HEIC          4032 × 3024
          MATERIALS
          ┌──────────────────────────────┐
          │ ▣ PORTRA 400              ›  │ 64
          │   Kodak · C-41               │
          ├──────────────────────────────┤
          │ ▤ CRYSTAL ARCHIVE PEARL   ›  │ 64
          │   Fujifilm · RA-4            │
          └──────────────────────────────┘
          ● Metered · 0.0 EV · spectral
CTA 50    [        To the developer        ]
tab 49+34 [ Darkroom ] [ Rack ] [ Gallery ]
```

- The photograph sits on **black card** (`KalloFilm.rebate`), `contain`, never cropped and never stretched to fill. The black card lifts the original out of the page and gives portrait or banner shapes a stable frame.
- A small `ORIGINAL` pill at the top left; a `Change` pill at the bottom right (32 pt, 44 pt touch area); do not turn "change it" into a small orange word in the title bar.
- Under the photograph, the filename and pixels; under that, the `MATERIALS` section header.
- Materials are two rows, not a shelf: film, paper. Row height 64, a 35 pt icon on the left, title 15/600, subtitle 12/400, a chevron on the right; tapping a row opens a full-height picker.
- Exposure is a fact, not a control: one 11 pt line, `● Metered · 0.0 EV · spectral`; not tappable.
- **The CTA is fixed above the tab bar** and does not scroll with the materials: `To the developer`, 50 pt, radius 14; with no photograph it becomes `Choose a photograph…`.
- With no photograph the whole stage is an empty state: a 76 pt rounded icon, a 22 pt title "Start with a photograph", a 13 pt note, the CTA, and one line at the bottom, "Your original is never modified." No second "choose a photograph" anywhere.
- Once there is a photograph the material card appears; if the current strip already has test prints, confirm before changing the photograph, film or paper.
- **Reversal film**: the paper row greys out and shows "This film is its own picture"; `To the developer` still reaches Develop, and the Print step says there is no print to make.
- No model / catalogue not loaded: the material rows show "Film list unavailable", the CTA is disabled with one line of reason; do not pretend there are materials.

**Film / paper picker (sheet)**

```text
          ╭──────────────────────────────╮
          │            Film          ✕   │
          │  🔍 Search 24 films          │
          │  [ All | Negative | Reversal | Mono ]
          │  KODAK                       │
          │  ┌──────────────────────────┐│
          │  │ PORTRA 400             ✓ ││ 56
          │  │ Colour negative · C-41   ││
          │  ├──────────────────────────┤│
          │  │ PORTRA 800               ││
          │  └──────────────────────────┘│
          │  FUJIFILM …                  │
          │  A different film starts a   │
          │  new strip.                  │
          ╰──────────────────────────────╯
```

- A `.large` sheet, about 90% of the height; 28 pt corners at the top; a 5 × 36 grabber; 32% scrim.
- Title 17/600, centred; a 32 pt round `✕` at the top right; search field 36 pt; four filter segments 32 pt.
- Rows 56 pt, grouped by maker (`KODAK` / `FUJIFILM` / `ILFORD`); the maker is a section header and is not repeated in front of every row.
- The row's title is the product name (`PORTRA 400`); the subtitle is chemistry and process (`Colour negative · C-41`). A selected row uses an `accentSoft` background + a checkmark on the right, not an orange chip.
- Tapping a row applies it and closes; there is no second "Done" confirmation. If the strip already has prints, ask `Start a new strip?` first.
- Empty search, no results and an unloaded catalogue each have an inline empty state.
- The paper picker is the same skeleton; it filters to the papers available for the current film first; for a reversal film it shows an explanation rather than an empty list.

### 6.2 Develop: one sheet, one strip, one time

```text
status 47
nav 52    [Select|Develop|Print]      ⚙
stage     ┌──────────────────┐
          │    developed      │  (paper)
          │    test print     │
          └──────────────────┘
          PORTRA 400 · CRYSTAL        Test print
deck 236  ╭────────────────────────────────╮
          │ TEST STRIP  2 prints   New strip│
          │ [6:00] [12:00] [15:00]          │
          │ 12:00                  20.0 °C  │
          │ ├──────●───────────────────────┤│
          │ [        Develop 12:00        ] │
          ╰────────────────────────────────╯
tab 49+34
```

- **The photograph is the test print**: the 1200 px test print for the current time, on warm white paper; the paper has an edge and an object shadow. Tapping the paper opens a full-screen preview (chrome hidden, pinch to zoom), so even though the paper is only 250 pt wide on the main screen, the detail can be read.
- Under the paper there is only one line of material name (12 pt muted) + `Test print`; do not repeat the temperature there — it lives in the deck.
- **The deck is an instrument panel**:
  - The first row is the strip: `TEST STRIP` at 9.5 uppercase + the print count; `New strip` on the right (13, orange, destructive confirmation). Thumbnails 44 × 44, with the time under each at 9 pt; the selected one has a 1.5 pt orange frame.
  - The second row is the clock, 32/600 tabular, + the temperature pill on the right (28 pt, 44 pt touch area). Tapping the temperature opens a `.medium` sheet: a large value, −/+ at 44 pt, a slider, and one line, "Changing temperature starts a new strip"; after setting it, confirm first if there are prints.
  - The third row is the 46 pt time ruler: five ticks at 3/6/9/12/15; dragging follows the finger; values are quantised to 0.5 min; ticks and whole numbers snap with a selection haptic.
  - Last is `Develop 12:00` at 44–50 pt. When a print at that time exists, the label becomes `Re-develop 12:00`, and a text button, "Remove this print", appears beside it (or long-press a thumbnail → context menu).
- **No prints**: the deck puts the strip away and keeps one line, "A test print fixes the exposure.", + `Develop first print`; the paper's place shows the original with a `NOT DEVELOPED` pill on it, not blank paper.
- **Rendering**: keep the previous image; the CTA text becomes `Developing…` and a 2 pt progress shows inside the button; disable the time ruler to prevent repeat taps. No full-screen spinner.
- **Details**: the 32 pt `i` at the stage's top right opens a `.large` sheet for the film curve, the paper curve, Gamma/Dmax and the materials' full names; all the density that the desktop inspector holds lives here, off the main screen.
- **Changing temperature / film / paper**: all of these are "new strip" semantics; confirm when there are prints. The confirmation names the count: `3 test prints will be cleared.` The photograph stays.

### 6.3 Print: four values, one finished print

```text
status 47
nav 52    [Select|Develop|Print]      ⚙
stage     ┌──────────────────┐
          │   finished print  │
          └──────────────────┘
          12:00 · +0.0 EV · Y0 M0 C0 · KG2
deck 192  ╭────────────────────────────────╮
          │ TIME 12:00      EXPOSURE +0.0  │
          │ BALANCE Y0M0C0  HEAT GLASS KG2 │
          │ [            Print            ] │
          ╰────────────────────────────────╯
```

- The finished print is the subject, larger than on the Develop page; under it, one 11–12 pt status line (tabular) lets you confirm the current combination at a glance.
- The deck is a **2 × 2 summary of controls** (192 high), not four stacked steppers:
  - `TIME 12:00`, `EXPOSURE +0.0 EV`, `BALANCE Y0 M0 C0`, `HEAT GLASS KG2`.
  - Each cell is 54 high; the label is 9 pt uppercase, the value 14.5/600, with a chevron at the bottom right; the touch area is 54.
  - Tapping any cell opens its sheet, and **the finished print stays visible on the main screen**:
    - Time: the current strip's test prints (thumbnail + time); pick one.
    - Exposure: a `.medium` sheet, a large −/+ at 44 pt, 0.1 EV steps, range ±2; updates live while dragging.
    - Balance: three rows, Y/M/C, each with −/+ at 44 pt, steps of 5; a Reset at the top.
    - Heat glass: a `None / KG1 / KG2 / KG3 / KG5` list, 44 pt rows, with one line of explanation.
- `Print` opens the print options sheet: size (Original / 6000 / 4000 px) and format (PNG/JPEG/TIFF), each row 56, with `Print` at the bottom. The options sheet shows the expected pixels and file type.
- While printing: the CTA says `Printing…` and the controls are disabled; on success a toast at the top, `Printed` + `View`, and View goes to the drying rack; on failure one red line above the CTA, no dialog.
- No prints: the whole page is an empty state + `To the developer`; do not leave the Print step tappable and empty.
- Reversal: there is no Print; the Print segment in the step control shows as unavailable and says why.
- Details: the same sheet as Develop, showing the paper curve for the current settings.

### 6.4 Drying rack: two columns of paper

```text
status 47
nav 98    Drying rack                     ⚙
          4 prints · newest first
content   ┌─────────┐  ┌─────────┐
          │ 01 15:00│  │ 01 13:30│   two columns
          │ paper   │  │ paper   │
          └─────────┘  └─────────┘
          ┌─────────┐  ┌─────────┐
          │ 01 12:00│  │ 01 10:30│
          └─────────┘  └─────────┘
tab
```

- A large title at 32/600, the subtitle "4 prints · newest first"; the gear at the top right.
- 2 columns, margin 16, gap 12; each sheet is about 171 wide, following the original's proportions, never cropped to a square.
- A card = paper + a 6 pt white edge + 0.5 hairline + object shadow + a 9 × 13 clip at the top + a 1 pt wire; the wire is the room's, not a divider.
- Under the image, at 10 pt: `01 · 15:00` (tabular) + the film's short name; no meaningless "1 of 1".
- A job still developing sits at the top as one `Developing 15:00…` card with a 2 pt progress; it does not block the list.
- Empty state: the wire + a clip icon, `Nothing on the rack`, `Make a print in the darkroom. It will hang here while it dries.`, `Open the Darkroom`.
- Tap one → full-screen viewer: black, a 44 pt back/title/export bar at the top, the image `contain`, pinch to zoom, double-tap 1:1, swipe down to close; material/time/temperature/date at the bottom; no tab bar.
- The desktop's existing `Rack` geometry (138 pt wire, 28 pt margins, 260 max width) stays for the desktop; the phone gets the new grid.

### 6.5 Gallery: a wall

```text
status 47
nav 98    Gallery                        ☀
          4 prints · one lamp
content   ┌─────────┐  ┌─────────┐
          │ film 01 │  │ film 02 │   two columns of 35 mm
          │         │  │         │
          └─────────┘  └─────────┘
          ┌─────────┐  ┌─────────┐
          │ film 03 │  │ film 04 │
          └─────────┘  └─────────┘
tab
```

- A large title + subtitle; the light is **one sun icon** at the top right, not two text pills reading "Loupe" and "Light". The Loupe switch is removed on the phone.
- 2 columns of film frames, margin 16, gap 12; a frame is about 171 wide, with a 9 pt black rebate, 4 pt sprocket holes on both sides, and 4.5 pt edge text that is texture only and not meant to be read.
- A column may run unevenly (portrait frames are taller); no uniform squares — film is film.
- With 1 print: a single frame, centred, max width 420; with 2 or more: 2 columns. Empty wall: a wire + an empty-frame icon, `An empty wall`, `Prints you make will hang here.`, `Make a Print`.
- Tap one → full-screen 35 mm viewer: the frame fits, the picture zooms inside the gate with pinch (1:1 ceiling), back/title/export at the top, pixels + zoom percentage at the bottom; no mouse-hover glass, touch uses pinch + double-tap.
- Lamp: one switch changes the wall's `light` and the paper's brightness; with the lamp off the wall is black and labels fall to 10%, while the window frame and the back button remain. Motion 240 ms.
- Sorting is still newest first; if the list is empty when the gallery opens, show the empty state, not an empty wall.

### 6.6 Settings: a whole page, not a drawer

```text
status 47
nav 48    Settings                    Done
content   APPEARANCE
          ┌──────────────────────────┐
          │ Interface [System|Light|Dark] │
          └──────────────────────────┘
          LANGUAGE
          ┌──────────────────────────┐
          │ Follow the system      ✓ │
          │ English                  │
          │ Chinese                  │
          └──────────────────────────┘
          LIBRARY
          ┌──────────────────────────┐
          │ Location      Kallo album ›│
          │ Import images            ›│
          │ Repair markers  Up to date│
          └──────────────────────────┘
          RENDERING
          ┌──────────────────────────┐
          │ Graphics                  │
          │  Adreno 730 (Vulkan)      │
          │ Processor                 │
          │  Snapdragon · 8 cores    │
          │ Engine          [GPU|CPU] │
          └──────────────────────────┘
          COLOUR
          ┌──────────────────────────┐
          │ Spectral path        [on] │
          └──────────────────────────┘
          ABOUT
          ┌──────────────────────────┐
          │ ▣ Kallo 0.1.0           › │
          └──────────────────────────┘
```

- Pushed in from the gear in any room, it covers the whole page; the top 48 nav has the title 17/600 centred and `Done` 16/500 in orange on the right.
- A grouped background + cards with 12–16 radius; section headers 11 uppercase; rows 44, primary text 15, secondary 11–13; dividers inset 14.
- Language uses checkmark rows (`Follow the system` / `English` / `Chinese`), not a segmented control; `Interface` is a 30 pt segmented control (System / Light / Dark) at the right of its row; the spectral path is a 47 × 28 native switch.
- Rendering is the only page that talks about hardware: the graphics line names the adapter wgpu will open (the same probe), and the processor line names what the system is willing to give plus the core count (Android may not give a name, and then only the count is shown). The engine defaults to GPU; switching to CPU stops trying the adapter, and a GPU error still finishes that one print on the CPU.
- On the phone, Library has no "choose folder" any more; it shows the system location (the `Kallo` album on iOS, `Pictures/Kallo` on Android), import and repair status, and a note when iOS grants only partial access.
- Footnotes appear only where they are needed: the spectral path changes new strips and leaves existing ones alone; a phone cannot choose a folder.
- Leave 24 pt at the bottom, clear of the home indicator; the content scrolls, and does not nest a sheet's scroll.

---

## 7. Component specs (build to these)

| Component | Spec |
|---|---|
| `MobileNavBar` | 52 high; segment 34 high, 3 equal parts, track `fill`, selected `card` + 0.5 hairline; gear 44 × 44; 16 on both sides; glass + hairline |
| `MobileTabBar` | 49 + safe; 3 equal parts; icons 24, labels 10.5; selected accent; top hairline; no shadow |
| `MobileStageTabs` | 3 segments; touch area ≥ 44; `Semantics(selected:)`; step switch 160 ms |
| `MobileCTA` | 50 high, radius 14, accent, onAccent, 17/600; disabled fill; min width 200 |
| `InstrumentDeck` | 12 on both sides, 12 at the bottom, 192–236 high, radius 16, card, hairline; 10–14 padding inside; CTA pinned to the bottom |
| `TestStrip` | horizontal scrolling; thumbnails 44–58; selected 1.5–2 pt accent frame; long-press context menu; no scrollbar |
| `TimeRuler` | 46–54 high; track 1 pt; ticks 8 pt; knob 16–28; touch height ≥ 44; 0.5 min quantised; ticks selection |
| `AdjustmentCell` | 54 high; label 9 uppercase; value 14.5/600; chevron 14; tap opens a sheet |
| `MobileSheet` | top radius 28; grabber 5 × 36; scrim 32%; medium/large detents; drag down to close; keyboard aware; `PopScope` |
| `PickerRow` | 56 high; title 15/600; subtitle 11.5; selected accentSoft + check; divider inset 14 |
| `SettingsGroup` | 12–16 radius; rows 44; header 11 uppercase; footer 10.5–13; switch/segments use native semantics |
| `EmptyState` | icon 76 on a rounded background; title 22; body 13; CTA 50; at most two lines of note |
| `Toast` | 12 above the bottom tab bar; pill card; 17/500; disappears after 4 s; carries one action |
| `PrintCard` (rack) | paper white, 6 pt edge, 0.5 hairline, object shadow, clip, wire; the image is never cropped |
| `FilmFrame` (gallery) | keep the existing 35 mm geometry; shrink it to 171 wide on the phone; edge text is texture only |
| `Viewer` | full screen, black; 44 at the top; pinch zoom, double-tap 1:1, swipe down to close; metadata at the bottom; no tab bar |

---

## 8. Interaction and state

### 8.1 Destructive confirmations

| Action | Condition | Confirmation |
|---|---|---|
| Change the photograph | prints on the strip | `Replace the photograph?` · `N test prints will be cleared. The film and paper stay.` |
| Change the film | prints on the strip | `Change the film?` · `N test prints will be cleared. The photograph and paper stay.` |
| Change the paper | prints on the strip | `Change the paper?` · `N test prints will be cleared. The photograph and film stay.` |
| Change the temperature | prints on the strip | `Change the temperature?` · `Temperature belongs to the strip; N test prints will be cleared.` |
| New strip | prints on the strip | `Start a new strip?` · `N test prints will be cleared. The photograph and materials stay.` |
| Remove print | a selected test print | long-press → context menu; or an inline text button; removed directly, and another can be made |
| Repair markers | repairable items | run directly, toast when done |

Confirmations use the iOS action-sheet shape: a title + one line of explanation + a red destructive + Cancel; no Alert with a paragraph.

### 8.2 Back

- Android back button: sheet → close; viewer/Settings → close; Print → Develop → Select; back again exits.
- iOS: sheet pulls down; viewer/Settings swipe in from the edge; steps do not intercept the edge gesture (so they do not fight the system back).
- Closing a sheet restores the focus/scroll position of the control that opened it.

### 8.3 Loading, errors, empty

| Case | Handling |
|---|---|
| Photograph decoding | a 2 pt progress line on the black card; no "please wait" paragraph |
| Photograph failed to decode | one error line inside the card + `Choose another` |
| Catalogue not loaded | material rows as a skeleton; CTA disabled; one line of reason |
| Developing the preview | keep the old image; 2 pt progress at the paper's corner; the CTA's text changes |
| Development failed | one red line above the CTA; keep the current test print; can retry |
| Printing | CTA `Printing…`; controls disabled; success toast |
| Print failed | red line in place + retry; current settings are not lost |
| No test prints | empty state + go to Develop |
| The rack is empty | empty state + go to the Darkroom |
| The gallery is empty | an empty wall + go to Print |
| Library permission limited | the settings/library rows explain; do not pretend all photographs are there |
| No network | nothing depends on the network; only a failed GitHub link is handed to the system |

### 8.4 Accessibility

- Every tappable element ≥ 44 × 44; when a thumbnail is 44, use an 8 pt outer margin to extend the hit area.
- The custom slider provides `Semantics(slider, value)` and `increase/decrease` actions; time readings use `darkroomClock`.
- The step segmented control provides `selected`; a material row provides "Film, PORTRA 400, Colour negative".
- Contrast: body uses `inkMuted` or darker; `inkFaint` is decoration only. Accent on white 5.18:1, onAccent 5.18:1; dark 10.22:1.
- At Dynamic Type 1.3× the deck may scroll and the CTA is not pushed away; text is never truncated to "…" where it carries a key value.
- VoiceOver order: the stage subject → the deck's controls → the CTA → the tab bar.
- Reduce motion: sheets fade in, prints do not pop in; no parallax.

### 8.5 Language and copy

- The app has two languages: English and Chinese. Settings offers three options — `Follow the system`, `English`, `Chinese` — and the words follow the choice.
- The Chinese tabs are two characters each where English needs `Darkroom` / `Rack` / `Gallery`; the shorter labels are why both languages fit the same three-slot bar, and the layout is measured against the longer English labels.
- Buttons are verbs: `To the developer`, `Develop`, `Print`, `Choose a photograph…`, `Open the Darkroom`.
- Destructive buttons name the thing: `Start a New Strip`, never `OK`.
- Technical words stay: `C-41`, `RA-4`, `EV`, `CC`, `KG2`, `Gamma`, `D-max`, `sRGB`; numbers are not translated in either language.
- English is sentence case; Chinese takes no capitals and no spaces between its characters. Film names keep the maker's spelling in both languages.
- The words live in `app/lib/design/strings.dart`, in two tables, English and Chinese; the film's own vocabulary never translates, and switching language moves no layout.

---

## 9. Implementation mapping

### 9.1 New / modified

```text
app/lib/
  design/
    mobile.dart             ← KalloLayout, compact type/spacing/radius/heights
    strings.dart            ← the phone's labels and empty-state copy (Chinese and English)
  views/mobile/
    mobile_picker.dart      ← searchable film/paper picker
    mobile_settings.dart    ← grouped, full-page Settings
  widgets/mobile/
    mobile_chrome.dart      ← darkroom bar, room header, three-slot tab bar
    mobile_controls.dart    ← buttons, segments, switches, rows, groups, empty states
    mobile_icon.dart        ← 24-grid hand-drawn icons, no Material
    mobile_sheet.dart       ← sheet, confirm, choice, full-screen viewer
  views/
    studio.dart             ← only adds the compact branch; the desktop path is untouched
    select_stage.dart       ← compact branch: original + two material rows + picker
    develop_stage.dart      ← compact branch: paper + strip + clock/ruler/CTA
    print_stage.dart        ← compact branch: 2×2 controls + print options
    rack.dart / gallery.dart ← compact grid, empty states, viewer callbacks
  main.dart                 ← portrait lock on phones; callback API unchanged
```

- `Studio`: `_compact` becomes `KalloLayout.isCompact(context)`; compact returns `MobileStudio` directly and **no longer enters the existing sidebar/StudioTopBar/StageTabs path**. The desktop still goes through the original `_shell`.
- The phone's stages use the existing `TestStrip`, `Print`, `Catalogue` and `ui.Image` data; no model logic is copied, and the callback signatures in `main.dart` are unchanged.
- The picker sheets are implemented by `MobileStudio` with `Overlay` + `AnimationController`; not Material's `showModalBottomSheet` (which would bring in Material semantics/theme).
- The existing `KalloShadowBox` paper/sheet assets stay in use for paper and sheets; the deck and nav do not use them.
- `Rack` / `Gallery`: the desktop implementation is untouched; the phone gets new `rack_view` / `gallery_view` that reuse the zoom/preview core of `Print`, `PrintThumbnailCache`, `FilmFrameMetrics` and `PrintViewer` (the pure image logic is extracted; the decode logic is not copied).
- `SettingsDrawer`: kept on the desktop; the phone gets a new `settings_view` that reuses `ExportSetting`, `Settings` and `AppInfo`.
- Phone status bar: `AnnotatedRegion<SystemUiOverlayStyle>`; on Android, `SystemChrome.setEnabledSystemUIMode(edgeToEdge)` already has a configuration check.
- Performance: `BackdropFilter` is used only on the 52 pt nav and the 83 pt tab bar, never on a whole page or a whole photograph; the rack and gallery keep going through `PrintThumbnailCache` (512 thumbnails + the viewer's preview/detail two levels), so a two-column grid does not decode more originals; sheet animations change only transform/opacity, avoiding a whole-page relayout.

### 9.2 Phases

| Phase | Content | Done when |
|---|---|---|
| **1. Shell and tokens** | breakpoints, `MobileStudio`, nav/tab/step/CTA/sheet, the 44 pt baseline | three empty tabs switch on 390 × 844; iPhone landscape no longer shows the desktop's two columns; the desktop goldens are unchanged |
| **2. Select** | original on black card, two material rows, picker sheet, empty state, destructive confirmations | the photograph, materials and CTA fit in one screen; no 24 chips; material changes confirm first |
| **3. Develop** | test print as the subject, deck, time ruler, strip, temperature/Details sheets | paper, time, prints and CTA fit in one screen; dragging is smooth; curves are off the main screen |
| **4. Print** | 2×2 controls, four sheets, print options, success toast | all four values change and the image updates live; Print needs no panel scrolling |
| **5. Rack / Gallery / Viewer** | two-column grid, empty states, lamp, pinch viewer, no hover loupe | at least two papers/frames per screen; the viewer zooms and returns |
| **6. Settings / landscape / accessibility** | grouped settings, landscape workbench, Dynamic Type, VoiceOver, haptics | no overflow at 1.3×; landscape does not crash; tab/sheet back is correct |

### 9.3 Tests

- New widget tests under `app/test/mobile/`:
  - the three sizes 390 × 844, 375 × 667, 430 × 932; light/dark;
  - every tappable element ≥ 44 (walking semantics/rect);
  - text scaling 1.3 does not overflow;
  - the Android back hierarchy;
  - changing film/paper/temperature with prints present asks for confirmation;
  - an empty state's CTA reaches the next step;
  - sheets close by pulling down or tapping the scrim.
- New phone goldens: `test/goldens/macos/mobile/{select,develop,print,rack,gallery}.png`, drawn with the synthetic test card, with no photographs of people. They use the existing `studio-goldens` opt-in.
- Integration test: on iPhone/Android, drive a **synthetic picture** through Select → film → paper → develop 3/6/9 → print → drying rack → gallery → settings; personal photographs never enter the repository.
- Desktop: the existing 12 macOS goldens and the widget tests all pass; the 7 CI checks all pass.

### 9.4 Not doing

- Not changing the model's mathematics, data files, XMP or catalogue; PhotoKit/MediaStore are adjusted only in Android permission timing.
- Not changing the desktop layout, the desktop sidebars or the desktop goldens.
- Not introducing `MaterialApp` / `Material` / `CupertinoApp` / `CupertinoPageScaffold`; not introducing a new font.
- Not swapping safelight orange for the system blue just to "look like iOS"; Kallo's accent is safelight.
- Not making the phone a responsive reduction of the desktop studio; the phone is a shell of its own.
- Not building an iPad-specific layout in this version; medium only has to not break, be readable, and stay one column.

---

## 10. Acceptance checklist

- [ ] At 390 × 844, the subject area of Select/Develop/Print is at least 50% of the content height; the photograph/paper itself is ≥ 280 pt (Select ≥ 300 pt); the CTA is visible on the first screen without scrolling.
- [ ] No tappable element is < 44 × 44; body ≥ 15, required notes ≥ 13.
- [ ] The top bar holds one step control only; the bottom bar holds three rooms only; there is no room-name pill.
- [ ] In iPhone landscape (844 × 390) there is no desktop sidebar/inspector; at least one operable column remains.
- [ ] Choosing film/paper is a 56 pt row + search + chemistry grouping, not 24 chips.
- [ ] Changing film/paper/temperature/photograph confirms first when prints exist, and says how many will be cleared.
- [ ] The main Develop screen holds only paper, time ruler, strip and CTA; curves are in the Details sheet.
- [ ] The four Print values are visible at a glance; tapping any opens a sheet and the picture stays visible; Print opens the options sheet.
- [ ] The rack and gallery are 2 columns on the phone; a single frame is centred on the wall; the empty states have a CTA.
- [ ] The phone has no Loupe switch; the viewer supports pinch, double-tap 1:1, and swipe down to close.
- [ ] Settings is a whole-page grouped list, not a horizontal tab rail + drawer.
- [ ] 1.3× type does not overflow; VoiceOver can read steps/materials/time/CC/lamp.
- [ ] The 12 desktop goldens are unchanged; CI is green.

---

## 11. Decided

1. **A bottom bar with 3 rooms + a gear**; Settings is not a room.
2. **The gallery is 2 columns of film**; with one frame it is still a single centred frame.
3. **Changing film/paper/temperature/photograph confirms first when there are prints**; the copy says how many will be cleared. The desktop keeps its current behaviour; whether it follows is a separate change.

One implementation-level decision is recorded here too: an Android Adreno 730 caps a single storage buffer binding at 128 MiB, and a 12 MP print is 195 MiB, so the old implementation hit a wgpu validation error in `create_bind_group` and fell back to the CPU. The GPU backend now renders frames larger than the binding limit in horizontal bands, with enough guard rows above and below the band for the vertical effect, and the body rows are bit-for-bit identical to a whole-frame render (Rust has a comparison test); `FfiModel.develop`'s CPU retry remains as the fallback for driver faults. When the preview session (`PreviewBench`) fails, the Develop and Print pages still fall back to a one-off CPU render.

Android photo permission is on demand too: the app reads the state at launch and shows no dialog; the first time `Choose a photograph…` is tapped, it explains in its own sheet that what the permission buys is sight of pictures other apps put in `Pictures/Kallo`, not the choosing itself, and only after agreeing does the system dialog appear; `Not now` still opens the system picker. The settings page keeps a `Photo access` row, and a permanent denial goes through system settings.

---

## 12. References

- The existing design rules: `app/README.md` (no Material, no layout shadows, one accent, closed spacing/radius/type ramps, the film is geometry).
- The existing desktop goldens: `app/test/goldens/macos/`.
- The existing compact branch: `app/lib/views/studio.dart`, `select_stage.dart`, `develop_stage.dart`, `print_stage.dart`, `gallery.dart`, `rack.dart`, `drawer.dart`.
- The boards for this plan: [board-1.png](board-1.png), [board-2.png](board-2.png), [board-3.png](board-3.png), [mockups.html](mockups.html).

> The boards are a direction, not final pixels: 390 × 844, Inter, real type sizes and touch targets. When building, the closed tokens of section 5 are the authority; the desktop does not move. The current implementation passes `flutter analyze`, the full widget tests and the 12 desktop goldens; the phone tests live in `app/test/mobile_test.dart`.
