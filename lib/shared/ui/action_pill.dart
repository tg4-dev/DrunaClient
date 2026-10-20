import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:flutter/material.dart';

/// The two sizes of the action pill: the event sheet's, and a smaller one
/// for rows of a list where two large pills would crowd out the name.
enum ActionPillSize {
  large(width: 80, height: 44, icon: 24, native: AdaptiveButtonSize.large),
  compact(width: 56, height: 36, icon: 20, native: AdaptiveButtonSize.medium);

  const ActionPillSize({
    required this.width,
    required this.height,
    required this.icon,
    required this.native,
  });

  final double width;
  final double height;
  final double icon;
  final AdaptiveButtonSize native;
}

/// What the pill does: its glass and colour follow from it.
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

/// The one shape for every yes/no, cancel/confirm action in the app: a pill
/// stretched sideways with an icon in the middle, Liquid Glass on iOS 26.
/// Taken from the ✕ and ✓ of the event sheet.
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
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (style, color) = switch (kind) {
      ActionPillKind.confirm || ActionPillKind.add => (
        AdaptiveButtonStyle.prominentGlass,
        SheetStyle.accent,
      ),
      ActionPillKind.cancel => (AdaptiveButtonStyle.glass, SheetStyle.muted),
      ActionPillKind.destructive => (
        AdaptiveButtonStyle.prominentGlass,
        SheetStyle.today,
      ),
    };
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: SheetStyle.fade,
        opacity: enabled ? 1 : 0.4,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: AdaptiveButton.icon(
            onPressed: onPressed ?? () {},
            enabled: enabled,
            icon: icon,
            iconColor: Colors.white,
            color: color,
            style: style,
            size: size.native,
            // Fixed padding around the icon gives the pill its width; the
            // native button centres its child only when the child spans it.
            padding: EdgeInsets.symmetric(
              horizontal: (size.width - size.icon) / 2,
            ),
            borderRadius: BorderRadius.circular(size.height / 2),
            useSmoothRectangleBorder: false,
          ),
        ),
      ),
    );
  }
}
