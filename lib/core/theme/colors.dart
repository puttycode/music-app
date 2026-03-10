import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1DB954);
  static const Color primaryDark = Color(0xFF191414);
  static const Color secondary = Color(0xFF535353);
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF181818);
  static const Color surfaceVariant = Color(0xFF282828);
  static const Color onPrimary = Colors.black;
  static const Color onBackground = Colors.white;
  static const Color onSurface = Colors.white;
  static const Color onSurfaceVariant = Color(0xFFB3B3B3);
  static const Color error = Color(0xFFE91429);
  static const Color success = Color(0xFF1DB954);
  static const Color warning = Color(0xFFF59B23);
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF1DB954), Color(0xFF191414)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
