import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

const dialogAccent = CupertinoColors.systemBlue;

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  var confirmed = false;
  final actions = [
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
  ];
  if (!PlatformInfo.isIOS) {
    await AdaptiveAlertDialog.show(
      context: context,
      title: title,
      message: message,
      actions: actions,
    );
    return confirmed;
  }
  final native = PlatformInfo.isIOS26OrHigher();
  await showCupertinoDialog<void>(
    context: context,
    barrierColor: native ? CupertinoColors.transparent : null,
    builder: (dialogContext) => CupertinoTheme(
      data: CupertinoTheme.of(
        dialogContext,
      ).copyWith(primaryColor: dialogAccent),
      child: native
          ? IOS26AlertDialog(title: title, message: message, actions: actions)
          : CupertinoAlertDialog(
              title: Text(title),
              content: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message),
              ),
              actions: [
                for (final action in actions)
                  CupertinoDialogAction(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      action.onPressed();
                    },
                    isDefaultAction: action.style == AlertActionStyle.primary,
                    isDestructiveAction:
                        action.style == AlertActionStyle.destructive,
                    child: Text(action.title),
                  ),
              ],
            ),
    ),
  );
  return confirmed;
}
