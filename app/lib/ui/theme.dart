import 'package:flutter/material.dart';

/// Earthy palette drawn from the radish logo: leaf greens, soil browns and
/// radish pinks on warm cream (light) or dark soil (dark).
abstract final class ClothoTheme {
  static const _light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF3F6E22),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCDEBB0),
    onPrimaryContainer: Color(0xFF10200A),
    secondary: Color(0xFF7A5634),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFEED9BD),
    onSecondaryContainer: Color(0xFF2B1B0B),
    tertiary: Color(0xFF8A4F7D),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF4DEF4),
    onTertiaryContainer: Color(0xFF3A0F33),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFFAF6EC),
    onSurface: Color(0xFF2A2620),
    onSurfaceVariant: Color(0xFF5C5446),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF6F1E5),
    surfaceContainer: Color(0xFFF2ECDD),
    surfaceContainerHigh: Color(0xFFEDE6D6),
    surfaceContainerHighest: Color(0xFFEAE2CF),
    outline: Color(0xFF8C8170),
    outlineVariant: Color(0xFFD6CCB8),
    inverseSurface: Color(0xFF332E27),
    onInverseSurface: Color(0xFFF4EBC8),
    inversePrimary: Color(0xFF8FD45A),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  static const _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8FD45A),
    onPrimary: Color(0xFF10230A),
    primaryContainer: Color(0xFF2F5418),
    onPrimaryContainer: Color(0xFFCDEBB0),
    secondary: Color(0xFFDDB78B),
    onSecondary: Color(0xFF3B2A16),
    secondaryContainer: Color(0xFF4A3826),
    onSecondaryContainer: Color(0xFFF4E1C6),
    tertiary: Color(0xFFE8C3E3),
    onTertiary: Color(0xFF46203F),
    tertiaryContainer: Color(0xFF5E3456),
    onTertiaryContainer: Color(0xFFF4DEF4),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: Color(0xFF17140F),
    onSurface: Color(0xFFECE4D6),
    onSurfaceVariant: Color(0xFFCFC4B2),
    surfaceContainerLowest: Color(0xFF110F0B),
    surfaceContainerLow: Color(0xFF1B1813),
    surfaceContainer: Color(0xFF1F1B15),
    surfaceContainerHigh: Color(0xFF26211A),
    surfaceContainerHighest: Color(0xFF2E2820),
    outline: Color(0xFF978C7B),
    outlineVariant: Color(0xFF4A4236),
    inverseSurface: Color(0xFFECE4D6),
    onInverseSurface: Color(0xFF2A2620),
    inversePrimary: Color(0xFF3F6E22),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  static ThemeData get light => _build(_light);
  static ThemeData get dark => _build(_dark);

  static ThemeData _build(ColorScheme s) {
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: s,
      scaffoldBackgroundColor: s.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        foregroundColor: s.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: s.outlineVariant)),
      ),
      cardTheme: CardThemeData(
        color: s.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: rounded),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: rounded,
          side: BorderSide(color: s.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: rounded),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: s.primaryContainer,
        foregroundColor: s.onPrimaryContainer,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: s.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: s.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: s.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: s.surfaceContainer,
        selectedColor: s.secondaryContainer,
        side: BorderSide(color: s.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: s.primary,
        unselectedLabelColor: s.onSurfaceVariant,
        indicatorColor: s.primary,
        dividerColor: s.outlineVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: s.surfaceContainer,
        indicatorColor: s.secondaryContainer,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(iconColor: s.secondary, shape: rounded),
      dividerTheme: DividerThemeData(color: s.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: s.inverseSurface,
        contentTextStyle: TextStyle(color: s.onInverseSurface),
        actionTextColor: s.inversePrimary,
        shape: rounded,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.primary,
        linearTrackColor: s.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: s.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: s.onInverseSurface),
      ),
    );
  }
}
