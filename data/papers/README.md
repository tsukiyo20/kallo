# Measured papers

`data/papers/` holds one `.kalopaper` per measured paper stock:

| file | what it is |
|---|---|
| `portra_endura.kalopaper` | KODAK PROFESSIONAL PORTRA ENDURA — the normal-contrast reference |
| `supra_endura.kalopaper` | KODAK PROFESSIONAL SUPRA ENDURA — the higher-contrast sibling |
| `endura_premier_metallic.kalopaper` | KODAK PROFESSIONAL ENDURA Premier Metallic — its own sheet and spectra |
| `fuji_crystal_archive_pearl.kalopaper` | FUJICOLOR CRYSTAL ARCHIVE DIGITAL PEARL — the first Fuji paper, and the first on a relative exposure axis |
| `endura_premier.kalopaper` | KODAK PROFESSIONAL ENDURA Premier — the non-metallic sister of the metallic paper, and the contrastiest so far |
| `polymax_ii_rc.kalopaper` | KODAK PROFESSIONAL POLYMAX II RC — black-and-white, and the only paper whose spectra are flat by necessity rather than measured |
| `endura_ultra.kalopaper` | KODAK PROFESSIONAL ULTRA ENDURA — E-4020, the higher-contrast professional paper of the Endura generation |
| `ektacolor_edge.kalopaper` | KODAK EKTACOLOR EDGE — E-7020, the consumer paper with the wider gamut |
| `royal_digital.kalopaper` | KODAK ROYAL Digital Paper — E-7021, the premium consumer paper of the same 2017 family |
| `photo_book.kalopaper` | KODAK Photo Book Paper — E-7027, the thin-base paper with the highest D-max of that family |
| `fuji_pdn.kalopaper` | FUJICOLOR CRYSTAL ARCHIVE PROFESSIONAL SUPER TYPE PDN — the second Fuji paper, and the first read from raster charts |

A paper is a different file from a film on purpose: one characteristic curve
instead of three, a target reflectance instead of a base density, no mask, no
grain and no blur. The format is specified in
[`../films/FORMAT.md`](../films/FORMAT.md#paper-files-kalopaper).

Both former placeholders are gone: `c41_paper` became the Fuji paper, and
`bw_paper` became POLYMAX II RC. There are no invented papers left in the tree.

A note on the black-and-white paper: the model's paper is trichrome by
construction — three dye curves and three layer sensitivities feeding three
density channels — and a silver paper is one neutral record. Its file therefore
carries flat grey absorption and flat layer rows, with the reasoning in the
stock's note. Graded printing (the eight PolyMax filter curves) is not modelled;
the file carries the White Light curve, the softest of the nine.

## The second shelf: the E-40xx and E-70xx sheets

Five papers were added in November 2026. The colour shelf had been five papers
from four dye sets (the E-4021 pair share their spectra, and the Endura Premier
pair have one sheet each); it is now ten from eight.

The four Kodak sheets are the same family as E-4021/E-4070: vector charts with
the characteristic curves, the three dye curves and the three layer
sensitivities, calibrated from the frame and the printed tick marks. Two of them
needed care:

- **E-4020 ULTRA ENDURA** exists in two editions. The June 2004 edition draws its
  dye chart on a 350–700 nm axis; the September 2008 reissue redraws the same
  chart on a 400–700 nm axis while keeping the 350–700 artwork, which lands the
  peaks about 30 nm long. The 2004 edition is the source here, and the
  provenance note says so.
- **E-7020 and E-7021** (EKTACOLOR EDGE and ROYAL Digital, both December 2017)
  draw each curve as many short stroked segments, so the pieces are joined by
  their shared endpoints before they are sampled, and the frame-and-tick
  calibration is what keeps the joined curve on its own axis. Their dye and
  layer charts agree to 0.003 of normalised dye: the two papers share an
  emulsion family and differ in their curves, which is the same shape as the
  E-4021 pair.

**Super Type PDN** (AF3-0236E) is the first paper whose charts are **raster**:
the characteristic curves, the dye curves and the sensitivity curves are
JPEG/PNG artwork inside the PDF, not vector paths. The curve was read from the
grey drawing (mean of R/G/B) with the gridline rows and columns masked out; the
dyes and sensitivities were separated by colour. Its two spectral axes are
*relative* — a printed 0.5 bar on the exposure axis and a 1.0 bar on the
sensitivity axis — so both origins are arbitrary and only the inter-layer
balance is kept, which is what the print balance needs.

Duplicate check, same rule the DPII sheet failed: two papers are added only if
they differ beyond the digitisation noise. The three E-70xx sheets were compared
curve by curve and spectra by spectra; EKTACOLOR EDGE and ROYAL Digital share
their spectra to 0.003 but differ in curve (d_min 0.078 against 0.086, gamma
3.94 against 3.84), and PHOTO BOOK differs in both (its magenta layer peak is
0.99 against 0.87). They stay as three stocks, as PORTRA and SUPRA ENDURA have.

## Sheets that were read and did not become papers

- **Crystal Archive Type II** (technical specs PDF) has the dye and sensitivity
  charts but **no characteristic curves** at all. A paper without its H&D curve
  is half a stock, so it is not here.
- **Crystal Archive Digital Paper Type DPII** (AF3-212E) has all three charts.
  Its curves and spectra agree with the Pearl sheet to within 0.005 of density
  and 0.005 of normalised dye — the two sheets describe the same emulsion on
  different surfaces, and the model has no surface. Adding it would have been a
  duplicate with a different name.
- **Crystal Archive Maxima** (AF3-0252E7, February 2022) and **Crystal Archive
  Supreme** (TMS 2014-06) print the dye and sensitivity charts but no
  characteristic curves: Fujifilm's newer bulletins replaced the H&D plot with
  calibration data. They are half stocks under the same rule as Type II.
- **Super Type C / Type II / DP** US bulletins are only findable as marketing
  leaflets or dead links; the former `fujifilmusa.com/shared/bin` directory now
  serves HTML for every path. A genuine AF3 PDF reached through the Wayback
  Machine is the source for PDN.

The licence is CC BY-SA 4.0, as for the films; the full text is in
[`../films/LICENSE`](../films/LICENSE).
