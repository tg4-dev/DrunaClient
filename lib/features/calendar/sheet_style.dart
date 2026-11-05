import 'package:druna_app/shared/ui/motion.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  static const fade = Motion.short;
  static const motion = Duration(milliseconds: 260);

  static const title = TextStyle(
    fontFamily: 'Onest',
    fontVariations: [FontVariation('wght', 600)],
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const row = TextStyle(
    fontFamily: 'Onest',
    fontVariations: [FontVariation('wght', 400)],
    color: secondary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const value = TextStyle(
    fontFamily: 'Onest',
    fontVariations: [FontVariation('wght', 500)],
    color: muted,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    fontFamily: 'Onest',
    fontVariations: [FontVariation('wght', 600)],
    color: muted,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static BoxDecoration get blockDecoration => const BoxDecoration(
    color: block,
    borderRadius: BorderRadius.all(blockRadius),
  );

  static CupertinoThemeData get pickerTheme => const CupertinoThemeData(
    brightness: Brightness.dark,
    textTheme: CupertinoTextThemeData(
      dateTimePickerTextStyle: TextStyle(
        fontFamily: 'Onest',
        color: Colors.white,
        fontSize: 22,
      ),
      pickerTextStyle: TextStyle(
        fontFamily: 'Onest',
        color: Colors.white,
        fontSize: 22,
      ),
    ),
  );
}

class Reveal extends StatelessWidget {
  const Reveal({
    required this.open,
    required this.child,
    this.contentKey,
    super.key,
  });

  final bool open;
  final Widget child;

  final Object? contentKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: SheetStyle.motion,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: SheetStyle.fade,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
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
