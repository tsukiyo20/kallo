import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/print.dart';
import 'package:kallo/views/wall_places.dart';

/// A print as the wall sees it: a shape, and the id it hangs by.
Print _print({String? id, String name = 'print', double aspect = 1.5}) {
  final Size pixels = aspect >= 1
      ? Size(1200, 1200 / aspect)
      : Size(1200 * aspect, 1200);
  return Print(id: id, name: name, pixels: pixels);
}

void main() {
  test('an unhung wall hangs the work in its own equal grid', () {
    final List<Print> prints = <Print>[
      for (int i = 0; i < 5; i++) _print(id: 'p$i', name: 'p$i'),
    ];
    final Map<String, Offset> places = const WallPlaces().resolve(prints);

    expect(places, hasLength(5));
    // Three across, newest first, the landscape sheet at the wall's width.
    expect(places['p0'], const Offset(0, 0));
    expect(places['p1'], const Offset(WallPlaces.sheet + WallPlaces.gap, 0));
    expect(
      places['p2'],
      const Offset((WallPlaces.sheet + WallPlaces.gap) * 2, 0),
    );
    // The next row starts under the tallest sheet of the one above it.
    final Size size = WallPlaces.sizeOf(prints[0]);
    expect(
      places['p3']!.dy,
      closeTo(size.height + WallPlaces.labelSpace + WallPlaces.gap, 0.001),
    );
    expect(places['p3']!.dx, 0);
    expect(places['p4']!.dy, places['p3']!.dy);
  });

  test('a portrait is the same paper turned, not a bigger one', () {
    final Print landscape = _print(id: 'l');
    final Print portrait = _print(id: 'p', aspect: 2 / 3);
    final Size land = WallPlaces.sizeOf(landscape);
    final Size port = WallPlaces.sizeOf(portrait);

    expect(land.width, closeTo(WallPlaces.sheet, 0.001));
    expect(port.width, lessThan(land.width));
    expect(port.height, greaterThan(land.height));
    expect(port.width * port.height, closeTo(land.width * land.height, 1));
  });

  test('the first touch hangs the whole wall', () {
    final List<Print> prints = <Print>[
      for (int i = 0; i < 3; i++) _print(id: 'p$i'),
    ];
    final WallPlaces grid = const WallPlaces();
    final Map<String, Offset> before = grid.resolve(prints);

    final WallPlaces hung = grid.moved(prints, 'p1', const Offset(1200, 900));
    final Map<String, Offset> after = hung.resolve(prints);

    expect(hung.isHung, isTrue);
    expect(after['p1'], const Offset(1200, 900));
    expect(after['p0'], before['p0']);
    expect(after['p2'], before['p2']);
  });

  test('a place is written against the print, not against its turn', () {
    final List<Print> prints = <Print>[
      for (int i = 0; i < 3; i++) _print(id: 'p$i'),
    ];
    final WallPlaces hung = const WallPlaces().moved(
      prints,
      'p2',
      const Offset(40, 50),
    );

    // The wall reads newest first; a print that arrives in front of the list
    // does not take another print's place with it.
    final List<Print> reordered = <Print>[
      _print(id: 'new'),
      prints[0],
      prints[1],
      prints[2],
    ];
    final Map<String, Offset> places = hung.resolve(reordered);
    expect(places['p2'], const Offset(40, 50));
    expect(places['p0'], const Offset(0, 0));
  });

  test('a print that arrives after the hanging is put under it', () {
    final List<Print> prints = <Print>[
      for (int i = 0; i < 3; i++) _print(id: 'p$i'),
    ];
    final WallPlaces hung = const WallPlaces().moved(
      prints,
      'p0',
      const Offset(0, 0),
    );
    final Map<String, Offset> kept = hung.resolve(prints);
    final Rect bounds = hung.bounds(prints, kept);

    final List<Print> withNew = <Print>[_print(id: 'new'), ...prints];
    final Map<String, Offset> places = hung.resolve(withNew);

    expect(places['new']!.dy, closeTo(bounds.bottom + WallPlaces.gap, 0.001));
    expect(places['new']!.dx, closeTo(bounds.left, 0.001));
    // The work that was already hung does not move for it.
    for (final Print print in prints) {
      expect(places[print.id], kept[print.id]);
    }
  });

  test('a sheet on the wall is paper and its label', () {
    final Print print = _print(id: 'p');
    final Size paper = WallPlaces.sizeOf(print);
    final Rect rect = WallPlaces.rectOf(print, const Offset(10, 20));

    expect(rect.left, 10);
    expect(rect.top, 20);
    expect(rect.width, closeTo(paper.width, 0.001));
    expect(rect.height, closeTo(paper.height + WallPlaces.labelSpace, 0.001));
  });

  test('the wall can be hung back in its grid', () {
    final List<Print> prints = <Print>[_print(id: 'p0'), _print(id: 'p1')];
    final WallPlaces grid = const WallPlaces();
    final WallPlaces hung = grid.moved(prints, 'p0', const Offset(500, 500));

    expect(hung.cleared().isHung, isFalse);
    expect(hung.cleared().resolve(prints), grid.resolve(prints));
  });

  test('a test print hangs by its turn when it has no catalog id', () {
    final List<Print> prints = <Print>[_print(name: 'a'), _print(name: 'b')];
    final WallPlaces hung = const WallPlaces().moved(
      prints,
      WallPlaces.keyOf(prints[1], 1),
      const Offset(800, 0),
    );
    final Map<String, Offset> places = hung.resolve(prints);

    expect(places['#1'], const Offset(800, 0));
    expect(places['#0'], const Offset(0, 0));
  });
}
