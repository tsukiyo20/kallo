# Tunable parameters: the unknowns become adjustable, the measured ones lock

> Status: a design proposal. This commit adds no code, no data and no interface
> change; the phases are separate pull requests.

Kallo's claim is that its numbers mean something. The stock files already know
which numbers do not: every `.kalofilm` and `.kalopaper` says, field by field,
what was measured, borrowed or left as a compiled placeholder. This proposes to
make that admission readable by a program, and to let a person move the values
that are not this stock's own measurement while the measured ones stay locked.

## The problem: the files know, the program cannot ask

The `[measured]` table is prose: `grain = "placeholder: the sheet prints a Print
Grain Index ..."`, `dyes = "borrowed: the VISION3 500T digitisation ..."`. A
reader understands it; a program cannot ask whether the field may move, rank the
fields by evidence, or close a lock when a measurement arrives. The catalogue
splits the leading verdict off the sentence (`field`, `claim`, `detail`), which
is a sentence splitter rather than a data model.

The data is mixed: of the twenty-four films, fifteen borrow their dye curves
from the VISION3 500T digitisation, sixteen have a placeholder grain, seven
borrow the orange mask, eight borrow the blur, and every film's couplers,
interimage and halation values are compiled placeholders for colour negative in
general. These are numbers a person might want to shape, and none can be, because
the data cannot say which ones may be.

## The principle: lock by evidence, not by the word measured

