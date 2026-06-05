import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/n_colors.dart';
import '../constants/n_spacing.dart';

class NBottomNav extends StatelessWidget {
  const NBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.home_outlined,          activeIcon: Icons.home_rounded,          label: 'Inicio'),
    (icon: Icons.pie_chart_outline_rounded, activeIcon: Icons.pie_chart_rounded,  label: 'Presupuesto'),
    (icon: Icons.swap_horiz_rounded,     activeIcon: Icons.swap_horiz_rounded,    label: 'Movimientos'),
    (icon: Icons.auto_awesome_outlined,  activeIcon: Icons.auto_awesome,          label: 'IA'),
    (icon: Icons.adjust_rounded,         activeIcon: Icons.adjust_rounded,        label: 'Metas'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,        label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding > 0 ? bottomPadding : 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NSpacing.rXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: ct.glassBlur / 2,
            sigmaY: ct.glassBlur / 2,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: ct.surface1,
              borderRadius: BorderRadius.circular(NSpacing.rXl),
              border: Border.all(color: ct.borderSubtle),
            ),
            child: Row(
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                final isActive = i == currentIndex;
                final isAI = i == 3;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? NColors.indigoSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(NSpacing.rMd),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: NColors.indigo.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? item.activeIcon : item.icon,
                            size: isAI ? 24 : 22,
                            color: isActive
                                ? ct.accent1
                                : isAI
                                    ? NColors.indigo
                                    : ct.textTertiary,
                            shadows: isAI
                                ? [Shadow(color: NColors.indigo.withValues(alpha: 0.5), blurRadius: 8)]
                                : null,
                          ),
                          if (isActive) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: ct.accent1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
