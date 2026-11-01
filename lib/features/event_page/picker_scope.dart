import 'package:flutter/foundation.dart';

/// Closes the open wheel or month on the event page when the user taps
/// anywhere else (design-system §9.1). The blocks with pickers listen.
class PickerScope extends ChangeNotifier {
  void closeAll() => notifyListeners();
}
