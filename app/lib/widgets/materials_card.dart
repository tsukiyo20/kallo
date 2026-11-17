import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/scope.dart';
import '../design/strings.dart';
import '../design/tokens.dart';
import '../lab/stock.dart';
import 'mobile/mobile_icon.dart';
import 'segments.dart';

/// Which half of the shelf is lying on the bench.
enum MaterialsKind { film, paper }

/// The shelf, laid on the bench.
///
/// The shelf is not a chip wall: twenty-four films and fourteen papers do not fit in
/// a card that also has to leave the print its room. So the card is a drawer
/// with one half open at a time — the film half or the paper half — and each
/// half is a flat list: a search field, the chemistry as the group heading, and
/// rows that carry the whole name of the box — maker and product — in one line,
/// with the chosen box a check mark on its row. The print above the card is the
/// preview: taking a box off the shelf is a comparison, not a form.
///
/// The card is opened by the thing it changes. The materials line under the
/// print is two handles — `film` and `paper` — and each lays the card on the
/// bench with its half open.
class MaterialsCard extends StatefulWidget {
  const MaterialsCard({
    super.key,
    required this.catalogue,
    required this.filmId,
    required this.paperId,
    required this.time,
    required this.kind,
    required this.onKind,
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

  /// Which half is open, and the way to open the other one.
  final MaterialsKind kind;
  final ValueChanged<MaterialsKind> onKind;

  final ValueChanged<Stock> onFilm;
  final ValueChanged<Stock?> onPaper;

  /// The most bench a card may take. Beyond this the shelf scrolls.
  static const double maxHeight = 340;

  /// The most bench this card may take; the bench lowers it on a short window
  /// so the print keeps room to be looked at.
  final double? height;

  @override
  State<MaterialsCard> createState() => _MaterialsCardState();
}

class _MaterialsCardState extends State<MaterialsCard> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _search = FocusNode(debugLabel: 'shelf-search');

  /// Which chemistry is shown: all of them, or one. The shelf opens on the
  /// chemistry of the film in the enlarger, because that is the shelf a person
  /// is standing at.
  int _filter = 0;

  /// The chosen row, so a card opened on a long shelf can start at it.
  final GlobalKey _chosen = GlobalKey(debugLabel: 'shelf-chosen');
  bool _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    _filter = _chemistryOf(widget.filmId);
    _scheduleReveal();
  }

