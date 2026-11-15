import 'dart:io';

import 'catalog.dart';
import 'folder_print_library.dart';
import 'mobile_print_library.dart';
import 'print_library.dart';

/// Open the library this platform actually has.
///
/// A desktop gets a folder, a phone gets the system photo library. Tests and
/// desktop code call [FolderPrintLibrary.open] directly. Android's bridge is
/// opened without a permission dialog; the first photograph chosen is where
/// the app explains itself and asks.
Future<PrintLibrary> openPrintLibrary({
  Directory? folder,
  Catalog? catalog,
}) async {
  if (Platform.isIOS || Platform.isAndroid) {
    return MobilePrintLibrary.open(catalog: catalog);
  }
  if (folder == null) {
    throw ArgumentError('a desktop library needs a folder');
  }
  return FolderPrintLibrary.open(folder: folder, catalog: catalog);
}
