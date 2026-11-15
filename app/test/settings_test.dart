import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/render_mode.dart';
import 'package:kallo/lab/settings.dart';

void main() {
  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('kallo-settings-');
    Settings.useDirectory(folder);
  });

  tearDown(() {
    Settings.useDirectory(null);
    folder.deleteSync(recursive: true);
  });

  test('the photo explanation is remembered', () async {
    expect((await Settings.read()).photoPrimerSeen, isFalse);

    await const Settings().withPhotoPrimerSeen(true).write();

    final Settings settings = await Settings.read();
    expect(settings.photoPrimerSeen, isTrue);
    // Setting it must not drop the choices beside it.
    expect(settings.spectral, isFalse);
    expect(settings.exportPath, isNull);
  });

  test('the renderer is remembered, and the default is the gpu', () async {
    expect((await Settings.read()).renderer, RenderMode.gpu);

    await const Settings().withRenderer(RenderMode.cpu).write();

    final Settings settings = await Settings.read();
    expect(settings.renderer, RenderMode.cpu);
    // Setting it must not drop the choices beside it.
    expect(settings.spectral, isFalse);
    expect(settings.photoPrimerSeen, isFalse);
  });

  test('a settings file without a renderer means the gpu', () async {
    final File file = Settings.file!;
    file.writeAsStringSync('{"spectral": true}');

    final Settings settings = await Settings.read();
    expect(settings.renderer, RenderMode.gpu);
    expect(settings.spectral, isTrue);
  });

  test('a settings file without the flag still opens', () async {
    final File file = Settings.file!;
    file.writeAsStringSync('{"spectral": true}');

    final Settings settings = await Settings.read();
    expect(settings.spectral, isTrue);
    expect(settings.photoPrimerSeen, isFalse);
  });
}
