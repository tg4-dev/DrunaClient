import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The rows of the settings' blocks (design-system §9.3): at least 44 pt,
/// a title 17 white, a subtitle 13 grey.
abstract final class SettingRowStyle {
  static const title = TextStyle(color: Colors.white, fontSize: 17);
  static const subtitle = TextStyle(color: SheetStyle.muted, fontSize: 13);
  static const success = Color(0xFF34C759);
}

/// The result of a check shown at the right of a row.
class SettingCheck {
  const SettingCheck.running() : running = true, ok = false, text = '';
  const SettingCheck.ok(this.text) : running = false, ok = true;
  const SettingCheck.failed(this.text) : running = false, ok = false;

  final bool running;
  final bool ok;
  final String text;
}

/// A row at least 44 pt tall: title, optional subtitle, and on the right a
/// value or the result of a check.
class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.title,
    this.subtitle,
    this.value,
    this.status,
    this.trailing,
    this.color = Colors.white,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final SettingCheck? status;

  /// In place of [value]: a menu, a chevron.
  final Widget? trailing;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final check = status;
    final enabled =
        onTap != null || value != null || check != null || trailing != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: SheetStyle.fade,
        opacity: enabled ? 1 : 0.4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SettingRowStyle.title.copyWith(color: color),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: SettingRowStyle.subtitle),
                    ],
                  ),
                ),
                if (value != null)
                  Flexible(
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: SheetStyle.value,
                    ),
                  ),
                ?trailing,
                if (check != null)
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: SheetStyle.fade,
                      child: check.running
                          ? const CupertinoActivityIndicator()
                          : Text(
                              check.text,
                              key: ValueKey(check.text),
                              maxLines: 2,
                              textAlign: TextAlign.end,
                              style: SheetStyle.value.copyWith(
                                color: check.ok
                                    ? SettingRowStyle.success
                                    : SheetStyle.today,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row with a switch at the right; [leading] stands before the title.
class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: SheetStyle.fade,
      opacity: onChanged == null ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SettingRowStyle.title),
                  if (subtitle != null)
                    Text(subtitle!, style: SettingRowStyle.subtitle),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IgnorePointer(
              ignoring: onChanged == null,
              child: AdaptiveSwitch(
                value: value,
                onChanged: (next) => onChanged?.call(next),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
