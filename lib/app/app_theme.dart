import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const background = Color(0xFF080808);
  const surface = Color(0xFF111112);
  const raised = Color(0xFF1A1A1C);
  const text = Color(0xFFF5F5F7);
  const muted = Color(0xFF9A9AA1);
  const danger = Color(0xFFFF5967);
  final noBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: text,
      onPrimary: background,
      secondary: Color(0xFF8F68FF),
      onSecondary: text,
      surface: surface,
      onSurface: text,
      error: danger,
    ),
    splashFactory: InkSparkle.splashFactory,
    fontFamily: 'SF Pro Display',
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, height: 1.35, color: muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: raised,
      hintStyle: const TextStyle(color: Color(0xFF73737A)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: noBorder,
      enabledBorder: noBorder,
      focusedBorder: noBorder,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: raised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
