import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AuthNavigation {
  static bool _redirectingToLogin = false;

  static void redirectToLogin() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || _redirectingToLogin) return;

    _redirectingToLogin = true;
    Future.microtask(() {
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      _redirectingToLogin = false;
    });
  }
}
