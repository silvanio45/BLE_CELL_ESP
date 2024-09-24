import 'package:flutter/material.dart';
import 'package:appble/App_controller.dart';

import 'Home_app.dart';

class AppWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, child) {
        return MaterialApp(
          theme: ThemeData(
            primarySwatch: Colors.red,
            brightness: ThemeController.instance.switchValue
                ? Brightness.dark
                : Brightness.light,
          ),
          home: HomeApp(),
        );
      },
    );
  }
}
