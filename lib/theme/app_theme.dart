import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF111827);
  static const Color primarySoft = Color(0xFF1F2937);
  static const Color accent = Color(0xFF0F766E);
  static const Color accentDark = Color(0xFF115E59);
  static const Color background = Color(0xFFF7F9FB);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFD1D5DB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color success = Color(0xFF059669); // emerald-600
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706); // amber-600
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626); // red-600
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFEFF6FF);
  static const Color neutral = Color(0xFF64748B);
  static const Color neutralSoft = Color(0xFFF1F5F9);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            titleLarge: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: AppColors.textPrimary,
            ),
            titleMedium: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            bodySmall: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
            labelSmall: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: AppColors.textSecondary,
            ),
          ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        prefixIconColor: AppColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
