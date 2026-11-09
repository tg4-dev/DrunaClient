import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';

abstract final class PageStyle {
  static const gutter = 20.0;
  static const actionsGap = 24.0;

  static const title = TextStyle(
    fontFamily: 'Onest',
    fontVariations: [FontVariation('wght', 700)],
    color: Colors.white,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const body = TextStyle(
    fontFamily: 'Onest',
    color: Colors.white,
    fontSize: 17,
  );

  static const action = TextStyle(
    fontFamily: 'Onest',
    fontVariations: [FontVariation('wght', 600)],
    color: SheetStyle.accent,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
}

class BlockSection extends StatelessWidget {
  const BlockSection({
    required this.icon,
    required this.title,
    required this.children,
    super.key,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: SheetStyle.blockDecoration,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: SheetStyle.muted, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: SheetStyle.title)),
              ],
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}

class BlockMessage extends StatelessWidget {
  const BlockMessage({
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: SheetStyle.blockDecoration,
      child: Padding(
        padding: SheetStyle.blockPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: SheetStyle.title),
            const SizedBox(height: 6),
            Text(body, style: SheetStyle.row),
            if (action != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PillButton(text: action, onPressed: onAction),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
