import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Colours, type and motion of the event sheet, measured from the Figma
/// reference and tuned for contrast.
abstract final class SheetStyle {
  static const block = Color(0xFF141414);
  static const blockRadius = Radius.circular(32);
  static const blockPadding = EdgeInsets.fromLTRB(24, 18, 20, 20);
  static const muted = Color(0xFF8E8E93);
  static const secondary = Color(0xFFD1D1D6);
  static const accent = Color(0xFF0A84FF);
  static const today = Color(0xFFFF3B30);
  static const chip = Color(0xFF2C2C2E);
  static const divider = Color(0x1FFFFFFF);
  static const pickerHeight = 180.0;

  /// Anything that appears or disappears fades for at least this long.
  static const fade = Duration(milliseconds: 180);
  static const motion = Duration(milliseconds: 260);

  /// Block titles: "Весь день", "Повтор".
  static const title = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// Rows inside a block: options, "Окончание повтора".
  static const row = TextStyle(
    color: secondary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  /// Values at the end of a row.
  static const value = TextStyle(
    color: muted,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// Small labels above values: "Начало", "Конец".
  static const caption = TextStyle(
    color: muted,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const clock = TextStyle(
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const duration = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  static BoxDecoration get blockDecoration => const BoxDecoration(
    color: block,
    borderRadius: BorderRadius.all(blockRadius),
  );

  static CupertinoThemeData get pickerTheme => const CupertinoThemeData(
    brightness: Brightness.dark,
    textTheme: CupertinoTextThemeData(
      dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 22),
      pickerTextStyle: TextStyle(color: Colors.white, fontSize: 22),
    ),
  );
}

/// Shows [child] when [open], growing and fading in; collapses and fades out
/// otherwise. The sheet's rule: nothing pops in or out.
class Reveal extends StatelessWidget {
  const Reveal({
    required this.open,
    required this.child,
    this.contentKey,
    super.key,
  });

  final bool open;
  final Widget child;

  /// Changing it cross-fades to the new [child] instead of swapping it.
  final Object? contentKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: SheetStyle.motion,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: SheetStyle.fade,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: open
            ? KeyedSubtree(key: ValueKey(('open', contentKey)), child: child)
            : const SizedBox(key: ValueKey(false), width: double.infinity),
      ),
    );
  }
}
