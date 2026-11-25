import 'dart:io';

import 'roll_store.dart';

/// The folder the darkroom's strip is worked in.
///
/// A strip is the work in progress, not an export: its prints are the PNGs the
/// model writes there, in the app's own folder beside the settings. The strip
/// itself is not kept for the next window — the darkroom opens on an empty
/// bench — but the photographs the person chose stay, because they are not the
/// strip's.
abstract final class StripStore {
  /// The record an earlier version kept, and restored on the next launch.
  static const String _record = 'strip.json';

  /// Where the strip works. The same folder the old roll used, because it is
  /// the same darkroom and the photograph is already there.
  static Directory? get folder => RollStore.folder;

  /// The file a print is written to. A print is named by its development, so
  /// re-developing the same time replaces the print rather than growing a
  /// second one at the same place on the strip.
  static File printFile(Directory folder, double minutes) => File(
    '${folder.path}${Platform.pathSeparator}'
    'strip-${minutes.toStringAsFixed(2)}.png',
  );

  /// Copy the photograph into the strip's folder.
  ///
  /// A file panel can hand over a temporary copy of something in a photo
  /// library; a strip that pointed at a file that will be gone tomorrow could
  /// not be developed again. The name is kept: the photograph is the one thing
  /// here the app did not make.
  static Future<File> keep(File photograph, {Directory? folder}) async {
    final Directory target = folder ?? folderOrThrow;
    await target.create(recursive: true);
    final String name = photograph.path.split(Platform.pathSeparator).last;
    final File kept = File('${target.path}${Platform.pathSeparator}$name');
    if (kept.absolute.path == photograph.absolute.path) {
      return kept;
    }
    return photograph.copy(kept.path);
  }

  static Directory get folderOrThrow {
    final Directory? target = folder;
    if (target == null) {
      throw const FileSystemException(
        'the app has no folder to write a strip to',
      );
    }
    return target;
  }

  /// Forget the strip's files: its prints, its previews, and the record an
  /// earlier version kept for the next launch. The photographs stay, because
  /// they are not the strip's — they were the person's.
  static Future<void> clear({Directory? folder}) async {
    final Directory? target = folder ?? StripStore.folder;
    if (target == null) {
      return;
    }
    final File record = File('${target.path}${Platform.pathSeparator}$_record');
    if (record.existsSync()) {
      await record.delete();
    }
    for (final FileSystemEntity entity in target.listSync()) {
      if (entity is File &&
          entity.path.split(Platform.pathSeparator).last.startsWith('strip-')) {
        await entity.delete();
      }
    }
  }
}
