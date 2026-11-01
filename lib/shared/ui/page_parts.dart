import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';

/// Pieces shared by the pages on the home plane (friends, settings): the
/// page title and the blocks borrowed from the event sheet.
abstract final class PageStyle {
  /// Same side margin as the month title.
  static const gutter = 20.0;

  static const title = TextStyle(
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  /// Buttons, rows and the search field on the page plane.
  static const body = TextStyle(color: Colors.white, fontSize: 17);

  static const action = TextStyle(
    color: SheetStyle.accent,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
}

/// A block with an icon and a title on top, like the blocks of the event
/// sheet.
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

/// Empty and error states: a block with a title, a line of text and an
/// optional action.
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
