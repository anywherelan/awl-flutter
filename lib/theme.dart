import 'package:flutter/material.dart';

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0169ED)),
  brightness: Brightness.light,
);
