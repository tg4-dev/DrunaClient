import 'package:druna_app/shared/ui/motion.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/widgets.dart';

abstract final class PageBarStyle {
  static const gutter = 16.0;
}

class PageBar extends StatelessWidget {
  const PageBar({this.hidden = false, this.leading, this.trailing, super.key});

  final bool hidden;

  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget fading(Widget? child) {
      if (child == null) return const SizedBox(width: PillStyle.size);
      return IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: reduce ? Duration.zero : Motion.short,
          child: child,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PageBarStyle.gutter),
      child: SizedBox(
        height: PillStyle.size,
        child: Row(
          children: [fading(leading), const Spacer(), fading(trailing)],
        ),
      ),
    );
  }
}
