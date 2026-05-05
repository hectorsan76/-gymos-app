import 'package:flutter/material.dart';

class R {
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  static double pad(BuildContext context) => isTablet(context) ? 28.0 : 16.0;
  static double buttonHeight(BuildContext context) => isTablet(context) ? 74.0 : 56.0;
  static double heroHeight(BuildContext context) => isTablet(context) ? 164.0 : 120.0;
  static double avatarRadius(BuildContext context) => isTablet(context) ? 36.0 : 24.0;
  static double fontSize(BuildContext context, double base) =>
      isTablet(context) ? base * 1.25 : base;
}
