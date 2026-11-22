import 'package:flutter/material.dart';

class RippleColors {
  // Core backgrounds - deep charcoal for OLED-friendly dark mode
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceVariant = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF242424);

  // Brand colors - Amber → Copper → Rose gradient (unique signature)
  static const Color primary = Color(0xFFFF6B35);     // Vibrant amber-orange
  static const Color primaryLight = Color(0xFFFF8C42);
  static const Color primaryDark = Color(0xFFE85D04);
  static const Color secondary = Color(0xFFD4A574);   // Warm copper
  static const Color tertiary = Color(0xFFC97B4A);    // Deep copper
  static const Color quaternary = Color(0xFFF5A623);  // Golden amber
  static const Color accent = Color(0xFFE85D04);      // Rich copper-orange
  static const Color rose = Color(0xFFE94D6A);        // Soft rose accent

  // Gradient stops for Ripple brand gradient (Amber → Copper → Rose)
  static const List<Color> brandGradient = [
    Color(0xFFFF6B35),  // Vibrant amber
    Color(0xFFFF8C42),  // Light amber
    Color(0xFFE85D04),  // Copper-orange
    Color(0xFFD4A574),  // Warm copper
    Color(0xFFC97B4A),  // Deep copper
    Color(0xFFE94D6A),  // Rose
    Color(0xFFD63A5E),  // Deep rose
  ];

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Border/divider
  static const Color border = Color(0xFF2A2A2A);
  static const Color divider = Color(0xFF1F1F1F);

  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF5A623);
  static const Color error = Color(0xFFEF4444);

  // Story ring gradient (uses brand gradient)
  static const List<Color> storyRingGradient = [
    Color(0xFFFF6B35),
    Color(0xFFFF8C42),
    Color(0xFFE85D04),
    Color(0xFFD4A574),
    Color(0xFFE94D6A),
    Color(0xFFD63A5E),
  ];

  // Live badge
  static const Color liveRed = Color(0xFFFF0000);

  // Online indicator
  static const Color onlineGreen = Color(0xFF22C55E);
}

class RippleTheme {
  static ThemeData get darkTheme {
    const ColorScheme colorScheme = ColorScheme.dark(
      primary: RippleColors.primary,
      primaryContainer: RippleColors.primaryDark,
      secondary: RippleColors.secondary,
      secondaryContainer: RippleColors.tertiary,
      tertiary: RippleColors.rose,
      surface: RippleColors.surface,
      surfaceContainerHighest: RippleColors.surfaceElevated,
      onPrimary: RippleColors.textOnPrimary,
      onSecondary: RippleColors.textOnPrimary,
      onSurface: RippleColors.textPrimary,
      onSurfaceVariant: RippleColors.textSecondary,
      outline: RippleColors.border,
      outlineVariant: RippleColors.divider,
      error: RippleColors.error,
      onError: RippleColors.textOnPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RippleColors.background,
      canvasColor: RippleColors.surface,

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: RippleColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Billabong',
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: RippleColors.textPrimary,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(
          color: RippleColors.textPrimary,
          size: 26,
        ),
        actionsIconTheme: const IconThemeData(
          color: RippleColors.textPrimary,
          size: 26,
        ),
        toolbarHeight: 56,
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: RippleColors.background,
        selectedItemColor: RippleColors.textPrimary,
        unselectedItemColor: RippleColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 26),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: RippleColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: RippleColors.border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RippleColors.primary,
          foregroundColor: RippleColors.textOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RippleColors.textPrimary,
          side: const BorderSide(color: RippleColors.border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RippleColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RippleColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RippleColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RippleColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RippleColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RippleColors.error, width: 1),
        ),
        labelStyle: const TextStyle(
          color: RippleColors.textSecondary,
          fontSize: 15,
        ),
        hintStyle: const TextStyle(
          color: RippleColors.textTertiary,
          fontSize: 15,
        ),
        floatingLabelStyle: const TextStyle(
          color: RippleColors.primary,
          fontSize: 13,
        ),
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: RippleColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
          letterSpacing: -0.3,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
          letterSpacing: 0,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
          letterSpacing: 0.1,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
          letterSpacing: 0.1,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
          letterSpacing: 0.1,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
          letterSpacing: 0.1,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: RippleColors.textPrimary,
          letterSpacing: 0.1,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: RippleColors.textPrimary,
          letterSpacing: 0.1,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: RippleColors.textSecondary,
          letterSpacing: 0.2,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: RippleColors.textSecondary,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: RippleColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: RippleColors.textPrimary,
        size: 24,
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: RippleColors.divider,
        thickness: 0.5,
        space: 1,
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: RippleColors.surfaceVariant,
        selectedColor: RippleColors.primary.withValues(alpha: 0.2),
        disabledColor: RippleColors.surfaceVariant,
        labelStyle: const TextStyle(
          color: RippleColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: RippleColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: RippleColors.border, width: 0.5),
        ),
        side: const BorderSide(color: RippleColors.border, width: 0.5),
        brightness: Brightness.dark,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: RippleColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: RippleColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 15,
          color: RippleColors.textSecondary,
        ),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: RippleColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        modalBackgroundColor: RippleColors.surface,
        constraints: const BoxConstraints(maxWidth: 600),
      ),

      // Snack bar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RippleColors.surfaceElevated,
        contentTextStyle: const TextStyle(
          color: RippleColors.textPrimary,
          fontSize: 14,
        ),
        actionTextColor: RippleColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),

      // Tab bar theme
      tabBarTheme: TabBarThemeData(
        labelColor: RippleColors.textPrimary,
        unselectedLabelColor: RippleColors.textSecondary,
        indicatorColor: RippleColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
        dividerColor: Colors.transparent,
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: RippleColors.primary,
        inactiveTrackColor: RippleColors.border,
        thumbColor: RippleColors.primary,
        overlayColor: RippleColors.primary.withValues(alpha: 0.2),
        valueIndicatorColor: RippleColors.primary,
        valueIndicatorTextStyle: const TextStyle(
          color: RippleColors.textOnPrimary,
          fontSize: 12,
        ),
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RippleColors.primary,
        linearTrackColor: RippleColors.border,
        circularTrackColor: RippleColors.border,
      ),
    );
  }
}