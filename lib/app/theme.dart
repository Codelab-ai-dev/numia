import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/constants/n_colors.dart';
import '../shared/constants/n_spacing.dart';

ThemeData buildNumiaTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final ct = isDark ? NColorTheme.dark() : NColorTheme.light();

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: ct.bg,
    extensions: [ct],
    colorScheme: ColorScheme(
      brightness: brightness,
      primary:   NColors.indigo,
      secondary: NColors.emerald,
      surface:   ct.surface1,
      error:     NColors.error,
      onPrimary:   Colors.white,
      onSecondary: Colors.white,
      onSurface:   ct.textPrimary,
      onError:     Colors.white,
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ct.textPrimary,
      ),
      iconTheme: IconThemeData(color: ct.textPrimary),
    ),

    // Card
    cardTheme: CardThemeData(
      color: ct.surface1,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NSpacing.rXl),
        side: BorderSide(color: ct.borderSubtle),
      ),
      margin: EdgeInsets.zero,
    ),

    // Input — glass style
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ct.surface1,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: NSpacing.sp4,
        vertical: NSpacing.sp4,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NSpacing.rMd),
        borderSide: BorderSide(color: ct.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NSpacing.rMd),
        borderSide: BorderSide(color: ct.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NSpacing.rMd),
        borderSide: const BorderSide(color: NColors.indigo, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NSpacing.rMd),
        borderSide: const BorderSide(color: NColors.error),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: ct.textTertiary,
      ),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: ct.textSecondary,
      ),
    ),

    // ElevatedButton fallback
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NColors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NSpacing.rMd),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: ct.borderSubtle,
      thickness: 1,
      space: 0,
    ),

    // BottomNav
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: ct.surface1,
      selectedItemColor: ct.accent1,
      unselectedItemColor: ct.textTertiary,
      elevation: 0,
    ),

    // Text theme base
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(
      bodyColor: ct.textSecondary,
      displayColor: ct.textPrimary,
    ),

    // Page transitions
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
