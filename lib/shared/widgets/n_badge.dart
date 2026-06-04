import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/n_colors.dart';
import '../constants/n_spacing.dart';

enum NBadgeVariant { success, error, warning, info, indigo, emerald }

class NBadge extends StatelessWidget {
  const NBadge({
    super.key,
    required this.label,
    this.variant = NBadgeVariant.indigo,
    this.icon,
  });

  final String label;
  final NBadgeVariant variant;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    final (bg, fg) = switch (variant) {
      NBadgeVariant.success => (NColors.successSoft, NColors.success),
      NBadgeVariant.error   => (NColors.errorSoft,   NColors.error),
      NBadgeVariant.warning => (NColors.warningSoft,  NColors.warning),
      NBadgeVariant.info    => (NColors.infoSoft,     NColors.info),
      NBadgeVariant.indigo  => (NColors.indigoSoft,   ct.accent1),
      NBadgeVariant.emerald => (NColors.emeraldSoft,  ct.accent2),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(NSpacing.rFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NSpacing.sp2 + 2,
            vertical: NSpacing.sp1,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(NSpacing.rFull),
            border: Border.all(color: fg.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Text(icon!, style: TextStyle(fontSize: 10, color: fg)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
