import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../design/mobile.dart';
import '../design/scope.dart';
import '../design/strings.dart';
import '../design/tokens.dart';
import '../lab/stock.dart';
import '../lab/strip.dart';
import '../widgets/button.dart';
import '../widgets/chip.dart';
import '../widgets/inspector.dart';
import '../widgets/mobile/mobile_controls.dart';
import '../widgets/mobile/mobile_icon.dart';
import '../widgets/mobile/mobile_sheet.dart';
import 'mobile/mobile_picker.dart';

/// The first step: the photograph, before the developer.
///
/// The original is the thing being worked on, so it is what the page is about;
/// the materials are a column beside it, the way a darkroom has the enlarger in
/// front of the paper shelves. Choosing a film or a paper is taking a box off
/// the shelf, not setting a preference — a new box starts a new strip.
class SelectStage extends StatelessWidget {
  const SelectStage({
    super.key,
    required this.strip,
    required this.photograph,
    required this.catalogue,
    required this.onChoosePhoto,
    required this.onFilm,
    required this.onPaper,
    required this.onGoDevelop,
    required this.onClear,
    this.showInspector = true,
    this.topInset = 0,
  });

  final TestStrip strip;
  final ui.Image? photograph;
  final Catalogue catalogue;

  final VoidCallback onChoosePhoto;
  final ValueChanged<Stock> onFilm;
  final ValueChanged<Stock?> onPaper;
  final VoidCallback onGoDevelop;
  final VoidCallback onClear;

  /// Whether the instrument panel is open. The work takes the width back when
  /// it is not.
  final bool showInspector;

  /// The transparent chrome at the top of the window. The page runs under it;
  /// its text starts below it.
  final double topInset;

