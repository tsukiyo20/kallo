# The Windows MSI

`Product.wxs` is the WiX 3 source for `kallo-desktop-windows-x86_64.msi`. The
release workflow builds it on the Windows runner:

1. `heat dir` harvests `build/windows/x64/runner/Release` into `files.wxs`
   (a component per file, rooted at `INSTALLFOLDER`).
2. `candle` compiles `Product.wxs` and `files.wxs`, with the app version from
   `app/pubspec.yaml` and the icon from `windows/runner/resources/app_icon.ico`.
3. `light` links the MSI; `license.rtf` is the licence page.

The install is **per-user**, under `%LOCALAPPDATA%\Kallo`, with a Start Menu
shortcut. There is no administrator prompt, and because the folder is writable
the in-app updater can still replace the app in place.

The `UpgradeCode` is fixed: a newer MSI (higher version in `pubspec.yaml`)
replaces an older install. `Product Id` is generated for every build.
