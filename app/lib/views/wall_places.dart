import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import '../lab/print.dart';
import '../widgets/wall.dart';

/// Where every print hangs on the gallery's wall.
///
/// The wall is a place with coordinates of its own rather than a list that
/// reflows. Until a person hangs something the wall arranges the work for them
/// — the same equal grid it has always had, because five developments of one
/// negative are five equal things. The first time a sheet is moved the whole
/// hanging is written down, and after that the wall is theirs: prints that
/// arrive later are hung in a fresh line under the work that is already there,
/// and nothing that was hung by hand moves again.
///
/// A place is the top-left corner of the sheet itself, not of the paper's
/// label: the label is part of what hangs, and it follows the sheet wherever
/// the sheet is hung.
@immutable
class WallPlaces {
  const WallPlaces([this.byId = const <String, Offset>{}]);

  /// The wall's hanging: one place for each print, by the print's key.
  final Map<String, Offset> byId;

  /// Whether a person has hung this wall. Empty means the wall hangs it.
  bool get isHung => byId.isNotEmpty;

  /// The width of a landscape 3:2 sheet on this wall, in wall points.
  ///
  /// A sheet has a size of its own — paper does not grow when the window does —
  /// and every print keeps the same area on it, so a portrait is the same sheet
  /// turned rather than a bigger one. The three columns and the room between
  /// them make the wall 956 points across, which is a window's width: on a
  /// window-sized wall the paper is looked at at 1:1, and only a bigger wall or
  /// a narrower window asks for a step back.
  static const double sheet = 300;

  /// The room between two cells of the wall's own grid.
  static const double gap = 28;

  /// The wall hangs three sheets across, as it always has.
  static const int columns = 3;

  /// The paper under a sheet that the wall's label is written on, in points.
  ///
  /// A sheet's rectangle on the wall is its paper plus this space: the label
  /// under a print is part of what hangs, so it is part of what is hung.
  static const double labelSpace = 40;

  /// How far the wall runs from its origin, in wall points, in each direction.
  ///
  /// A wall is not the window: it is a place a person can walk along. The
  /// number is the practical end of that walk — far enough that nobody reaches
  /// it while hanging work, small enough that the coordinates stay exact.
  static const double reach = 20000;

  /// The key a print hangs by.
  ///
  /// A print from a library carries its catalog id, and that is what a hanging
  /// is written against. A print a test built has no id yet still has to hang;
  /// its place in the list is the name it gets. Library prints never fall back
  /// to the index, so a list that grows does not move a hung sheet.
  static String keyOf(Print print, [int index = 0]) => print.id ?? '#$index';

  /// The size of a print's sheet at the wall's paper size.
  static Size sizeOf(Print print) {
    final double heightPerWidth = PrintSheet.heightPerWidth(
      aspect: print.aspect,
    );
    final double area = sheet * sheet * PrintSheet.heightPerWidth(aspect: 1.5);
    final double width = math.sqrt(area / heightPerWidth);
    return Size(width, width * heightPerWidth);
  }

  /// The rectangle a print occupies on the wall: its sheet and its label.
  static Rect rectOf(Print print, Offset at) {
    final Size size = sizeOf(print);
    return Rect.fromLTWH(at.dx, at.dy, size.width, size.height + labelSpace);
  }

  /// Where each print hangs.
  ///
  /// [prints] is read newest first, the way the wall hangs them: the work just
  /// made is the work at the top. On a wall nobody has hung, this is the grid
  /// the wall would have made. On a wall that has been hung, the sheets that
  /// were placed stay exactly where they were put, and prints that arrived
  /// after the hanging was written down are put in a fresh line beneath it.
  Map<String, Offset> resolve(List<Print> prints) {
    final Map<String, Offset> places = <String, Offset>{};
    if (!isHung) {
      _grid(places, <(Print, int)>[
        for (int i = 0; i < prints.length; i++) (prints[i], i),
      ], origin: Offset.zero);
      return places;
    }
    final List<(Print, int)> fresh = <(Print, int)>[];
    Rect? kept;
    for (int i = 0; i < prints.length; i++) {
      final Print print = prints[i];
      final String key = keyOf(print, i);
      final Offset? at = byId[key];
      if (at == null) {
        fresh.add((print, i));
        continue;
      }
      places[key] = at;
      final Rect rect = rectOf(print, at);
      kept = kept == null ? rect : kept.expandToInclude(rect);
    }
    if (fresh.isNotEmpty) {
      final Offset under = kept == null
          ? Offset.zero
          : Offset(kept.left, kept.bottom + gap);
      _grid(places, fresh, origin: under);
    }
    return places;
  }

  /// The wall with [key]'s print hung at [at].
  ///
  /// Moving a sheet on a wall that has not been hung yet hangs the whole wall:
  /// the grid everyone was looking at becomes the arrangement, and the moved
  /// sheet is the one thing that differs. That is what "the wall is yours" is
  /// made of — a decision frozen at the first touch.
  WallPlaces moved(List<Print> prints, String key, Offset at) {
    final Map<String, Offset> next = resolve(prints);
    next[key] = at;
    return WallPlaces(Map<String, Offset>.unmodifiable(next));
  }

  /// The wall in its own grid again.
  WallPlaces cleared() => const WallPlaces();

  /// The rectangle every hung print occupies, in wall points.
  Rect bounds(List<Print> prints, Map<String, Offset> places) {
    Rect? out;
    for (int i = 0; i < prints.length; i++) {
      final Offset? at = places[keyOf(prints[i], i)];
      if (at == null) {
        continue;
      }
      final Rect rect = rectOf(prints[i], at);
      out = out == null ? rect : out.expandToInclude(rect);
    }
    return out ?? Rect.zero;
  }

  /// Hang [prints] in the wall's own grid, rows newest first.
  ///
  /// A row is as tall as its tallest sheet, so a portrait and a landscape can
  /// stand in the same row without one of them leaving a hole under the other.
  static void _grid(
    Map<String, Offset> places,
    List<(Print, int)> prints, {
    required Offset origin,
  }) {
    double top = origin.dy;
    for (int start = 0; start < prints.length; start += columns) {
      final int end = math.min(start + columns, prints.length);
      double rowHeight = 0;
      for (int i = start; i < end; i++) {
        rowHeight = math.max(rowHeight, sizeOf(prints[i].$1).height);
      }
      for (int i = start; i < end; i++) {
        final (Print print, int index) = prints[i];
        final int column = i - start;
        final Size size = sizeOf(print);
        places[keyOf(print, index)] = Offset(
          origin.dx + column * (sheet + gap) + (sheet - size.width) / 2,
          top,
        );
      }
      top += rowHeight + labelSpace + gap;
    }
  }
}
