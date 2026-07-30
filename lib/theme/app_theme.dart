import 'package:flutter/material.dart';

class AppColors {
  // Brand colors extracted from logo.png
  static const Color primaryCoral = Color(0xFFFF3B6B);
  static const Color primaryCoralDark = Color(0xFFD62854);
  static const Color accentAqua = Color(0xFF74D4EC);
  static const Color accentAquaLight = Color(0xFFB8EDF8);
  
  // Background & Surface dark palette
  static const Color bgDark = Color(0xFF0F181F);
  static const Color cardDark = Color(0xFF162732);
  static const Color surfaceDark = Color(0xFF1F3543);
  static const Color borderDark = Color(0xFF2C4C5B);

  // Text & Icons
  static const Color textPrimary = Color(0xFFF0F8FB);
  static const Color textSecondary = Color(0xFF8AA4B3);
  static const Color textMuted = Color(0xFF5A7585);

  // Gradient accents
  static const LinearGradient logoGradient = LinearGradient(
    colors: [primaryCoral, Color(0xFFFF6584)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aquaGradient = LinearGradient(
    colors: [accentAqua, Color(0xFF4DB9D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A2B36), Color(0xFF13222C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.bgDark,
      primaryColor: AppColors.primaryCoral,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryCoral,
        secondary: AppColors.accentAqua,
        surface: AppColors.cardDark,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.accentAqua,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentAqua, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryCoral,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: AppColors.primaryCoral.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.accentAqua,
      ),
      listTileTheme: ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.accentAqua,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryCoral,
        linearTrackColor: AppColors.surfaceDark,
      ),
    );
  }
}
