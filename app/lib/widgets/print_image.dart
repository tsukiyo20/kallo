import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../design/scope.dart';
import '../lab/print.dart';
import '../lab/thumbnails.dart';

/// A print's picture, loaded only when someone is looking at it.
///
/// This is the picture on the paper and nothing else: a print is cropped to the
/// frame's image area, so there is no rebate, no sprocket hole and no edge
/// printing around it. The film's edge is a choice made when the print is made
/// (`lab/edge_print.dart`), not a layer the wall draws over the paper.
///
/// The rack and the gallery hold metadata, not textures. This widget asks the
/// thumbnail cache for the one picture it needs and lets it go when it leaves
/// the tree, which is what makes a wall of a thousand prints a wall and not a
/// decoded copy of the folder.
class PrintImage extends StatefulWidget {
  const PrintImage({
    super.key,
    required this.print,
    this.fit = BoxFit.cover,
    this.quality = FilterQuality.medium,
  });

  final Print print;
  final BoxFit fit;
  final FilterQuality quality;

  @override
  State<PrintImage> createState() => _PrintImageState();
}

class _PrintImageState extends State<PrintImage> {
  PrintThumbnail? _thumbnail;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PrintImage old) {
    super.didUpdateWidget(old);
    if (!identical(old.print, widget.print)) {
      _thumbnail?.release();
      _thumbnail = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.print.image != null) {
      return;
    }
    final int generation = ++_generation;
    final PrintThumbnail? thumbnail = await PrintThumbnailCache.instance
        .acquire(widget.print);
    if (!mounted || generation != _generation) {
      thumbnail?.release();
      return;
    }
    setState(() => _thumbnail = thumbnail);
  }

  @override
  void dispose() {
    _thumbnail?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? image = _thumbnail?.image ?? widget.print.image;
    if (image != null) {
      return RawImage(
        image: image,
        fit: widget.fit,
        filterQuality: widget.quality,
      );
    }
    return ColoredBox(
      color: KalloScope.colorsOf(context).fill.withValues(alpha: 0.45),
    );
  }
}
