/// The ten scalars a stock recipe may move.
///
/// The catalogue says which fields expose a control and what interval each may
/// take; this is the values themselves, as the model consumes them. Every field
/// is an identity multiplier — 1.0 is the file's own number — so a default
/// [Tuning] renders the stock as the file compiled it, and the model may skip
/// the arithmetic entirely.
///
/// The order is `kallo_core::Tuning::KEYS` and the names are the catalogue's
/// control keys: `grain.strength` is [grainStrength], and so on. The bridge
/// takes the values as one list, so that order is the contract; nothing else
/// in the app may reorder them.
class Tuning {
  const Tuning({
    this.grainStrength = 1.0,
    this.grainSize = 1.0,
    this.maskStrength = 1.0,
    this.blurSharpness = 1.0,
    this.dyeSaturation = 1.0,
    this.halationStrength = 1.0,
    this.couplersStrength = 1.0,
    this.interimageStrength = 1.0,
    this.printContrast = 1.0,
    this.printBlack = 1.0,
  });

  /// The file's own numbers: a stock with no recipe applied.
  static const Tuning identity = Tuning();

  /// The control keys, in the order the bridge takes the values.
  static const List<String> keys = <String>[
    'grain.strength',
    'grain.size',
    'mask.strength',
    'blur.sharpness',
    'dyes.saturation',
    'halation.strength',
    'couplers.strength',
    'interimage.strength',
    'print.contrast',
    'print.black',
  ];

  /// Multiplies the developed grain density of every layer.
  final double grainStrength;

  /// Scales the grain's correlation length; above one is a coarser grain.
  final double grainSize;

  /// Multiplies the orange mask's density.
  final double maskStrength;

  /// Divides the borrowed blur's width; above one is a sharper borrow.
  final double blurSharpness;

  /// Multiplies the borrowed dye set's absorption.
  final double dyeSaturation;

  /// Multiplies both halation components' strengths.
  final double halationStrength;

  /// Multiplies the DIR couplers' inhibition matrix.
  final double couplersStrength;

  /// Multiplies the cyan-sensitive layer's gain.
  final double interimageStrength;

  /// Multiplies the print's slope on the paper: above one is a harder print.
  final double printContrast;

  /// Scales the print's span from the paper's white to its deepest black.
  final double printBlack;

  /// The values, in the order of [keys].
  List<double> toList() => <double>[
    grainStrength,
    grainSize,
    maskStrength,
    blurSharpness,
    dyeSaturation,
    halationStrength,
    couplersStrength,
    interimageStrength,
    printContrast,
    printBlack,
  ];

  /// Whether this is the file's own rendering.
  bool get isIdentity =>
      grainStrength == 1.0 &&
      grainSize == 1.0 &&
      maskStrength == 1.0 &&
      blurSharpness == 1.0 &&
      dyeSaturation == 1.0 &&
      halationStrength == 1.0 &&
      couplersStrength == 1.0 &&
      interimageStrength == 1.0 &&
      printContrast == 1.0 &&
      printBlack == 1.0;

  /// The controls that depart from the file, keyed by their catalogue names.
  Map<String, double> get overrides {
    final List<double> values = toList();
    return <String, double>{
      for (int i = 0; i < keys.length; i++)
        if (values[i] != 1.0) keys[i]: values[i],
    };
  }

  /// The value of one control, or null when the model has no such control.
  double? valueOf(String key) => switch (key) {
    'grain.strength' => grainStrength,
    'grain.size' => grainSize,
    'mask.strength' => maskStrength,
    'blur.sharpness' => blurSharpness,
    'dyes.saturation' => dyeSaturation,
    'halation.strength' => halationStrength,
    'couplers.strength' => couplersStrength,
    'interimage.strength' => interimageStrength,
    'print.contrast' => printContrast,
    'print.black' => printBlack,
    _ => null,
  };

  Tuning copyWith({
    double? grainStrength,
    double? grainSize,
    double? maskStrength,
    double? blurSharpness,
    double? dyeSaturation,
    double? halationStrength,
    double? couplersStrength,
    double? interimageStrength,
    double? printContrast,
    double? printBlack,
  }) => Tuning(
    grainStrength: grainStrength ?? this.grainStrength,
    grainSize: grainSize ?? this.grainSize,
    maskStrength: maskStrength ?? this.maskStrength,
    blurSharpness: blurSharpness ?? this.blurSharpness,
    dyeSaturation: dyeSaturation ?? this.dyeSaturation,
    halationStrength: halationStrength ?? this.halationStrength,
    couplersStrength: couplersStrength ?? this.couplersStrength,
    interimageStrength: interimageStrength ?? this.interimageStrength,
    printContrast: printContrast ?? this.printContrast,
    printBlack: printBlack ?? this.printBlack,
  );

