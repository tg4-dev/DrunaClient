import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';

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

enum ActionPillKind { confirm, cancel, add, destructive }

class ActionPill extends StatelessWidget {
  const ActionPill({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.kind = ActionPillKind.confirm,
    this.size = ActionPillSize.large,
    this.filled = false,
    super.key,
  });

  final IconData icon;

  final String label;
  final VoidCallback? onPressed;
  final ActionPillKind kind;
  final ActionPillSize size;

  final bool filled;

  @override
  Widget build(BuildContext context) => PillButton(
    icon: icon,
    label: label,
    onPressed: onPressed,
    width: size.width,
    height: size.height,
    iconSize: size.icon,
    fill: filled ? Colors.white : PillStyle.fill,
    color: filled
        ? Colors.black
        : kind == ActionPillKind.destructive
        ? SheetStyle.today
        : Colors.white,
  );
}
