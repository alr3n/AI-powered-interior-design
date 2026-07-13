import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 theming. Seed-based schemes keep light/dark in harmony;
/// typography pairs a geometric display face with a readable body face.
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF3D6B5E); // muted eucalyptus — calm, premium

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.sora(
          textStyle: base.textTheme.displaySmall, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.sora(
          textStyle: base.textTheme.headlineSmall, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.sora(
          textStyle: base.textTheme.titleLarge, fontWeight: FontWeight.w600),
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? const Color(0xFFF7F6F3) : null,
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: scheme.surfaceContainerLow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