  /// This tuning with one control moved.
  ///
  /// An unknown key is a programming mistake: the catalogue's vocabulary is the
  /// model's, and a control the model does not have cannot be set.
  Tuning withValue(String key, double value) => switch (key) {
    'grain.strength' => copyWith(grainStrength: value),
    'grain.size' => copyWith(grainSize: value),
    'mask.strength' => copyWith(maskStrength: value),
    'blur.sharpness' => copyWith(blurSharpness: value),
    'dyes.saturation' => copyWith(dyeSaturation: value),
    'halation.strength' => copyWith(halationStrength: value),
    'couplers.strength' => copyWith(couplersStrength: value),
    'interimage.strength' => copyWith(interimageStrength: value),
    'print.contrast' => copyWith(printContrast: value),
    'print.black' => copyWith(printBlack: value),
    _ => throw ArgumentError.value(key, 'key', 'the model has no such control'),
  };

  /// This tuning with another's moved controls laid over it.
  ///
  /// A print carries two documents when both materials have recipes: the film's
  /// and the paper's. Their controls are different keys, so a control the other
  /// tuning left at the file's number keeps this one's value.
  Tuning mergedWith(Tuning other) => Tuning(
    grainStrength: other.grainStrength == 1.0
        ? grainStrength
        : other.grainStrength,
    grainSize: other.grainSize == 1.0 ? grainSize : other.grainSize,
    maskStrength: other.maskStrength == 1.0 ? maskStrength : other.maskStrength,
    blurSharpness: other.blurSharpness == 1.0
        ? blurSharpness
        : other.blurSharpness,
    dyeSaturation: other.dyeSaturation == 1.0
        ? dyeSaturation
        : other.dyeSaturation,
    halationStrength: other.halationStrength == 1.0
        ? halationStrength
        : other.halationStrength,
    couplersStrength: other.couplersStrength == 1.0
        ? couplersStrength
        : other.couplersStrength,
    interimageStrength: other.interimageStrength == 1.0
        ? interimageStrength
        : other.interimageStrength,
    printContrast: other.printContrast == 1.0
        ? printContrast
        : other.printContrast,
    printBlack: other.printBlack == 1.0 ? printBlack : other.printBlack,
  );

  /// The tuning for values in [keys] order.
  static Tuning fromList(List<double> values) {
    if (values.length != keys.length) {
      throw ArgumentError.value(
        values,
        'values',
        'tuning is ${keys.length} numbers, in the order of Tuning.keys',
      );
    }
    return Tuning(
      grainStrength: values[0],
      grainSize: values[1],
      maskStrength: values[2],
      blurSharpness: values[3],
      dyeSaturation: values[4],
      halationStrength: values[5],
      couplersStrength: values[6],
      interimageStrength: values[7],
      printContrast: values[8],
      printBlack: values[9],
    );
  }

  /// The tuning a set of named controls describes.
  static Tuning fromOverrides(Map<String, double> values) {
    Tuning tuning = identity;
    for (final MapEntry<String, double> entry in values.entries) {
      tuning = tuning.withValue(entry.key, entry.value);
    }
    return tuning;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tuning &&
          other.grainStrength == grainStrength &&
          other.grainSize == grainSize &&
          other.maskStrength == maskStrength &&
          other.blurSharpness == blurSharpness &&
          other.dyeSaturation == dyeSaturation &&
          other.halationStrength == halationStrength &&
          other.couplersStrength == couplersStrength &&
          other.interimageStrength == interimageStrength &&
          other.printContrast == printContrast &&
          other.printBlack == printBlack;

  @override
  int get hashCode => Object.hash(
    grainStrength,
    grainSize,
    maskStrength,
    blurSharpness,
    dyeSaturation,
    halationStrength,
    couplersStrength,
    interimageStrength,
    printContrast,
    printBlack,
  );

  @override
  String toString() => isIdentity
      ? 'Tuning.identity'
      : 'Tuning(${overrides.entries.map((MapEntry<String, double> e) => '${e.key}=${e.value}').join(', ')})';
}
