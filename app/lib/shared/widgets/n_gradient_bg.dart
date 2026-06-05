import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/n_colors.dart';

class NGradientBg extends StatefulWidget {
  const NGradientBg({super.key, required this.child});
  final Widget child;

  @override
  State<NGradientBg> createState() => _NGradientBgState();
}

class _NGradientBgState extends State<NGradientBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Base background
        Positioned.fill(
          child: ColoredBox(color: ct.bg),
        ),

        // Animated orbs
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            return Stack(
              children: [
                // Indigo orb — top right
                Positioned(
                  top: -80 + math.sin(t * 2 * math.pi) * 30,
                  right: -60 + math.cos(t * 2 * math.pi) * 20,
                  child: _Orb(
                    size: 300,
                    colors: NColors.orbIndigo,
                    opacity: isDark ? 0.25 : 0.12,
                  ),
                ),
                // Emerald orb — bottom left
                Positioned(
                  bottom: -100 + math.cos(t * 2 * math.pi + 1) * 25,
                  left: -80 + math.sin(t * 2 * math.pi + 1) * 20,
                  child: _Orb(
                    size: 280,
                    colors: NColors.orbEmerald,
                    opacity: isDark ? 0.20 : 0.10,
                  ),
                ),
                // Amber orb — center, smaller
                Positioned(
                  top: 200 + math.sin(t * 2 * math.pi + 2) * 40,
                  right: 40 + math.cos(t * 2 * math.pi + 2) * 30,
                  child: _Orb(
                    size: 180,
                    colors: NColors.orbAmber,
                    opacity: isDark ? 0.12 : 0.06,
                  ),
                ),
              ],
            );
          },
        ),

        // Content
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.size,
    required this.colors,
    required this.opacity,
  });

  final double size;
  final List<Color> colors;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.first.withValues(alpha: opacity),
            colors.last.withValues(alpha: opacity * 0.3),
            colors.last.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
