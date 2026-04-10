import 'package:flutter/material.dart';

ThemeData buildAppTheme() => ThemeData(
  // Default fallback fonts
  // See bug https://github.com/flutter/flutter/issues/60069
  fontFamilyFallback: const ['Noto Color Emoji 2', 'Noto Sans SC 71'],
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFF1565C0),
  brightness: Brightness.light,
);
