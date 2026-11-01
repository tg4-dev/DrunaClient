import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';

/// The two sizes of the action pill: the event sheet's, and a smaller one
/// for rows of a list where two large pills would crowd out the name.
enum ActionPillSize {
  large(width: PillStyle.wide, height: PillStyle.size, icon: 24),
  compact(width: 56, height: PillStyle.compact, icon: 20);

  const ActionPillSize({
    required this.width,
    required this.height,
    required this.icon,
  });

  final double width;
  final double height;
  final double icon;
}

/// What the pill does. Only [destructive] looks different: a red icon.
enum ActionPillKind {
  /// ✓ — save, accept, yes.
  confirm,

  /// ✕ — cancel, reject, no.
  cancel,

  /// + — add, send.
  add,

  /// Removes something for good.
  destructive,
}

/// The one shape for every yes/no, cancel/confirm action in the app: a
/// [PillButton] stretched sideways with an icon in the middle. Taken from
/// the ✕ and ✓ of the event sheet. Drawn by Flutter, not a native view:
/// a list of them scrolls as cheaply as plain shapes.
class ActionPill extends StatelessWidget {
  const ActionPill({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.kind = ActionPillKind.confirm,
    this.size = ActionPillSize.large,
    super.key,
  });

  final IconData icon;

  /// Read by VoiceOver; the pill has no visible text.
  final String label;
  final VoidCallback? onPressed;
  final ActionPillKind kind;
  final ActionPillSize size;

  @override
  Widget build(BuildContext context) => PillButton(
    icon: icon,
    label: label,
    onPressed: onPressed,
    width: size.width,
    height: size.height,
    iconSize: size.icon,
    color: kind == ActionPillKind.destructive ? SheetStyle.today : Colors.white,
  );
}
