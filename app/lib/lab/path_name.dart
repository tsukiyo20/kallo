// The name of a file, read on either separator.
//
// Windows accepts `/` and `\` in the same path, and a path reaches the app from
// a picker, a drop, a record written on another machine and the tests — so a
// split on `Platform.pathSeparator` alone reads a POSIX-looking path as one
// long file name, and the ORIGINAL line shows `/photographs/uji` where it means
// `uji`.

/// Where the last folder separator in [path] is, or -1 when there is none.
int lastSeparator(String path) {
  final int slash = path.lastIndexOf('/');
  final int backslash = path.lastIndexOf(r'\');
  return slash > backslash ? slash : backslash;
}

/// The last segment of [path]: the file's own name, folder left behind.
String baseName(String path) {
  final int separator = lastSeparator(path);
  return separator < 0 ? path : path.substring(separator + 1);
}

/// The last segment of [path], without its extension.
String stemOf(String path) {
  final String base = baseName(path);
  final int dot = base.lastIndexOf('.');
  return dot <= 0 ? base : base.substring(0, dot);
}