An adjustable number is still a claim, so the design grades the evidence and
lets the grade decide: **measured** (a sheet, patent or paper, with a page and
checksum in `[provenance]`) beats **estimate** (a figure read off a chart), which
beats **borrowed** (another stock's measured set), which beats **placeholder**
(the model's stand-in). `none` is not a grade: the component does not exist.

- **A default is always the current value.** A control at its default renders the
  stock as the file compiled it; nothing on screen is a suggested replacement.
- **Measured is locked.** The sheet's own number is not a suggestion: the record
  lists it, says what it is, and offers no control for it. Evidence that cannot
  be read fails closed.
- **Only photographically meaningful scalars move.** No raw table becomes a
  slider: not the 71-point dye spectra, not the curves, not the layer
  sensitivities. The modules are grain strength and size, couplers, interimage,
  halation, the borrowed mask, the borrowed blur, and one approximate scalar for
  a borrowed dye set.
- **The lock follows the evidence.** When a measurement arrives the state changes
  and the lock closes by itself.

## What the files admit to today

These are the current `[measured]` counts for the twenty-four films: the
adjustable surface is almost exactly the part of the data that is not this
stock's own measurement.

| field | measured | borrowed | placeholder | none |
|---|---|---|---|---|
| curves | 24 | — | — | — |
| layers | 21 | — | — | 3 |
| dyes | 4 | 15 | — | 5 |
| mask | 9 | 7 | — | 8 |
| MTF | 16 | 8 | — | — |
| grain | 8 | — | 16 | — |
| cl layer | 1 | — | — | 23 |

Some lines are mixed: FUJI PRO 400H's grain is measured for cyan and magenta and
a placeholder for yellow, its CL layer has a measured sensitivity and placeholder
gain, and VISION3 500T's MTF is borrowed from the compiled fit of its own sheet.

The papers are different: every paper has a measured curve; the colour papers
have measured dyes and layer sensitivities and the silver papers carry none (flat
by necessity); and every paper's white is measured — the Pearl's is the toe of
its own curve. Those values are held for films and papers alike. A paper's record
still opens two controls, because they are the model's and not the paper's: the
**print's contrast** and **black level**, the darkroom's choices over the
measured curve. They live in the catalogue's `model` section with
`applies_to: "paper"`, which is also what keeps halation and the couplers off the
paper's page.

## What moves, and what stays locked

| module | the default comes from | today | by default |
|---|---|---|---|
| grain strength | `[character].grains_per_um2`, per layer | placeholder 16, measured 8 | open 16, locked 8 |
| grain size | mean spacing the grain density implies; a lower bound on clump width | placeholder on all 24 | open |
| couplers | `Couplers::typical()`, in code | placeholder on all 24 | open |
| interimage strength | `InterImage::typical()`, in code; only FUJI PRO 400H has a CL layer | placeholder | open, offered only for that film |
| halation | `Halation::typical()`, in code; the reflection width is geometry | placeholder strengths | open |
| borrowed mask strength | the mask table | borrowed 7, measured 9, none 8 | open 7, locked 9, absent 8 |
| borrowed blur sharpness | `sigma_um` | borrowed 8, measured 16 | open 8, locked 16 |
| borrowed dye saturation | the dye tables | borrowed 15, measured 4, none 5 | open 15, locked 4, absent 5 |
| print contrast | the paper's measured curve, as a slope | model placeholder on every paper | open, on papers |
| print black level | the paper's measured curve, as a span | model placeholder on every paper | open, on papers |
| everything else | — | curves, layers, measured dyes and mask, measured MTF, paper curve, dyes, layers and white, CL sensitivity | locked, no control |

The couplers, interimage and halation numbers are not film facts; they are the
model's own placeholders, the same for every stock, and belong under the
catalogue's `model` section rather than in twenty-four files. The controls are few
on purpose: a small vocabulary of scalars, each with a photographic name. Development
time and temperature are already a dimension of the model.

## The header, made readable

The records need a new file version: `film/v2` and `paper/v2`, read the
FORMAT.md way — a v2 reader reads v1 files, and a v1 reader refuses a v2 file.

### A film

The parts that do not change are elided; the sentences are from
`portra-400.kalofilm`.

```toml
schema = "film/v2"
id = "kodak_portra_400"
# [provenance], [character], [development], [curve.*] and [grid] are unchanged.
[measured.grain]
state = "placeholder"
source = "the sheet prints a Print Grain Index and states that it cannot be compared to rms granularity, so the compiled placeholder is used"
strength.value = 1.0
strength.min = 0.0
strength.max = 3.0
size.value = 1.0
size.min = 0.5
size.max = 2.0
[measured.dyes]
state = "borrowed"
source = "the VISION3 500T digitisation, because this sheet prints one mid-scale neutral rather than three dyes"
saturation.value = 1.0
saturation.min = 0.0
saturation.max = 2.0
```

### A paper

A paper's record has no controls, because every value is measured or absent; the
print controls are the catalogue's `model` section and never the stock file. It
keeps the shape, so a paper that later loses a measurement has a place to say so.

```toml
schema = "paper/v2"
id = "portra_endura"
# [provenance], [curve], [character] and [grid] are unchanged.
[measured.curve]
state = "measured"
source = "E-4021 page 7, the mean of three vector curves, transition 7"
[measured.white]
state = "measured"
source = "0.096 status density"
```

`state` is required and closed-vocabulary (a field the vocabulary cannot carry
omits it and stays locked); `source` is the old sentence with the verdict
removed and is never reworded; a borrow names the stock it borrows from in that
sentence. A control is written as `<name>.value`, `<name>.min` and
`<name>.max` under its field: `value` is the control's starting scalar — 1.0 on
every stock today, because a file is its own default — and `min..max` is the
interval a person may move within, written by the packer from the module
definition so a per-stock tightening can later be a data change. A field with
no control omits all three keys.

The model's own placeholders — halation, couplers, interimage — are not in a
stock file: the catalogue carries them once under `model`, in the same shape.

## The catalogue, as the app reads it

`kallo stocks --json` becomes `kallo/catalogue/2`. It stays one document built
from the compiled stocks, and the keys the current app reads are kept (`field`,
`claim`, `detail`) while `state`, `grade`, `source`, `controls`, `locked`,
`advanced_unlock` and `stock_digest` are added — additive for a shipped 0.3 app.

```json
{
  "schema": "kallo/catalogue/2",
  "films": [{
    "id": "kodak_portra_400",
    "stock_digest": "sha256:4f2a...",
    "measured": [{
      "field": "grain", "claim": "placeholder", "detail": "the sheet prints a Print Grain Index ...",
      "state": "placeholder", "grade": 1, "source": "the sheet prints a Print Grain Index ...",
      "locked": false, "advanced_unlock": false,
      "values": { "grains_per_um2": [0.62, 0.51, 0.07] },
      "controls": [
        { "name": "strength", "value": 1.0, "min": 0.0, "max": 3.0 },
        { "name": "size", "value": 1.0, "min": 0.5, "max": 2.0 }
      ]
    }]
  }],
  "papers": [],
  "model": [
    { "field": "halation", "applies_to": "film", "state": "placeholder",
      "grade": 1, "source": "the strengths describe a modern colour negative ...",
      "controls": [{ "name": "strength", "value": 1.0, "min": 0.0, "max": 2.0 }] },
    { "field": "print", "applies_to": "paper", "state": "placeholder",
      "grade": 0, "source": "the print's contrast and black level are the darkroom's ...",
      "controls": [{ "name": "contrast", "value": 1.0, "min": 0.5, "max": 2.0 },
                   { "name": "black", "value": 1.0, "min": 0.5, "max": 1.5 }] }
  ]
}
```

`grade` orders the states without a Dart list: higher is stronger evidence.
`locked` and `advanced_unlock` are the model's decisions and the app draws them.
`stock_digest` is the file's trailing SHA-256 — the one `kallo stock check`
already verifies — so a recipe can say which version it was written against. No
Dart list of fields, controls, ranges or lock rules is added.

## Migrating the prose

1. **The sentence survives.** The text after the verdict becomes `source`
   unchanged, including its particles, em dashes and caveats; the verdict becomes
   `state`, and the sentence keeps the stock a borrow names.
2. **Mixed lines split only where the parts are different components.** A row may
   carry the whole sentence twice with different states, or keep it on the row it
   describes best; a mixed line is not flattened into a half-true state.
3. **Nothing is deleted.** `[provenance].note` stays the long note and the source
   file's `[stock].claim` and `[stock].borrowed` stay the authoring summary; a
   sentence the vocabulary cannot carry keeps its text, is locked, and says why.

## The recipe

A user edit is not a stock file. The `.kalofilm` and `.kalopaper` files stay
read-only data, and `app/assets/film_strip.json` is not a home either — it is the
defaults rendered at a commit by `just view`. The departure is a **stock
recipe**: a separate JSON document, one per stock, recording only the controls
that were moved. JSON because the app already parses it and carries no TOML
parser; the stock files stay TOML because they are authored and packed.

```json
{
  "schema": "kallo/stock-recipe/1",
  "stock": "kodak_portra_400",
  "stock_digest": "sha256:4f2a...",
  "overrides": {
    "grain.strength": { "value": 0.6, "against": "placeholder" }
  },
  "model": {
    "halation.strength": { "value": 0.8, "against": "placeholder" }
  }
}
```

**Digest binding.** Each override records `against`, the grade it was written
against, so a later review can say *this was a placeholder when you moved it; it
is measured now*. The recipe applies only when `stock_digest` equals the digest
of the stock being rendered; the digest covers the whole file, so a repack, a
prose fix and a new measurement all change it. A recipe beside a stock whose
digest has moved is **stale**.

**What stale does.** A stale recipe renders as if it did not exist: defaults are
used, the print is the file's, the bench previews the file's rendering, and the
interface shows a review. The review lists
each override with its old grade, current grade and current control, and offers
remove, reset, or — where the field is now measured — an explicit departure
confirmation against the new digest. The model never silently applies or drops
one; the report is part of the API. `--recipe` with a stale digest exits non-zero;
`--allow-stale` applies only overrides whose field still has the same grade and
prints what it dropped.

**Where they live.** Desktop: `recipes/<stock-id>.json` in the app's support
folder, beside `settings.json` and `library.sqlite`; phone: the app's container.
A print made while a recipe applies carries the recipe's digest in its filename
fingerprint and record; a print made with no recipe keeps the name it has today.

**Command line.** `--recipe <file>` reads a recipe and `--set` builds one in the
open: `kallo render frame.tif -o print.png --film kodak_portra_400 --set
kodak_portra_400.grain.strength=0.6` — the same validation, digest check and
report.

## The default render does not change

- Every control's default is the identity. At `value = 1.0` it multiplies the
  compiled number by one, and the model may skip the multiply when no override is
  present; a render with no recipe is today's render, bit for bit.
- Fixed frames — one colour negative, one reversal, one monochrome, one paper —
  are hashed before phase (a) and must match after phase (b) with no recipe.
  `just view vision3_500t app/assets/film_strip.json` must write the committed
  file unchanged through both: the asset is the defaults rendered.
- The studio goldens are the defaults' instrument and are not regenerated; a
  recipe's rendering is tested against a direct model call with the same scalar,
  which is the stronger check.
- The catalogue only grows keys: a new app reading an old CLI sees no `state`, and
  a print's filename recipe list only gains the stock-recipe digest when a recipe
  applies.

## The interface

The controls live on the stock's record, not on the bench: the shelf is still a
shelf and the bench still holds one print, one time and one strip. The record is
the sheet the `[measured]` table has always promised, and on a window it is a
page of the instrument panel beside the print, one tap from the panel's own
`FILM PARAMETERS` and `PAPER PARAMETERS` lines; a phone has no panel, so there it
is a sheet over the bench. The page is two lists. The first is the controls the
file exposes; the second is the fields the file measured, held, each with the one
word for what it is. There is no bibliography on the page: the sheet's own
`source` and `[provenance]` stay in the catalogue for a program and for review,
not in a slider's paragraph.

The bench's preview is a print, so it carries the recipes: the panel reports a
control while it is still in hand, and the easel beside it renders that print
from the decoded photograph rather than reading a file — a move and its picture
are one gesture. Film and paper have one document each, and a print carries
both; the options in `kallo-core` merge without a collision because the two
documents move different controls. A print already on the test strip is a
developed sheet and does not change; the next development, and the print step's
proof, are the recipes'.

Each control shows its name and current scalar with the file's own value beside
it (`strength, ×0.6; file ×1.0`), its interval, and reset once it has moved.
Reset returns the control to the file. The lock is the model's decision, not an
app rule: a measured field has no control at all, rather than a disabled slider
with a confirmation in front of it. `none` fields are absent rather than shown
disabled. The one approximate colour-film control is a single dye-density or
saturation scalar on a borrowed dye set, labelled approximate because the model
is not claiming this film's dyes.

## When a measurement arrives

1. A data pull request repacks the stock as `film/v2` with the field's `state`
   changed to `measured` and the new document, page and checksum in
   `[provenance]`. The build compiles it, the catalogue exposes the new grade, and
   the stock digest changes.
2. Every recipe written against the old digest is stale: the app shows the review,
   the command line refuses it without `--allow-stale`, and the override on the
   newly measured field is not applied, because its lock is closed and the recipe
   predates the measurement.
3. The person resets the field or explicitly departs from the new measurement;
   either way the next print, and its record, says which. Prints already made are
   files: they are not re-rendered and their wall labels do not change.

Because the state rides on the data, a lock closes itself without an app release.

## Phasing

Phases (a) and (b) are each one pull request, in order; (c) is one data pull
request per measurement.

**Phase (a) — the data says what it knows; nothing renders differently.** Bump
the format to v2 in FORMAT.md; repack every stock file with structured
`[measured.*]` sections, keeping every `source` sentence; teach the build parser
and the CLI file reader to read v1 and v2; extend the catalogue to
`kallo/catalogue/2`; make `kallo stock check` validate the new rows. Tests: a v2
reader reads a v1 file and a v1 reader rejects a v2 file; every control's default
compiles to the field it has today; fixed-frame pixel hashes are unchanged.

**Phase (b) — the record and the recipe.** Add the recipe document and its
reader/writer to the Rust API; add `--recipe`, `--set` and the stale behaviour;
extend the app parser; add the record page with its controls, its held list and
the paper's print controls in the model section, reset, recipe storage and stale
review. Tests: a recipe round-trips; an
unknown control is rejected; a digest mismatch applies nothing; a measured field
needs a departure confirmation; a default render is byte-identical to before the
phase; the CLI report names every departure.

**Phase (c) — tightening, stock by stock.** Each measurement is its own data pull
request: repack one stock with a field moved to measured and let the lock close;
no app or format change. Tests: a fixture whose grain becomes measured exercises
the stale review; the measured-claim tests run over structured rows.

## Open questions

1. **Ranges and coupling.** The ranges come from the module's definition, not
   from a study of what is photographically plausible: can grain strength go to
   zero, should halation's scatter and reflection move together, are couplers and
   interimage independent when both act through the same matrix, and does a
   usable range make the model unphysical? The controls should print the derived
   quantity so a person sees what a number does.
2. **The colour film scalar.** One approximate dye-density or saturation scalar
   is agreed; what it multiplies is not. A multiplier on all three dye
   absorptions moves the borrow as a whole, a saturation of the peaks moves its
   shape, and a matrix between the dyes would be a different claim.
3. **Per layer or one number.** Grain strength, mask strength and blur are all
   per layer in the file. A mean scalar is simpler and is what most people mean;
   per-layer controls are three sliders each and may be a darkroom's idea of a
   control. The first version probably offers the mean and nothing per layer.
4. **Coexistence with the prose.** Keeping the author's sentence as `source` is
   agreed, but some rows mix grades (PRO 400H's grain and CL layer, Pearl's
   white). Whether a mixed row may carry two states needs the data author's
   call, and `[provenance].note` must keep agreeing with the rows.
5. **API stability.** The catalogue is additive now, but `Measured` in the app
   and `FilmStock::measured` in the model have to change shape. The crates are
   in-repository and unpublished, so the internal break is affordable; the file
   format needs the version rule and the catalogue is what the app reads.
6. **Export and sharing.** A recipe is a user document, and a print made with one
   should carry it, because a file that departed from the stock and does not say
   so is the same lie as a borrowed spectrum with no `[measured]` line. The shape
   is open: a digest only, the digest and overrides in the XMP record, or the
   recipe file exported beside the print. Importing one against another build's
   digest raises the stale question again.
