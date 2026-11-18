import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/model.dart';
import 'package:kallo/lab/stock.dart';

/// A catalogue in the shape `kallo stocks --json` writes, cut down to the keys
/// the app reads. Two films and a paper is enough to prove the document is
/// parsed the way the app reads it; the document itself is the model's, and the
/// integration test asks a real binary for one.
const String _document = '''
{
  "films": [
    {
      "id": "kodak_portra_400",
      "short": "PORTRA 400",
      "label": "KODAK PROFESSIONAL PORTRA 400",
      "process": "negative",
      "note": "Measured: the characteristic curves.",
      "reference": {"minutes": 6.5, "temp_c": 20.0},
      "provenance": {
        "publication": "E-4050",
        "page": "4",
        "retrieved": "2026-11-08",
        "checksum": "sha256:e83a"
      },
      "stock_digest": "sha256:6c6f",
      "measured": [
        {"field": "curves", "claim": "measured", "detail": "page 4, three curves",
         "state": "measured", "grade": 3, "source": "page 4, three curves",
         "locked": true, "advanced_unlock": false, "controls": []},
        {"field": "grain", "claim": "placeholder", "detail": "",
         "state": "placeholder", "grade": 0, "source": "",
         "locked": false, "advanced_unlock": false,
         "controls": [
           {"name": "strength", "value": 1.0, "min": 0.0, "max": 3.0},
           {"name": "size", "value": 1.0, "min": 0.5, "max": 2.0}
         ]}
      ]
    },
    {
      "id": "provia_100f",
      "short": "PROVIA 100F",
      "label": "FUJICHROME PROVIA 100F (RDP III), E-6",
      "process": "reversal"
    }
  ],
  "papers": [
    {
      "id": "fuji_crystal_archive_pearl",
      "short": "CRYSTAL ARCHIVE PEARL",
      "label": "FUJICOLOR CRYSTAL ARCHIVE DIGITAL PEARL PAPER, RA-4",
      "emulsion": "colour"
    },
    {
      "id": "polymax_ii_rc",
      "short": "POLYMAX II RC",
      "label": "KODAK PROFESSIONAL POLYMAX II RC Paper, F surface",
      "emulsion": "silver"
    }
  ],
  "model": [
    {"field": "halation", "claim": "placeholder", "detail": "typical",
     "state": "placeholder", "grade": 0, "source": "typical",
     "applies_to": "film", "locked": false, "advanced_unlock": false,
     "controls": [{"name": "strength", "value": 1.0, "min": 0.0, "max": 2.0}]},
    {"field": "print", "claim": "placeholder", "detail": "the darkroom's choices",
     "state": "placeholder", "grade": 0, "source": "the darkroom's choices",
     "applies_to": "paper", "locked": false, "advanced_unlock": false,
     "controls": [
       {"name": "contrast", "value": 1.0, "min": 0.5, "max": 2.0},
       {"name": "black", "value": 1.0, "min": 0.5, "max": 1.5}
     ]}
  ]
}
''';

