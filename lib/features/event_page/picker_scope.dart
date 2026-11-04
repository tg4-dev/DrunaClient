import 'package:flutter/foundation.dart';

class PickerScope extends ChangeNotifier {
  void closeAll() => notifyListeners();
}
