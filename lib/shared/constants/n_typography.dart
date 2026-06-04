import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class NTypography {
  // Display — Sora 800, 48px
  static TextStyle get display => GoogleFonts.sora(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.92,
    height: 1.0,
  );

  // H1 — Sora 700, 32px
  static TextStyle get h1 => GoogleFonts.sora(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.96,
    height: 1.1,
  );

  // H2 — Sora 700, 22px
  static TextStyle get h2 => GoogleFonts.sora(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.66,
    height: 1.2,
  );

  // Title — Plus Jakarta Sans 600, 17px
  static TextStyle get title => GoogleFonts.plusJakartaSans(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // Body — Plus Jakarta Sans 400, 15px
  static TextStyle get body => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.7,
  );

  // Body Light — Plus Jakarta Sans 300, 15px
  static TextStyle get bodyLight => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w300,
    height: 1.7,
  );

  // Caption — Plus Jakarta Sans 500, 13px
  static TextStyle get caption => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  // Overline — Plus Jakarta Sans 600, 11px uppercase
  static TextStyle get overline => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.32,
    height: 1.4,
  );

  // Numeric Large — Sora 700, 36px (para patrimonio)
  static TextStyle get numericLg => GoogleFonts.sora(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.08,
    height: 1.1,
  );

  // Numeric Medium — Sora 700, 24px
  static TextStyle get numericMd => GoogleFonts.sora(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.72,
    height: 1.2,
  );

  // Button — Plus Jakarta Sans 600, 15px
  static TextStyle get button => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  // Logo — Sora 700, 20px
  static TextStyle get logo => GoogleFonts.sora(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );
}
