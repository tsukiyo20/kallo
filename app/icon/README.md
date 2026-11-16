# The mark

The source is `kallo-icon.svg`; the 1024 px master is `kallo-icon-1024.png`.
The platform assets are generated from the master, never edited by hand:

```bash
python3 app/icon/generate.py
```

The generator needs Pillow. It writes the macOS asset catalogue, every iOS
icon, the iOS launch screen's mark and background colour, the Android legacy
mipmaps and adaptive background layers, the Windows ICO, and the 256 px copy
the About page draws from `app/assets/`. The macOS icon is the master masked to
a rounded square with a transparent margin and a shadow; iOS gets the full
square and no alpha. The launch mark is the icon as iOS masks it — rounded, with
a transparent margin — and the launch background is the app's own ground, so the
storyboard and the app's first frame are the same colour.

If the SVG changes, render a new master first. On macOS:

```bash
qlmanage -t -s 1024 -o /tmp app/icon/kallo-icon.svg
cp /tmp/kallo-icon.svg.png app/icon/kallo-icon-1024.png
```

Then run the generator.
