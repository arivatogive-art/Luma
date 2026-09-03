import 'package:flutter/material.dart';

class LumaTheme {
  static const Color lumaOrange = Color(0xFFE58A2B);

  static const Color darkBackground = Color(0xFF0B0B0B);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceSoft = Color(0xFF171717);
  static const Color darkSurfaceMuted = Color(0xFF1E1E1E);
  static const Color darkSurfaceStrong = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkTextPrimary = Color(0xFFF5F5F4);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
  static const Color darkTextMuted = Color(0xFF8F8F8F);

  static const Color lightBackground = Color(0xFFF0F2F5);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceSoft = Color(0xFFF7F8FA);
  static const Color lightSurfaceMuted = Color(0xFFE9EDF2);
  static const Color lightSurfaceStrong = Color(0xFFDDE3EA);
  static const Color lightBorder = Color(0xFFD8DEE6);
  static const Color lightTextPrimary = Color(0xFF1C1E21);
  static const Color lightTextSecondary = Color(0xFF65676B);
  static const Color lightTextMuted = Color(0xFF8A8D91);

  static const Color darkError = Color(0xFFE46962);
  static const Color lightError = Color(0xFFC84B43);

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: lumaOrange,
      onPrimary: Colors.white,
      secondary: lumaOrange,
      onSecondary: Colors.white,
      tertiary: darkSurfaceSoft,
      onTertiary: darkTextPrimary,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerLowest: darkBackground,
      surfaceContainerLow: darkSurface,
      surfaceContainer: darkSurfaceSoft,
      surfaceContainerHigh: darkSurfaceMuted,
      surfaceContainerHighest: darkSurfaceStrong,
      outline: darkBorder,
      outlineVariant: darkBorder,
      error: darkError,
      onError: Colors.white,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: colorScheme,
      cardColor: darkSurfaceSoft,
      dividerColor: darkBorder,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      canvasColor: darkBackground,
      disabledColor: darkTextMuted,
      textTheme: _textTheme(
        primary: darkTextPrimary,
        secondary: darkTextSecondary,
        buttonText: Colors.white,
      ),
      iconTheme: const IconThemeData(
        color: darkTextSecondary,
        size: 22,
      ),
      primaryIconTheme: const IconThemeData(
        color: lumaOrange,
        size: 22,
      ),
      appBarTheme: _appBarTheme(
        background: darkBackground,
        foreground: darkTextPrimary,
        titleColor: darkTextPrimary,
      ),
      bottomNavigationBarTheme: _bottomNavigationBarTheme(
        background: darkSurface,
        unselected: darkTextSecondary,
      ),
      navigationBarTheme: _navigationBarTheme(
        background: darkSurface,
        selected: lumaOrange,
        unselected: darkTextSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: _cardTheme(
        background: darkSurfaceSoft,
        border: darkBorder,
      ),
      dialogTheme: _dialogTheme(
        background: darkSurface,
        border: darkBorder,
        text: darkTextPrimary,
      ),
      bottomSheetTheme: _bottomSheetTheme(
        background: darkSurface,
        dragHandle: darkBorder,
      ),
      inputDecorationTheme: _inputDecorationTheme(
        fill: darkSurfaceSoft,
        border: darkBorder,
        hint: darkTextMuted,
        error: darkError,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(
        border: darkBorder,
        foreground: darkTextPrimary,
      ),
      textButtonTheme: _textButtonTheme(),
      chipTheme: _chipTheme(
        background: darkSurfaceSoft,
        selected: lumaOrange,
        border: darkBorder,
        label: darkTextPrimary,
        secondaryLabel: darkTextSecondary,
      ),
      switchTheme: _switchTheme(),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: lumaOrange,
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);

    const colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: lumaOrange,
      onPrimary: Colors.white,
      secondary: lumaOrange,
      onSecondary: Colors.white,
      tertiary: lightSurfaceSoft,
      onTertiary: lightTextPrimary,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerLowest: lightBackground,
      surfaceContainerLow: lightSurface,
      surfaceContainer: lightSurfaceSoft,
      surfaceContainerHigh: lightSurfaceMuted,
      surfaceContainerHighest: lightSurfaceStrong,
      outline: lightBorder,
      outlineVariant: lightBorder,
      error: lightError,
      onError: Colors.white,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: colorScheme,
      cardColor: lightSurface,
      dividerColor: lightBorder,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      canvasColor: lightBackground,
      disabledColor: lightTextMuted,
      textTheme: _textTheme(
        primary: lightTextPrimary,
        secondary: lightTextSecondary,
        buttonText: Colors.white,
      ),
      iconTheme: const IconThemeData(
        color: lightTextSecondary,
        size: 22,
      ),
      primaryIconTheme: const IconThemeData(
        color: lumaOrange,
        size: 22,
      ),
      appBarTheme: _appBarTheme(
        background: lightBackground,
        foreground: lightTextPrimary,
        titleColor: lumaOrange,
      ),
      bottomNavigationBarTheme: _bottomNavigationBarTheme(
        background: lightSurface,
        unselected: lightTextSecondary,
      ),
      navigationBarTheme: _navigationBarTheme(
        background: lightSurface,
        selected: lumaOrange,
        unselected: lightTextSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: _cardTheme(
        background: lightSurface,
        border: lightBorder,
      ),
      dialogTheme: _dialogTheme(
        background: lightSurface,
        border: lightBorder,
        text: lightTextPrimary,
      ),
      bottomSheetTheme: _bottomSheetTheme(
        background: lightSurface,
        dragHandle: lightBorder,
      ),
      inputDecorationTheme: _inputDecorationTheme(
        fill: lightSurfaceSoft,
        border: lightBorder,
        hint: lightTextMuted,
        error: lightError,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(
        border: lightBorder,
        foreground: lightTextPrimary,
      ),
      textButtonTheme: _textButtonTheme(),
      chipTheme: _chipTheme(
        background: lightSurfaceSoft,
        selected: lumaOrange,
        border: lightBorder,
        label: lightTextPrimary,
        secondaryLabel: lightTextSecondary,
      ),
      switchTheme: _switchTheme(),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: lumaOrange,
      ),
    );
  }

