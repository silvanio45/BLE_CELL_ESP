import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController();
  bool switchValue = false;

  void changeTheme() {
    switchValue = !switchValue;
    notifyListeners();
  }
}
