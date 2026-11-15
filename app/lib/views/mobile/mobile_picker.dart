import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design/mobile.dart';
import '../../design/scope.dart';
import '../../design/strings.dart';
import '../../design/tokens.dart';
import '../../lab/stock.dart';
import '../../widgets/mobile/mobile_controls.dart';
import '../../widgets/mobile/mobile_icon.dart';
import '../../widgets/mobile/mobile_sheet.dart';

/// The film and paper shelves, made into a list a thumb can use.
///
/// The desktop shelf is a taxonomy; a phone picker is a search box, four
/// chemistry filters and rows that are tall enough to hit. The selected stock
/// is a checkmark, not a tiny orange chip in a wall of chips.
Future<Stock?> showKalloFilmPicker(
  BuildContext context, {
  required Catalogue catalogue,
  required String? selectedId,
}) {
  final KalloStrings s = KalloStrings.of(context);
  final List<Stock> films = catalogue.films;
  return showKalloMobileSheet<Stock>(
    context,
    builder: (BuildContext sheetContext) => _StockPicker(
      title: s.film,
      searchHint: s.searchFilms,
      stocks: films,
      selectedId: selectedId,
      groupOf: (Stock stock) =>
          s.processName(stock.process ?? FilmProcess.negative),
      subtitleOf: (Stock stock) => s
          .processNote(stock.process ?? FilmProcess.negative)
          .split(' — ')
          .first,
      filters: <String>[
        s.filterAll,
        s.filterNegative,
        s.filterReversal,
        s.filterMono,
      ],
      filterFor: (int index, Stock stock) => switch (index) {
        1 => stock.process == FilmProcess.negative,
        2 => stock.process == FilmProcess.reversal,
        3 => stock.process == FilmProcess.monochrome,
        _ => true,
      },
    ),
  );
}

Future<Stock?> showKalloPaperPicker(
  BuildContext context, {
  required List<Stock> papers,
  required String? selectedId,
}) {
  final KalloStrings s = KalloStrings.of(context);
  return showKalloMobileSheet<Stock>(
    context,
    builder: (BuildContext sheetContext) => _StockPicker(
      title: s.paper,
      searchHint: s.searchPapers,
      stocks: papers,
      selectedId: selectedId,
      groupOf: (Stock stock) =>
          (stock.emulsion ?? PaperEmulsion.colour) == PaperEmulsion.silver
          ? s.silverPaper
          : s.colourPaper,
      subtitleOf: (Stock stock) => stock.emulsion == PaperEmulsion.silver
          ? s.silverPaper
          : s.colourPaper,
      filters: const <String>[],
      filterFor: (_, _) => true,
    ),
  );
}

class _StockPicker extends StatefulWidget {
  const _StockPicker({
    required this.title,
    required this.searchHint,
    required this.stocks,
    required this.selectedId,
    required this.groupOf,
    required this.subtitleOf,
    required this.filters,
    required this.filterFor,
  });

  final String title;
  final String searchHint;
  final List<Stock> stocks;
  final String? selectedId;
  final String Function(Stock) groupOf;
  final String Function(Stock) subtitleOf;
  final List<String> filters;
  final bool Function(int, Stock) filterFor;

  @override
  State<_StockPicker> createState() => _StockPickerState();
}