  @override
  void didUpdateWidget(MaterialsCard old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) {
      _query.clear();
      _search.unfocus();
      _filter = widget.kind == MaterialsKind.film
          ? _chemistryOf(widget.filmId)
          : 0;
      _scheduleReveal();
    } else if (old.filmId != widget.filmId || old.paperId != widget.paperId) {
      _scheduleReveal();
    }
  }

  /// The shelf's filter for a chemistry: 0 means all of them.
  int _chemistryOf(String filmId) =>
      switch (widget.catalogue.film(filmId)?.process) {
        FilmProcess.negative => 1,
        FilmProcess.reversal => 2,
        FilmProcess.monochrome => 3,
        null => 0,
      };

  @override
  void dispose() {
    _query.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Put the chosen row in the window once the card has been laid out. The
  /// shelf is short enough that every row is built, so the key is real.
  void _scheduleReveal() {
    if (_revealScheduled) {
      return;
    }
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted) {
        return;
      }
      final BuildContext? row = _chosen.currentContext;
      if (row != null) {
        Scrollable.ensureVisible(row, alignment: 0.4);
      }
    });
  }

  bool get _films => widget.kind == MaterialsKind.film;

  Stock? get _film => widget.catalogue.film(widget.filmId);

  /// Every box the shelf can offer in the open half, before the search.
  List<Stock> get _shelf {
    if (!_films) {
      return widget.catalogue.papersFor(_film?.process);
    }
    final FilmProcess? process = switch (_filter) {
      1 => FilmProcess.negative,
      2 => FilmProcess.reversal,
      3 => FilmProcess.monochrome,
      _ => null,
    };
    return <Stock>[
      for (final Stock stock in widget.catalogue.films)
        if (process == null || stock.process == process) stock,
    ];
  }

  /// The boxes the search leaves.
  List<Stock> get _shown {
    final String query = _query.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _shelf;
    }
    return <Stock>[
      for (final Stock stock in _shelf)
        if (stock.displayName.toLowerCase().contains(query) ||
            stock.maker.toLowerCase().contains(query) ||
            stock.productName.toLowerCase().contains(query))
          stock,
    ];
  }

  /// The taxonomy, split where the shelf is already split.
  List<({String title, List<Stock> stocks})> _groups(KalloStrings s) {
    final List<({String title, List<Stock> stocks})> groups =
        <({String title, List<Stock> stocks})>[];
    for (final Stock stock in _shown) {
      final String title = _films
          ? s.processName(stock.process ?? FilmProcess.negative)
          : (stock.emulsion ?? PaperEmulsion.colour) == PaperEmulsion.silver
          ? s.silverPaper
          : s.colourPaper;
      final int index = groups.indexWhere(
        (({String title, List<Stock> stocks}) group) => group.title == title,
      );
      if (index < 0) {
        groups.add((title: title, stocks: <Stock>[stock]));
      } else {
        groups[index].stocks.add(stock);
      }
    }
    return groups;
  }

  String get _hint => _films
      ? KalloStrings.of(context).searchFilms
      : KalloStrings.of(context).searchPapers;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    final List<({String title, List<Stock> stocks})> groups = _groups(s);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.height ?? MaterialsCard.maxHeight,
      ),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: <Widget>[
                  KalloSegments(
                    options: <String>[s.film, s.paper],
                    selected: widget.kind.index,
                    onSelect: (int index) =>
                        widget.onKind(MaterialsKind.values[index]),
                  ),
                  const Spacer(),
                  Text(
                    widget.time,
                    style: KalloType.data.copyWith(color: colors.inkFaint),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _ShelfSearch(
                controller: _query,
                focusNode: _search,
                hint: _hint,
                onChanged: () => setState(() {}),
              ),
            ),
            if (_films)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: KalloSegments(
                    options: <String>[
                      s.filterAll,
                      s.filterNegative,
                      s.filterReversal,
                      s.filterMono,
                    ],
                    selected: _filter,
                    onSelect: (int index) {
                      setState(() => _filter = index);
                      _scheduleReveal();
                    },
                  ),
                ),
              ),
            Flexible(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        // A reversal has no print stage, so the paper half of
                        // the shelf is empty by chemistry rather than by
                        // search, and says which.
                        _shelf.isEmpty && !_films ? s.noPaper : s.noResults,
                        textAlign: TextAlign.center,
                        style: KalloType.small.copyWith(color: colors.inkMuted),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (final ({String title, List<Stock> stocks})
                                group
                                in groups)
                              _group(colors, s, group),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: KalloSpace.step1),
          ],
        ),
      ),
    );
  }

  Widget _group(
    KalloColors colors,
    KalloStrings s,
    ({String title, List<Stock> stocks}) group,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
          child: Text(
            group.title.toUpperCase(),
            style: KalloType.caption.copyWith(
              color: colors.inkFaint,
              fontSize: 9.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        for (int i = 0; i < group.stocks.length; i++)
          _row(colors, s, group.stocks[i], divider: i > 0),
      ],
    );
  }

  Widget _row(
    KalloColors colors,
    KalloStrings s,
    Stock stock, {
    required bool divider,
  }) {
    final bool chosen = _films
        ? stock.id == widget.filmId
        : stock.id == widget.paperId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (divider)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Container(height: 1, color: colors.hairline),
          ),
        // The chosen row keeps its own key and is reached by a second one, so
        // a test or a screen reader can still name the box that was taken.
        KeyedSubtree(
          key: chosen ? _chosen : null,
          child: KalloStockRow(
            key: Key(_films ? 'film-${stock.id}' : 'paper-${stock.id}'),
            title: stock.displayName,
            semanticLabel: stock.displayName,
            selected: chosen,
            onTap: () => _films ? widget.onFilm(stock) : widget.onPaper(stock),
          ),
        ),
      ],
    );
  }
}

/// One stock on the shelf: a row that can be taken.
///
/// A row, not a chip: the shelf has one chosen box, and a check mark on a row
/// says so without turning the card into a mosaic of tints. The row is a
/// desktop control — it is 30 high, it answers the pointer, and it is the only
/// thing in the card that is one.
class KalloStockRow extends StatefulWidget {
  const KalloStockRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  /// What a screen reader says; the row's title may be only the product name.
  final String? semanticLabel;

  @override
  State<KalloStockRow> createState() => _KalloStockRowState();
}

class _KalloStockRowState extends State<KalloStockRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final Color background = widget.selected
        ? colors.accentSoft
        : _hover
        ? colors.fill
        : const Color(0x00000000);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel ?? widget.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: KalloMotion.instant,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(KalloRadius.control - 2),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KalloType.small.copyWith(
                      color: widget.selected ? colors.ink : colors.inkMuted,
                      fontWeight: widget.selected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (widget.selected)
                  Padding(
                    padding: const EdgeInsets.only(left: KalloSpace.step2),
                    child: KalloGlyphView(
                      KalloGlyph.check,
                      size: 14,
                      color: colors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A field on the shelf: one line, a magnifier, and the query.
class _ShelfSearch extends StatelessWidget {
  const _ShelfSearch({
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
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: KalloSpace.step3),
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: BorderRadius.circular(KalloRadius.control - 1),
        ),
        child: Row(
          children: <Widget>[
            KalloGlyphView(KalloGlyph.search, size: 14, color: colors.inkMuted),
            const SizedBox(width: KalloSpace.step2),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  EditableText(
                    controller: controller,
                    focusNode: focusNode,
                    style: KalloType.small.copyWith(color: colors.ink),
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
                        style: KalloType.small.copyWith(color: colors.inkFaint),
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
                child: Padding(
                  padding: const EdgeInsets.only(left: KalloSpace.step2),
                  child: KalloGlyphView(
                    KalloGlyph.close,
                    size: 13,
                    color: colors.inkMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
