/// The two steps of the darkroom, in the order the work goes.
///
/// The photograph is developed and printed; each one has a page in the same
/// room, reached through one small capsule at the top of the bench. The
/// two-letter marks are the film's own vocabulary and do not translate — an
/// edge code is an edge code in every language. Drying is not a step: a print
/// is finished when it leaves the enlarger, and the wall is a place beside the
/// darkroom, not another page of it.
///
/// The photograph used to have a page of its own, before the developer. It
/// does not any more: the original is a row on the bench, because the film and
/// the paper are chosen by looking at the print they make, and a page that
/// showed the original without the print was a form with no answer.
enum DarkroomStep {
  develop('01', 'DEV'),
  print('02', 'PRT');

  const DarkroomStep(this.code, this.mark);

  /// The number printed before the mark on the film's edge.
  final String code;

  /// The two-letter mark: `DEV`, `PRT`.
  final String mark;
}
