import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
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
