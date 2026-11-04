import 'package:druna_app/features/onboarding/onboarding_style.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onSubmitted;

  static const length = 6;

  static bool blink = true;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes>
    with SingleTickerProviderStateMixin {
  FocusNode get _focus => widget.focusNode;
  late final _caret = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    _focus.addListener(_blink);
    widget.controller.addListener(_blink);
  }

  @override
  void didUpdateWidget(covariant CodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_blink);
      widget.focusNode.addListener(_blink);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_blink);
      widget.controller.addListener(_blink);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_blink);
    _focus.removeListener(_blink);
    _caret.dispose();
    super.dispose();
  }

  void _blink() {
    final on =
        CodeBoxes.blink &&
        _focus.hasFocus &&
        widget.controller.text.length < CodeBoxes.length &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (on && !_caret.isAnimating) {
      _caret.repeat();
    } else if (!on) {
      _caret.stop();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const box = OnboardingStyle.codeBox;
    final width =
        CodeBoxes.length * box.width +
        (CodeBoxes.length - 1) * OnboardingStyle.codeGap;
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final allSelected =
        selection.isValid && !selection.isCollapsed && text.isNotEmpty;
    return Semantics(
      label: 'Код из письма',
      child: SizedBox(
        width: width,
        height: box.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: TextField(
                key: const ValueKey('code-field'),
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(CodeBoxes.length),
                ],
                keyboardAppearance: Brightness.dark,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => widget.onSubmitted?.call(),
                onEditingComplete: () {},
                onTapOutside: (_) {},
                showCursor: false,
                enableInteractiveSelection: false,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                ),
              ),
            ),
            IgnorePointer(
              child: Row(
                children: [
                  for (var i = 0; i < CodeBoxes.length; i++) ...[
                    if (i > 0) const SizedBox(width: OnboardingStyle.codeGap),
                    _Cell(
                      digit: i < text.length ? text[i] : null,
                      selected: allSelected,
                      caret: _focus.hasFocus && i == text.length,
                      blink: _caret,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.digit,
    required this.selected,
    required this.caret,
    required this.blink,
  });

  final String? digit;
  final bool selected;
  final bool caret;
  final Animation<double> blink;

  @override
  Widget build(BuildContext context) {
    final box = OnboardingStyle.codeBox;
    return SizedBox.fromSize(
      size: box,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OnboardingStyle.codeRadius),
        child: CustomPaint(
          painter: _CellPainter(selected: selected),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: digit != null
                  ? Text(
                      digit!,
                      key: ValueKey(digit),
                      style: OnboardingStyle.digit,
                    )
                  : caret
                  ? FadeTransition(
                      opacity: blink.drive(_caretCurve),
                      child: Container(
                        width: 2,
                        height: 26,
                        color: Colors.white,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  static final _caretCurve = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1), weight: 1),
    TweenSequenceItem(tween: ConstantTween(0), weight: 1),
  ]);
}

class _CellPainter extends CustomPainter {
  const _CellPainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const radius = Radius.circular(OnboardingStyle.codeRadius);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..color = selected
            ? Colors.white.withValues(alpha: 0.28)
            : PillStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(PillStyle.rimWidth / 2), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = PillStyle.rimWidth
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PillStyle.rimTop, PillStyle.rimBottom],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _CellPainter old) => old.selected != selected;
}
