import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/short_hash.dart';

void main() {
  test('a print is named after the photograph and its recipe, not a counter', () {
    final String raw = printFileName(
      photograph: '/Users/me/Pictures/DSC03315.ARW',
      recipe: 'portra|endura|9.0|none',
    );
    final String jpeg = printFileName(
      photograph: r'C:\photos\IMG_5186.jpeg',
      recipe: 'superia|endura|9.0|warm',
    );

    // The name a person recognises is the original file's, on either separator,
    // without the camera's extension.
    expect(raw, startsWith('DSC03315-'));
    expect(jpeg, startsWith('IMG_5186-'));
    expect(raw.toLowerCase(), matches(RegExp(r'^dsc03315-[0-9a-f]{8}$')));

    // The fingerprint is the recipe's: one print asked for twice keeps its
    // name, another edge of the same negative does not take its file.
    expect(
      printFileName(
        photograph: '/p/DSC03315.ARW',
        recipe: 'portra|endura|9.0|none',
      ),
      raw,
    );
    expect(
      printFileName(
        photograph: '/p/DSC03315.ARW',
        recipe: 'portra|endura|9.0|warm',
      ),
      isNot(raw),
    );
  });

  test('the short hash is eight hexadecimal digits', () {
    for (final String recipe in <String>['', 'a', 'one print', '另一个配方']) {
      expect(
        shortHash(recipe),
        matches(RegExp(r'^[0-9a-f]{8}$')),
        reason: 'recipe "$recipe"',
      );
    }
    expect(shortHash('one'), shortHash('one'));
    expect(shortHash('one'), isNot(shortHash('two')));
  });
}
