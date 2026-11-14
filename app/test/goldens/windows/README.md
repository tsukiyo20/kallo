# Windows studio goldens

The twelve pictures Windows draws. They are the same widgets, the same test card
and the same bundled fonts as `../macos/`; what differs is Windows' own text
rasterisation, and nothing else. Compared against the macOS set, no picture is
more than 0.3 of 255 away on average, and the differing pixels are glyph edges.

From `app/` on Windows:

```bash
fvm flutter test --dart-define=studio-goldens=true --update-goldens \
  test/studio_golden_test.dart
```

Then, to compare:

```bash
fvm flutter test --dart-define=studio-goldens=true \
  test/studio_golden_test.dart
```

The files are `select.png`, `select-light.png`, `develop.png`, `print.png`,
`rack.png`, `rack-light.png`, `viewer.png`, `gallery.png`, `gallery-light.png`,
`portrait.png`, `lens.png` and `loupe.png`. They sit beside the macOS set; the
test reads only the folder for the platform it runs on.
