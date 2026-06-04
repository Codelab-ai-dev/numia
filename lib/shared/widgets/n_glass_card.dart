import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/n_colors.dart';
import '../constants/n_spacing.dart';

enum NGlassVariant { default_, featured, accent }

class NGlassCard extends StatelessWidget {
  const NGlassCard({
    super.key,
    required this.child,
    this.variant = NGlassVariant.default_,
    this.padding,
    this.onTap,
    this.accentColor,
  });

  final Widget child;
  final NGlassVariant variant;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color borderColor;
    List<BoxShadow> glowShadow;

    switch (variant) {
      case NGlassVariant.default_:
        bgColor = ct.surface1;
        borderColor = ct.borderSubtle;
        glowShadow = [];
      case NGlassVariant.featured:
        bgColor = ct.surface2;
        borderColor = ct.accent1.withValues(alpha: isDark ? 0.3 : 0.2);
        glowShadow = [
          BoxShadow(
            color: ct.accent1.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ];
      case NGlassVariant.accent:
        final ac = accentColor ?? ct.accent2;
        bgColor = ct.surface1;
        borderColor = ac.withValues(alpha: isDark ? 0.3 : 0.2);
        glowShadow = [
          BoxShadow(
            color: ac.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ];
    }

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(NSpacing.rXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ct.glassBlur / 2,
          sigmaY: ct.glassBlur / 2,
        ),
        child: Container(
          padding: padding ?? const EdgeInsets.all(NSpacing.sp6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(NSpacing.rXl),
            border: Border.all(color: borderColor),
            boxShadow: glowShadow,
          ),
          child: child,
        ),
      ),
    );

    if (variant == NGlassVariant.featured) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NSpacing.rXl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ct.accent1.withValues(alpha: isDark ? 0.08 : 0.05),
              ct.accent2.withValues(alpha: isDark ? 0.04 : 0.02),
            ],
          ),
        ),
        child: card,
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }
}