  Stock? get _film => catalogue.film(strip.stockId);
  Stock? get _paper =>
      strip.paperId == null ? null : catalogue.paper(strip.paperId!);

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    final Widget work = ColoredBox(
      color: colors.content,
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, topInset + 18, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  s.theOriginal,
                  style: KalloType.caption.copyWith(
                    color: colors.inkFaint,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(width: KalloSpace.step3),
                Expanded(
                  child: Text(
                    strip.name ?? s.noPhotographChosen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KalloType.small.copyWith(color: colors.inkMuted),
                  ),
                ),
                _Quiet(
                  label: photograph == null ? s.choosePhoto : s.changePhoto,
                  onTap: onChoosePhoto,
                ),
              ],
            ),
            const SizedBox(height: KalloSpace.step4),
            Expanded(child: _photograph(colors, s)),
            const SizedBox(height: KalloSpace.step3),
            Text(
              photograph == null ? s.choosePhotoNote : '${strip.photo}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KalloType.small.copyWith(color: colors.inkFaint),
            ),
          ],
        ),
      ),
    );
    if (KalloLayout.isCompact(context)) {
      return _phone(context, colors, s);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: work),
        InspectorPane(
          key: const Key('select-inspector'),
          open: showInspector,
          child: _materials(colors, s),
        ),
      ],
    );
  }

  Widget _phone(BuildContext context, KalloColors colors, KalloStrings s) {
    if (photograph == null) {
      return ColoredBox(
        color: colors.ground,
        child: KalloMobileEmpty(
          glyph: KalloGlyph.photo,
          title: s.startWithPhoto,
          message: s.choosePhotoNote,
          action: SizedBox(
            width: 240,
            child: KalloMobileButton(
              label: s.choosePhoto,
              onTap: onChoosePhoto,
            ),
          ),
          footnote: s.originalNote,
        ),
      );
    }
    return ColoredBox(
      color: colors.ground,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double photoHeight = (constraints.maxHeight - 300).clamp(
            240.0,
            380.0,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: KalloMobileSpace.step3,
                    bottom: KalloMobileSpace.step4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _phonePhoto(context, colors, s, photoHeight),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KalloMobileSpace.screen,
                          KalloMobileSpace.step2,
                          KalloMobileSpace.screen,
                          0,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                strip.name ?? s.noPhotograph,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KalloMobileType.footnote.copyWith(
                                  color: colors.inkMuted,
                                ),
                              ),
                            ),
                            Text(
                              '${photograph!.width} × ${photograph!.height}',
                              style: KalloMobileType.footnote.copyWith(
                                color: colors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      KalloMobileSectionHeader(s.materials),
                      _phoneMaterials(context, colors, s),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KalloMobileSpace.screen + 2,
                          KalloMobileSpace.step3,
                          KalloMobileSpace.screen + 2,
                          0,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: KalloMobileSpace.step2),
                            Expanded(
                              child: Text(
                                '${s.metered} · 0.0 EV · ${strip.spectral ? s.spectralPath : s.scalarPath}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KalloMobileType.footnote.copyWith(
                                  color: colors.inkFaint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KalloMobileSpace.screen,
                  KalloMobileSpace.step2,
                  KalloMobileSpace.screen,
                  KalloMobileSpace.step3,
                ),
                child: KalloMobileButton(
                  label: s.goDevelop,
                  onTap: onGoDevelop,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _phonePhoto(
    BuildContext context,
    KalloColors colors,
    KalloStrings s,
    double height,
  ) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: KalloMobileSpace.screen),
      decoration: BoxDecoration(
        color: KalloFilm.rebate,
        borderRadius: BorderRadius.circular(KalloMobileRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RawImage(
            image: photograph,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          Positioned(
            left: KalloMobileSpace.step3,
            top: KalloMobileSpace.step3,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x8A121214),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                s.theOriginal,
                style: KalloMobileType.micro.copyWith(
                  color: const Color(0xFFF5F5F7),
                  fontSize: 9,
                ),
              ),
            ),
          ),
          Positioned(
            right: KalloMobileSpace.step3,
            bottom: KalloMobileSpace.step3,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _changePhoto(context),
              child: Container(
                height: KalloMobileSpace.touch,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xE6F5F2EA),
                  borderRadius: BorderRadius.circular(KalloMobileRadius.pill),
                ),
                child: Text(
                  s.change,
                  style: KalloMobileType.footnote.copyWith(
                    color: const Color(0xFF1D1D1F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneMaterials(
    BuildContext context,
    KalloColors colors,
    KalloStrings s,
  ) {
    final Stock? film = _film;
    final Stock? paper = _paper;
    final List<Stock> papers = catalogue.papersFor(film?.process);
    final bool noPaper =
        film?.process == FilmProcess.reversal || papers.isEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KalloMobileSpace.screen),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(KalloMobileRadius.card),
        border: Border.all(color: colors.hairline.withValues(alpha: 0.75)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          KalloMobileRow(
            key: const Key('phone-film-row'),
            title: film?.productName ?? s.film,
            subtitle: film == null
                ? null
                : '${film.maker} · ${s.processName(film.process ?? FilmProcess.negative)}',
            minHeight: 64,
            leading: _materialGlyph(colors, KalloGlyph.film),
            onTap: () => _pickFilm(context),
          ),
          const KalloMobileDivider(inset: 64),
          KalloMobileRow(
            key: const Key('phone-paper-row'),
            title: noPaper ? s.paper : (paper?.productName ?? s.paper),
            subtitle: noPaper
                ? s.noPaper
                : (paper == null
                      ? null
                      : '${paper.maker} · ${(paper.emulsion ?? PaperEmulsion.colour) == PaperEmulsion.silver ? s.silverPaper : s.colourPaper}'),
            minHeight: 64,
            leading: _materialGlyph(colors, KalloGlyph.paper, accent: true),
            chevron: !noPaper,
            onTap: noPaper ? null : () => _pickPaper(context),
          ),
        ],
      ),
    );
  }

  Widget _materialGlyph(
    KalloColors colors,
    KalloGlyph glyph, {
    bool accent = false,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent ? colors.accentSoft : colors.fill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: KalloGlyphView(
          glyph,
          size: 18,
          color: accent ? colors.accent : colors.inkMuted,
          stroke: 1.5,
        ),
      ),
    );
  }

  Future<void> _changePhoto(BuildContext context) async {
    if (strip.hasPrints) {
      final bool go = await showKalloConfirm(
        context,
        title: KalloStrings.of(context).changePhotoQuestion,
        message: KalloStrings.of(context).clearsPrints(strip.prints.length),
        confirm: KalloStrings.of(context).changeAction,
      );
      if (!go) {
        return;
      }
    }
    onChoosePhoto();
  }

  Future<void> _pickFilm(BuildContext context) async {
    final Stock? choice = await showKalloFilmPicker(
      context,
      catalogue: catalogue,
      selectedId: _film?.id,
    );
    if (choice == null || choice.id == _film?.id || !context.mounted) {
      return;
    }
    if (strip.hasPrints) {
      final KalloStrings s = KalloStrings.of(context);
      final bool go = await showKalloConfirm(
        context,
        title: s.changeFilmQuestion,
        message: s.clearsPrints(strip.prints.length),
        confirm: s.changeAction,
      );
      if (!go) {
        return;
      }
    }
    onFilm(choice);
  }

  Future<void> _pickPaper(BuildContext context) async {
    final Stock? film = _film;
    final List<Stock> papers = catalogue.papersFor(film?.process);
    if (papers.isEmpty) {
      return;
    }
    final Stock? choice = await showKalloPaperPicker(
      context,
      papers: papers,
      selectedId: _paper?.id,
    );
    if (choice == null || choice.id == _paper?.id || !context.mounted) {
      return;
    }
    if (strip.hasPrints) {
      final KalloStrings s = KalloStrings.of(context);
      final bool go = await showKalloConfirm(
        context,
        title: s.changePaperQuestion,
        message: s.clearsPrints(strip.prints.length),
        confirm: s.changeAction,
      );
      if (!go) {
        return;
      }
    }
    onPaper(choice);
  }

  Widget _photograph(KalloColors colors, KalloStrings s) {
    final ui.Image? photograph = this.photograph;
    if (photograph == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: KalloSpace.step4),
            Text(
              s.choosePhotoNote,
              textAlign: TextAlign.center,
              style: KalloType.body.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: KalloSpace.step5),
            KalloButton(
              label: s.choosePhoto,
              onTap: onChoosePhoto,
              filled: true,
              height: 34,
            ),
          ],
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: photograph.width / photograph.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.print,
            border: Border.all(color: colors.hairline),
          ),
          child: RawImage(
            image: photograph,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  /// The makers in a chemistry, in the order the shelf already has them.
  List<String> _makers(FilmProcess process) {
    final List<String> makers = <String>[];
    for (final Stock stock in catalogue.of(process)) {
      if (!makers.contains(stock.maker)) {
        makers.add(stock.maker);
      }
    }
    return makers;
  }

  Widget _materials(
    KalloColors colors,
    KalloStrings s, {
    bool stacked = false,
  }) {
    final Stock? film = _film;
    final Stock? paper = _paper;
    final List<Stock> papers = catalogue.papersFor(film?.process);
    final Widget filmShelf = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.film,
          style: KalloType.caption.copyWith(
            color: colors.inkFaint,
            letterSpacing: 0.7,
          ),
        ),
        for (final FilmProcess process in FilmProcess.values)
          if (catalogue.of(process).isNotEmpty) ...<Widget>[
            const SizedBox(height: KalloSpace.step3),
            Text(
              s.processName(process),
              style: KalloType.small.copyWith(color: colors.inkMuted),
            ),
            for (final String maker in _makers(process)) ...<Widget>[
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
                        selected: stock.id == film?.id,
                        compact: true,
                        onTap: () => onFilm(stock),
                      ),
                ],
              ),
            ],
          ],
        if (film != null) ...<Widget>[
          const SizedBox(height: KalloSpace.step2),
          Text(
            film.label,
            style: KalloType.small.copyWith(color: colors.inkFaint),
          ),
        ],
        if (strip.hasPrints) ...<Widget>[
          const SizedBox(height: KalloSpace.step4),
          Text(
            s.materialsNote,
            style: KalloType.small.copyWith(color: colors.inkFaint),
          ),
        ],
      ],
    );
    final Widget paperShelf = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          s.paper,
          style: KalloType.caption.copyWith(
            color: colors.inkFaint,
            letterSpacing: 0.7,
          ),
        ),
        if (papers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: KalloSpace.step2),
            child: Text(
              s.noPaper,
              style: KalloType.small.copyWith(color: colors.inkFaint),
            ),
          )
        else
          for (final PaperEmulsion emulsion in PaperEmulsion.values)
            if (papers.any(
              (Stock p) => (p.emulsion ?? PaperEmulsion.colour) == emulsion,
            )) ...<Widget>[
              const SizedBox(height: KalloSpace.step2),
              Text(
                emulsion == PaperEmulsion.silver
                    ? s.silverPaper
                    : s.colourPaper,
                style: KalloType.small.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: KalloSpace.step1),
              Wrap(
                spacing: KalloSpace.step1 + 2,
                runSpacing: KalloSpace.step1 + 2,
                children: <Widget>[
                  for (final Stock p in papers)
                    if ((p.emulsion ?? PaperEmulsion.colour) == emulsion)
                      KalloChip(
                        label: p.displayName,
                        selected: p.id == paper?.id,
                        compact: true,
                        onTap: () => onPaper(p),
                      ),
                ],
              ),
            ],
        if (paper != null) ...<Widget>[
          const SizedBox(height: KalloSpace.step1),
          Text(
            paper.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KalloType.small.copyWith(color: colors.inkFaint),
          ),
        ],
        const SizedBox(height: KalloSpace.step3),
        Row(
          children: <Widget>[
            Text(
              s.exposure,
              style: KalloType.caption.copyWith(
                color: colors.inkFaint,
                letterSpacing: 0.7,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                '${s.metered}   0.0 EV',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: KalloType.data.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: KalloSpace.step3),
        KalloButton(
          label: s.goDevelop,
          onTap: photograph == null ? null : onGoDevelop,
          filled: true,
          height: 34,
        ),
        if (strip.hasPrints) ...<Widget>[
          const SizedBox(height: KalloSpace.step2),
          Align(
            alignment: Alignment.center,
            child: _Quiet(label: s.newStrip, onTap: onClear),
          ),
        ],
      ],
    );
    if (stacked) {
      return DecoratedBox(
        decoration: BoxDecoration(color: colors.surface),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              filmShelf,
              const SizedBox(height: KalloSpace.step5),
              Container(height: 1, color: colors.hairline),
              const SizedBox(height: KalloSpace.step4),
              paperShelf,
            ],
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 16),
              child: filmShelf,
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.hairline)),
            ),
            child: paperShelf,
          ),
        ],
      ),
    );
  }
}

/// A quiet action: a word that is a button because it is where the hand goes.
class _Quiet extends StatelessWidget {
  const _Quiet({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          label,
          style: KalloType.small.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
