import 'package:flutter/material.dart';

// ─── Static brand / semantic colors (unchanged across themes) ───
abstract class NColors {
  // Brand — Frosted Neon Finance
  static const indigo      = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const emerald     = Color(0xFF10B981);
  static const emeraldLight = Color(0xFF34D399);
  static const amber       = Color(0xFFF59E0B);
  static const amberLight  = Color(0xFFFBBF24);
  static const indigoSoft  = Color(0x266366F1);
  static const emeraldSoft = Color(0x1F10B981);
  static const amberSoft   = Color(0x1FF59E0B);

  // Semantic
  static const success     = Color(0xFF22C55E);
  static const successSoft = Color(0x1F22C55E);
  static const warning     = Color(0xFFF59E0B);
  static const warningSoft = Color(0x1FF59E0B);
  static const error       = Color(0xFFFF6B8A);
  static const errorSoft   = Color(0x1FFF6B8A);
  static const info        = Color(0xFF38BDF8);
  static const infoSoft    = Color(0x1F38BDF8);

  // Gradients
  static const grad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF818CF8), Color(0xFF34D399)],
    stops: [0.0, 0.5, 1.0],
  );

  static const gradH = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF818CF8), Color(0xFF34D399)],
  );

  // Orb gradients for animated background
  static const orbIndigo = [Color(0xFF6366F1), Color(0xFF818CF8)];
  static const orbEmerald = [Color(0xFF10B981), Color(0xFF34D399)];
  static const orbAmber = [Color(0xFFF59E0B), Color(0xFFFBBF24)];

  // Glows
  static const glowIndigo = BoxShadow(
    color: Color(0x596366F1),
    blurRadius: 20,
  );

  static const glowEmerald = BoxShadow(
    color: Color(0x4D10B981),
    blurRadius: 20,
  );

  static const glowAmber = BoxShadow(
    color: Color(0x40F59E0B),
    blurRadius: 20,
  );
}

// ─── Theme-dependent colors via ThemeExtension ───
class NColorTheme extends ThemeExtension<NColorTheme> {
  const NColorTheme({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.shadowSm,
    required this.shadowMd,
    required this.accent1,
    required this.accent2,
    required this.accent3,
    required this.glassBlur,
  });

  final Color bg;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final BoxShadow shadowSm;
  final BoxShadow shadowMd;
  final Color accent1;
  final Color accent2;
  final Color accent3;
  final double glassBlur;

  // ── Dark theme ──
  factory NColorTheme.dark() => const NColorTheme(
    bg:            Color(0xFF0A0A0F),
    surface1:      Color(0x0DFFFFFF), // white 5%
    surface2:      Color(0x14FFFFFF), // white 8%
    surface3:      Color(0x1FFFFFFF), // white 12%
    borderSubtle:  Color(0x14FFFFFF), // white 8%
    borderDefault: Color(0x1FFFFFFF), // white 12%
    borderStrong:  Color(0x33FFFFFF), // white 20%
    textPrimary:   Color(0xFFF8FAFC),
    textSecondary: Color(0x99FFFFFF), // white 60%
    textTertiary:  Color(0x59FFFFFF), // white 35%
    textDisabled:  Color(0x26FFFFFF),
    shadowSm: BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2)),
    shadowMd: BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)),
    accent1:   Color(0xFF818CF8), // Indigo
    accent2:   Color(0xFF34D399), // Emerald
    accent3:   Color(0xFFFBBF24), // Amber
    glassBlur: 24.0,
  );

  // ── Light theme ──
  factory NColorTheme.light() => const NColorTheme(
    bg:            Color(0xFFF0F0F7),
    surface1:      Color(0xB3FFFFFF), // white 70%
    surface2:      Color(0x80FFFFFF), // white 50%
    surface3:      Color(0x66FFFFFF), // white 40%
    borderSubtle:  Color(0x0F000000), // black 6%
    borderDefault: Color(0x1A000000), // black 10%
    borderStrong:  Color(0x2D000000),
    textPrimary:   Color(0xFF0F172A),
    textSecondary: Color(0x8C000000), // black 55%
    textTertiary:  Color(0x4D000000),
    textDisabled:  Color(0x26000000),
    shadowSm: BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
    shadowMd: BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
    accent1:   Color(0xFF6366F1), // Indigo
    accent2:   Color(0xFF10B981), // Emerald
    accent3:   Color(0xFFF59E0B), // Amber
    glassBlur: 20.0,
  );

  // ── Helper for easy access ──
  static NColorTheme of(BuildContext context) =>
      Theme.of(context).extension<NColorTheme>()!;

  @override
  NColorTheme copyWith({
    Color? bg,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    BoxShadow? shadowSm,
    BoxShadow? shadowMd,
    Color? accent1,
    Color? accent2,
    Color? accent3,
    double? glassBlur,
  }) {
    return NColorTheme(
      bg:            bg ?? this.bg,
      surface1:      surface1 ?? this.surface1,
      surface2:      surface2 ?? this.surface2,
      surface3:      surface3 ?? this.surface3,
      borderSubtle:  borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderStrong:  borderStrong ?? this.borderStrong,
      textPrimary:   textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary:  textTertiary ?? this.textTertiary,
      textDisabled:  textDisabled ?? this.textDisabled,
      shadowSm:      shadowSm ?? this.shadowSm,
      shadowMd:      shadowMd ?? this.shadowMd,
      accent1:       accent1 ?? this.accent1,
      accent2:       accent2 ?? this.accent2,
      accent3:       accent3 ?? this.accent3,
      glassBlur:     glassBlur ?? this.glassBlur,
    );
  }

  @override
  NColorTheme lerp(NColorTheme? other, double t) {
    if (other == null) return this;
    return NColorTheme(
      bg:            Color.lerp(bg, other.bg, t)!,
      surface1:      Color.lerp(surface1, other.surface1, t)!,
      surface2:      Color.lerp(surface2, other.surface2, t)!,
      surface3:      Color.lerp(surface3, other.surface3, t)!,
      borderSubtle:  Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderDefault: Color.lerp(borderDefault, other.borderDefault, t)!,
      borderStrong:  Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary:   Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary:  Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled:  Color.lerp(textDisabled, other.textDisabled, t)!,
      shadowSm:      BoxShadow.lerp(shadowSm, other.shadowSm, t)!,
      shadowMd:      BoxShadow.lerp(shadowMd, other.shadowMd, t)!,
      accent1:       Color.lerp(accent1, other.accent1, t)!,
      accent2:       Color.lerp(accent2, other.accent2, t)!,
      accent3:       Color.lerp(accent3, other.accent3, t)!,
      glassBlur:     glassBlur + (other.glassBlur - glassBlur) * t,
    );
  }
}
