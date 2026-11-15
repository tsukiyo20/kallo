import 'dart:convert';

/// A short, stable fingerprint of a print's recipe, for its file name.
///
/// FNV-1a, 32 bits, written as eight hex digits. This is not a security hash:
/// it exists so two prints of one photograph have two names — another edge,
/// another exposure, another paper — without a naming scheme a person has to
/// learn. The same recipe is the same print, and replacing its file is right.
String shortHash(Object? recipe) {
  int hash = 0x811c9dc5;
  for (final int byte in utf8.encode(recipe.toString())) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// The name a finished print is written under: the photograph's own name and
/// the recipe's fingerprint.
///
/// The name says which photograph it is, because that is the thing the person
/// recognises in a folder; the eight characters say which print of it, because
/// a photograph printed twice with a different edge is not the same sheet.
String printFileName({
  required String photograph,
  required String recipe,
}) => '${_stem(photograph)}-${shortHash(recipe)}';

/// The last segment of [photograph] without its extension.
String _stem(String path) {
  final int separator = path.lastIndexOf(RegExp(r'[/\\]'));
  final String base = separator < 0 ? path : path.substring(separator + 1);
  final int dot = base.lastIndexOf('.');
  return dot <= 0 ? base : base.substring(0, dot);
}
