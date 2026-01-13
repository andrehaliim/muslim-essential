import 'package:flutter/material.dart';
import 'package:muslim_essential/components/colors.dart';
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
