import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:flutter/cupertino.dart';

class ValueMenu extends StatelessWidget {
  const ValueMenu({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.dividerAfter = const {},
    super.key,
  });

  final String label;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Set<String> dividerAfter;

  @override
  Widget build(BuildContext context) {
    final items = <AdaptivePopupMenuEntry>[
      for (final entry in options.entries) ...[
        AdaptivePopupMenuItem<String>(
          label: entry.value,
          value: entry.key,
          selected: entry.key == selected,
        ),
        if (dividerAfter.contains(entry.key)) const AdaptivePopupMenuDivider(),
      ],
    ];
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AdaptivePopupMenuButton.widget<String>(
        items: items,
        onSelected: (_, entry) => onSelected(entry.value!),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AnimatedSwitcher(
                  duration: SheetStyle.fade,
                  child: Text(
                    label,
                    key: ValueKey(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SheetStyle.value,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 14,
                color: SheetStyle.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
