import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Native confirmation: Liquid Glass alert on iOS 26+, Cupertino on older iOS,
/// Material elsewhere. Resolves to `false` when dismissed without confirming.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  var confirmed = false;
  await AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: [
      AlertAction(
        title: 'Отмена',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: confirmLabel,
        style: destructive
            ? AlertActionStyle.destructive
            : AlertActionStyle.primary,
        onPressed: () => confirmed = true,
      ),
    ],
  );
  return confirmed;
}

/// A short text, e.g. a new name: a native-looking alert with one field.
/// Resolves to the trimmed text, or null when cancelled; [confirmLabel]
/// stays disabled while the field is empty.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
  String placeholder = '',
}) => showCupertinoDialog<String>(
  context: context,
  barrierDismissible: true,
  builder: (context) => _AskText(
    title: title,
    confirmLabel: confirmLabel,
    initial: initial,
    placeholder: placeholder,
  ),
);

class _AskText extends StatefulWidget {
  const _AskText({
    required this.title,
    required this.confirmLabel,
    required this.initial,
    required this.placeholder,
  });

  final String title;
  final String confirmLabel;
  final String initial;
  final String placeholder;

  @override
  State<_AskText> createState() => _AskTextState();
}

class _AskTextState extends State<_AskText> {
  late final _text = TextEditingController(text: widget.initial)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          key: const ValueKey('ask-text-field'),
          controller: _text,
          autofocus: true,
          placeholder: widget.placeholder,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _done(),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _text.text.trim().isEmpty ? null : _done,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Wheel picker on iOS, calendar picker on Android. [initialDate] is clamped
/// into range: both pickers assert on it, e.g. when editing a past event.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => AdaptiveDatePicker.show(
  context: context,
  initialDate: initialDate.isBefore(firstDate)
      ? firstDate
      : initialDate.isAfter(lastDate)
      ? lastDate
      : initialDate,
  firstDate: firstDate,
  lastDate: lastDate,
);

Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required TimeOfDay initialTime,
}) => AdaptiveTimePicker.show(
  context: context,
  initialTime: initialTime,
  use24HourFormat: true,
);
