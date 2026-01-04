import 'package:flutter/material.dart';
import 'package:muslim_essential/services/colors.dart';
// Dark THEME
final ThemeData appDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  primaryColor: AppColors.highlightBlue,
  cardColor: AppColors.containerBackground,
  dividerColor: AppColors.borderColor,
  iconTheme: const IconThemeData(color: AppColors.primaryText),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: AppColors.primaryText, fontSize: 28, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: AppColors.primaryText, fontSize: 20, fontWeight: FontWeight.bold),
    headlineSmall: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: AppColors.secondaryText, fontSize: 16),
    bodyMedium: TextStyle(color: AppColors.secondaryText, fontSize: 14),
    bodySmall: TextStyle(color: AppColors.secondaryText, fontSize: 12),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    iconTheme: IconThemeData(color: AppColors.primaryText),
    titleTextStyle: TextStyle(color: AppColors.primaryText, fontSize: 20),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.buttonBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 8
    ),
  ),
  colorScheme: ColorScheme.dark(
    surface: AppColors.containerBackground,
  ),
);

// LIGHT THEME
final ThemeData appLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.backgroundLight,
  primaryColor: AppColors.highlightBlue,
  cardColor: AppColors.containerBackgroundLight,
  dividerColor: Colors.grey.shade300,
  iconTheme: const IconThemeData(color: AppColors.highlightBlue),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Colors.black, fontSize: 22),
    bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.black, fontSize: 14),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.backgroundLight,
    iconTheme: IconThemeData(color: Colors.black),
    titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.highlightBlue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  colorScheme: ColorScheme.light(
    surface: AppColors.containerBackgroundLight,
  ),
);

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode =>
      _themeMode == ThemeMode.dark ||
          (_themeMode == ThemeMode.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