class _StockPickerState extends State<_StockPicker> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'stock-search');
  int _filter = 0;

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Stock> get _shown {
    final String query = _query.text.trim().toLowerCase();
    return <Stock>[
      for (final Stock stock in widget.stocks)
        if (widget.filterFor(_filter, stock) &&
            (query.isEmpty ||
                stock.displayName.toLowerCase().contains(query) ||
                stock.maker.toLowerCase().contains(query) ||
                stock.short.toLowerCase().contains(query)))
          stock,
    ];
  }

  List<({String title, List<Stock> stocks})> get _groups {
    final List<({String title, List<Stock> stocks})> groups =
        <({String title, List<Stock> stocks})>[];
    for (final Stock stock in _shown) {
      final String key = '${widget.groupOf(stock)} · ${stock.maker}';
      final int index = groups.indexWhere(
        (({String title, List<Stock> stocks}) group) => group.title == key,
      );
      if (index < 0) {
        groups.add((title: key, stocks: <Stock>[stock]));
      } else {
        groups[index].stocks.add(stock);
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    final List<({String title, List<Stock> stocks})> groups = _groups;
    return KalloMobileSheet(
      title: widget.title,
      height: MediaQuery.sizeOf(context).height * 0.9,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KalloMobileSpace.screen,
              KalloMobileSpace.step2,
              KalloMobileSpace.screen,
              0,
            ),
            child: _SearchField(
              controller: _query,
              focusNode: _focus,
              hint: widget.searchHint,
              onChanged: () => setState(() {}),
            ),
          ),
          if (widget.filters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KalloMobileSpace.screen,
                KalloMobileSpace.step3,
                KalloMobileSpace.screen,
                0,
              ),
              child: KalloSegmented(
                options: widget.filters,
                selected: _filter,
                onSelect: (int index) => setState(() => _filter = index),
                height: 32,
              ),
            ),
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Text(
                      s.noResults,
                      textAlign: TextAlign.center,
                      style: KalloMobileType.footnote.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      KalloMobileSpace.screen,
                      KalloMobileSpace.step3,
                      KalloMobileSpace.screen,
                      KalloMobileSpace.step6,
                    ),
                    itemCount: groups.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ({String title, List<Stock> stocks}) group =
                          groups[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
                            child: Text(
                              group.title.toUpperCase(),
                              style: KalloMobileType.caption.copyWith(
                                color: colors.inkMuted,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(
                                KalloMobileRadius.card,
                              ),
                              border: Border.all(
                                color: colors.hairline.withValues(alpha: 0.75),
                              ),
                            ),
                            child: Column(
                              children: <Widget>[
                                for (
                                  int i = 0;
                                  i < group.stocks.length;
                                  i++
                                ) ...[
                                  if (i > 0)
                                    const KalloMobileDivider(inset: 14),
                                  KalloMobileRow(
                                    key: Key('pick-${group.stocks[i].id}'),
                                    title: group.stocks[i].productName,
                                    subtitle: widget.subtitleOf(
                                      group.stocks[i],
                                    ),
                                    minHeight: 54,
                                    chevron: false,
                                    trailing:
                                        group.stocks[i].id == widget.selectedId
                                        ? KalloGlyphView(
                                            KalloGlyph.check,
                                            size: 18,
                                            color: colors.accent,
                                          )
                                        : null,
                                    onTap: () =>
                                        Navigator.of(context)
                                            .pop(group.stocks[i]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KalloMobileSpace.screen,
              KalloMobileSpace.step2,
              KalloMobileSpace.screen,
              KalloMobileSpace.step4,
            ),
            child: Text(
              s.materialsNote,
              style: KalloMobileType.footnote.copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focusNode.requestFocus,
      child: Container(
        height: KalloMobileSpace.touch,
        padding: const EdgeInsets.symmetric(horizontal: KalloMobileSpace.step3),
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: BorderRadius.circular(KalloMobileRadius.control),
        ),
        child: Row(
          children: <Widget>[
            KalloGlyphView(KalloGlyph.search, size: 17, color: colors.inkMuted),
            const SizedBox(width: KalloMobileSpace.step2),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  EditableText(
                    controller: controller,
                    focusNode: focusNode,
                    style: KalloMobileType.body.copyWith(color: colors.ink),
                    cursorColor: colors.accent,
                    backgroundCursorColor: colors.fillStrong,
                    onChanged: (_) => onChanged(),
                    textInputAction: TextInputAction.search,
                    maxLines: 1,
                    selectionColor: colors.accentSoft,
                  ),
                  if (controller.text.isEmpty)
                    IgnorePointer(
                      child: Text(
                        hint,
                        style: KalloMobileType.body.copyWith(
                          color: colors.inkFaint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  controller.clear();
                  onChanged();
                },
                child: KalloGlyphView(
                  KalloGlyph.close,
                  size: 15,
                  color: colors.inkMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