void main() {
  final Catalogue catalogue = Catalogue.fromJson(
    jsonDecode(_document) as Map<String, dynamic>,
  );

  test('a stock arrives with its box name, its sheet and its borrows', () {
    final Stock? portra = catalogue.film('kodak_portra_400');
    expect(portra, isNotNull);
    expect(portra!.short, 'PORTRA 400');
    expect(portra.label, 'KODAK PROFESSIONAL PORTRA 400');
    expect(portra.process, FilmProcess.negative);
    expect(portra.referenceMinutes, 6.5);
    expect(portra.referenceTempC, 20);
    expect(portra.provenance.publication, 'E-4050');
    expect(portra.provenance.page, '4');
    expect(portra.measured.map((Measured m) => m.field), <String>['curves', 'grain']);
    expect(portra.measured.first.claim, 'measured');
    expect(portra.measured.first.detail, 'page 4, three curves');
    // A field the file said one word about: the verdict is the whole line.
    expect(portra.measured.last.claim, 'placeholder');
    expect(portra.measured.last.detail, isEmpty);
    expect(portra.stockDigest, 'sha256:6c6f');
    final Measured grain = portra.measured.last;
    expect(grain.verdict, 'placeholder');
    expect(grain.grade, 0);
    expect(grain.locked, isFalse);
    expect(grain.controls.map((Control c) => c.name), <String>['strength', 'size']);
    expect(grain.controls.first.value, 1.0);
    expect(grain.controls.first.max, 3.0);
    expect(portra.measured.first.locked, isTrue);
    expect(portra.measured.first.advancedUnlock, isFalse);
  });

  test('the model carries its own placeholders once', () {
    expect(catalogue.model, hasLength(2));
    expect(catalogue.model.first.field, 'halation');
    expect(catalogue.model.first.controls.single.max, 2.0);
    expect(catalogue.model.last.field, 'print');
    expect(catalogue.model.last.appliesTo, 'paper');
  });

  test('a stock opens only the placeholders of its own half of the shelf', () {
    final Stock film = catalogue.film('kodak_portra_400')!;
    final Stock paper = catalogue.paper('fuji_crystal_archive_pearl')!;
    expect(catalogue.modelFor(film).map((Measured m) => m.field), <String>[
      'halation',
    ]);
    expect(catalogue.modelFor(paper).map((Measured m) => m.field), <String>[
      'print',
    ]);
    expect(
      catalogue.modelFor(paper).single.controls.map((Control c) => c.name),
      <String>['contrast', 'black'],
    );
  });

  test('the shelf groups the films by chemistry', () {
    expect(catalogue.of(FilmProcess.negative), hasLength(1));
    expect(catalogue.of(FilmProcess.reversal).single.id, 'provia_100f');
    expect(catalogue.of(FilmProcess.monochrome), isEmpty);
  });

  test('papers are stocks too, and are looked up the same way', () {
    expect(
      catalogue.paper('fuji_crystal_archive_pearl')?.short,
      'CRYSTAL ARCHIVE PEARL',
    );
  });

  test('the shelf offers the papers a film can be printed on', () {
    // A colour film is never offered a silver paper: the model's print is three
    // channels, and a silver paper has one record, so the print would come out
    // colour — a silver paper that does that is a lie about the paper.
    expect(
      catalogue.papersFor(FilmProcess.negative).map((Stock s) => s.id),
      <String>['fuji_crystal_archive_pearl'],
    );

    // A silver film is offered both, its own paper first, because a silver
    // negative on a colour paper is a print a darkroom does make.
    expect(
      catalogue.papersFor(FilmProcess.monochrome).map((Stock s) => s.id),
      <String>['polymax_ii_rc', 'fuji_crystal_archive_pearl'],
    );

    // A reversal has no print stage at all.
    expect(catalogue.papersFor(FilmProcess.reversal), isEmpty);
  });

  test('a paper without an emulsion is a colour paper', () {
    // The key is optional in the format, and every paper before it was colour.
    final Catalogue old = Catalogue.fromJson(
      jsonDecode('''
{"papers": [{"id": "endura_premier", "label": "KODAK ENDURA"}]}
''') as Map<String, dynamic>,
    );
    expect(old.paper('endura_premier')!.emulsion, isNull);
    expect(
      old.papersFor(FilmProcess.negative).single.id,
      'endura_premier',
    );
  });

  test('a film without a short name is called by its label', () {
    // The `short` key is optional in the format: a file that predates it is
    // still a film, and the wall label falls back rather than showing nothing.
    final Catalogue old = Catalogue.fromJson(
      jsonDecode('''
{"films": [{"id": "fuji200", "label": "FUJIFILM 200 Color Negative Film",
  "process": "negative"}]}
''') as Map<String, dynamic>,
    );
    expect(old.films.single.short, 'FUJIFILM 200 Color Negative Film');
    expect(old.films.single.measured, isEmpty);
  });

  test('no model is no catalogue: the shelf keeps the film it carries', () async {
    final Catalogue carried = await Catalogue.load(const ProcessModel(''));
    expect(carried.films, hasLength(1));
    expect(carried.films.single.id, Stocks.defaultId);
    // The paper the app prints on is carried too: a roll still needs one.
    expect(carried.papers.single.id, Stocks.paper);
    expect(carried.papers.single.short, Stocks.paperShort);
  });
}
