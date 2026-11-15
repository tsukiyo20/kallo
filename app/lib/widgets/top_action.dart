import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// An action on the window's top edge, beside the switches.
///
/// The switches say whether something is on; this says "do this". It is made
/// of the same glass as a switch — the chrome floats over the work, and only
/// the paper and the wall are materials — but it has a word and no dot, because
/// an action is not a state.
class KalloTopAction extends StatefulWidget {
  const KalloTopAction({
    super.key,
    required this.label,
    required this.onTap,
    required this.control,
  });

  final String label;
  final VoidCallback onTap;

  /// The ink and the glass: the room's own when the chrome stands over it.
  final Color control;

  @override
  State<KalloTopAction> createState() => _KalloTopActionState();
}

class _KalloTopActionState extends State<KalloTopAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color control = widget.control;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: KalloMotion.instant,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: KalloSpace.step3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: control.withValues(alpha: _hover ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(KalloRadius.pill),
          ),
          child: Text(
            widget.label,
            style: KalloType.small.copyWith(
              color: control.withValues(alpha: _hover ? 0.92 : 0.70),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
