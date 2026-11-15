import 'package:flutter/widgets.dart';

import '../design/scope.dart';
import '../design/strings.dart';
import '../design/tokens.dart';
import '../lab/stock.dart';
import 'chip.dart';

/// The shelf, laid on the bench.
///
/// Choosing a film or a paper is taking a box off the shelf, and a box is
/// compared in the print, not in a list: so the shelf is a card on the bench
/// under the print, the same way the edge picker is. The card is the taxonomy
/// the darkroom already has — chemistry, then the maker, then the boxes —
/// because a shelf that changed its shape with the room would be a different
/// shelf each time it was opened.
///
/// The card is as tall as the shelf it holds, up to [maxHeight]; a catalogue
/// larger than that scrolls inside the card rather than pushing the print off
/// the bench. The papers stay at the bottom, where the print's own edge is: the
/// two things a print is made of, in the order the darkroom takes them.
class MaterialsCard extends StatelessWidget {
  const MaterialsCard({
    super.key,
    required this.catalogue,
    required this.filmId,
    required this.paperId,
    required this.time,
    required this.onFilm,
    required this.onPaper,
    this.height,
  });

  final Catalogue catalogue;
  final String filmId;
  final String? paperId;

  /// The development the bench is showing, so the card says what it is
  /// changing the look of.
  final String time;

  final ValueChanged<Stock> onFilm;
  final ValueChanged<Stock?> onPaper;

  /// The most bench a card may take. Beyond this the shelf scrolls.
  static const double maxHeight = 268;

  /// The most bench this card may take; the bench lowers it on a short window
  /// so the print keeps room to be looked at.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    final Stock? film = catalogue.film(filmId);
    final List<Stock> papers = catalogue.papersFor(film?.process);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height ?? maxHeight),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(KalloRadius.card),
          border: Border.all(color: colors.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(
                children: <Widget>[
                  Text(
                    s.materials,
                    style: KalloType.caption.copyWith(
                      color: colors.inkFaint,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    time,
                    style: KalloType.data.copyWith(color: colors.inkFaint),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                children: <Widget>[
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints shelf) {
                      // A narrow bench keeps the boxes readable rather than
                      // three columns of clipped names: three columns when the
                      // card can hold them, two when it cannot.
                      final int columns = shelf.maxWidth >= 620 ? 3 : 2;
                      final double width =
                          (shelf.maxWidth - 16 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: <Widget>[
                          for (final FilmProcess process in FilmProcess.values)
                            SizedBox(
                              width: width,
                              child: _Shelf(
                                catalogue: catalogue,
                                process: process,
                                filmId: filmId,
                                onFilm: onFilm,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(height: 1, color: colors.hairline),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Text(
                        s.paper,
                        style: KalloType.small.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: papers.isEmpty
                            ? Text(
                                s.noPaper,
                                style: KalloType.small.copyWith(
                                  color: colors.inkFaint,
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: <Widget>[
                                    for (final Stock paper in papers)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: KalloSpace.step1 + 2,
                                        ),
                                        child: KalloChip(
                                          label: paper.displayName,
                                          selected: paper.id == paperId,
                                          compact: true,
                                          onTap: () => onPaper(paper),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One chemistry and its makers' boxes.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.catalogue,
    required this.process,
    required this.filmId,
    required this.onFilm,
  });

  final Catalogue catalogue;
  final FilmProcess process;
  final String filmId;
  final ValueChanged<Stock> onFilm;

  List<String> get _makers {
    final List<String> makers = <String>[];
    for (final Stock stock in catalogue.of(process)) {
      if (!makers.contains(stock.maker)) {
        makers.add(stock.maker);
      }
    }
    return makers;
  }

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.processName(process),
          style: KalloType.small.copyWith(color: colors.inkMuted),
        ),
        for (final String maker in _makers) ...<Widget>[
          const SizedBox(height: KalloSpace.step2),
          Text(
            maker,
            style: KalloType.caption.copyWith(
              color: colors.inkFaint,
              fontSize: 9.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: KalloSpace.step1),
          Wrap(
            spacing: KalloSpace.step1 + 2,
            runSpacing: KalloSpace.step1 + 2,
            children: <Widget>[
              for (final Stock stock in catalogue.of(process))
                if (stock.maker == maker)
                  KalloChip(
                    label: stock.productName,
                    semanticLabel: stock.displayName,
                    selected: stock.id == filmId,
                    compact: true,
                    onTap: () => onFilm(stock),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