  static TextTheme _textTheme({
    required Color primary,
    required Color secondary,
    required Color buttonText,
  }) {
    return TextTheme(
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: buttonText,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: secondary,
      ),
    );
  }

  static AppBarTheme _appBarTheme({
    required Color background,
    required Color foreground,
    required Color titleColor,
  }) {
    return AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: foreground,
      iconTheme: IconThemeData(color: foreground),
      actionsIconTheme: IconThemeData(color: foreground),
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: titleColor,
      ),
    );
  }

  static BottomNavigationBarThemeData _bottomNavigationBarTheme({
    required Color background,
    required Color unselected,
  }) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      backgroundColor: background,
      selectedItemColor: lumaOrange,
      unselectedItemColor: unselected,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static NavigationBarThemeData _navigationBarTheme({
    required Color background,
    required Color selected,
    required Color unselected,
  }) {
    return NavigationBarThemeData(
      elevation: 0,
      backgroundColor: background,
      indicatorColor: selected.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: lumaOrange);
        }
        return IconThemeData(color: unselected);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: lumaOrange,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          );
        }
        return TextStyle(
          color: unselected,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
    );
  }

  static CardThemeData _cardTheme({
    required Color background,
    required Color border,
  }) {
    return CardThemeData(
      elevation: 0,
      color: background,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: border),
      ),
    );
  }

  static DialogThemeData _dialogTheme({
    required Color background,
    required Color border,
    required Color text,
  }) {
    return DialogThemeData(
      elevation: 0,
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: text,
      ),
      contentTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: text,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: border),
      ),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme({
    required Color background,
    required Color dragHandle,
  }) {
    return BottomSheetThemeData(
      elevation: 0,
      backgroundColor: background,
      modalBackgroundColor: background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: dragHandle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required Color fill,
    required Color border,
    required Color hint,
    required Color error,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: TextStyle(
        color: hint,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(
        color: hint,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: lumaOrange,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: lumaOrange, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: error, width: 1.2),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: lumaOrange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: lumaOrange.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.65),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: lumaOrange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: lumaOrange.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.65),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme({
    required Color border,
    required Color foreground,
  }) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        foregroundColor: foreground,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lumaOrange,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static ChipThemeData _chipTheme({
    required Color background,
    required Color selected,
    required Color border,
    required Color label,
    required Color secondaryLabel,
  }) {
    return ChipThemeData(
      backgroundColor: background,
      selectedColor: selected.withValues(alpha: 0.16),
      disabledColor: background.withValues(alpha: 0.55),
      surfaceTintColor: Colors.transparent,
      checkmarkColor: lumaOrange,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      labelStyle: TextStyle(
        color: label,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        color: secondaryLabel,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
    );
  }

  static SwitchThemeData _switchTheme() {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return lumaOrange;
        }
        return null;
      }),
    );
  }
}
