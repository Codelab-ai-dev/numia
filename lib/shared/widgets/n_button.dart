import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/n_colors.dart';
import '../constants/n_spacing.dart';
import '../constants/n_typography.dart';

enum NButtonVariant { primary, secondary, ghost, danger }
enum NButtonSize { lg, sm, xs }

class NButton extends StatelessWidget {
  const NButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NButtonVariant.primary,
    this.size = NButtonSize.lg,
    this.fullWidth = true,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final NButtonVariant variant;
  final NButtonSize size;
  final bool fullWidth;
  final Widget? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    final height = switch (size) {
      NButtonSize.lg => 52.0,
      NButtonSize.sm => 36.0,
      NButtonSize.xs => 28.0,
    };

    final padding = switch (size) {
      NButtonSize.lg => const EdgeInsets.symmetric(horizontal: 28),
      NButtonSize.sm => const EdgeInsets.symmetric(horizontal: 18),
      NButtonSize.xs => const EdgeInsets.symmetric(horizontal: 12),
    };

    final radius = switch (size) {
      NButtonSize.lg => NSpacing.rMd,
      NButtonSize.sm => NSpacing.rSm,
      NButtonSize.xs => NSpacing.rXs,
    };

    final textStyle = NTypography.button.copyWith(
      fontSize: switch (size) {
        NButtonSize.lg => 15.0,
        NButtonSize.sm => 13.0,
        NButtonSize.xs => 12.0,
      },
    );

    Widget content = isLoading
        ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(label, style: textStyle),
            ],
          );

    return switch (variant) {
      NButtonVariant.primary => _GradientButton(
          onPressed: onPressed,
          height: height,
          padding: padding,
          radius: radius,
          fullWidth: fullWidth,
          child: content,
        ),
      NButtonVariant.secondary => _GlassButton(
          onPressed: onPressed,
          height: height,
          padding: padding,
          radius: radius,
          fullWidth: fullWidth,
          ct: ct,
          child: content,
        ),
      NButtonVariant.ghost => _OutlinedButton(
          onPressed: onPressed,
          height: height,
          padding: padding,
          radius: radius,
          fullWidth: fullWidth,
          bg: Colors.transparent,
          border: ct.borderSubtle,
          child: content,
        ),
      NButtonVariant.danger => _OutlinedButton(
          onPressed: onPressed,
          height: height,
          padding: padding,
          radius: radius,
          fullWidth: fullWidth,
          bg: NColors.errorSoft,
          border: NColors.error,
          child: content,
        ),
    };
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.height,
    required this.padding,
    required this.radius,
    required this.fullWidth,
    required this.child,
  });

  final VoidCallback? onPressed;
  final double height;
  final EdgeInsets padding;
  final double radius;
  final bool fullWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: height,
          width: fullWidth ? double.infinity : null,
          padding: padding,
          decoration: BoxDecoration(
            gradient: NColors.grad,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [NColors.glowIndigo],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.onPressed,
    required this.height,
    required this.padding,
    required this.radius,
    required this.fullWidth,
    required this.ct,
    required this.child,
  });

  final VoidCallback? onPressed;
  final double height;
  final EdgeInsets padding;
  final double radius;
  final bool fullWidth;
  final NColorTheme ct;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: height,
            width: fullWidth ? double.infinity : null,
            padding: padding,
            decoration: BoxDecoration(
              color: ct.surface2,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: ct.borderDefault),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({
    required this.onPressed,
    required this.height,
    required this.padding,
    required this.radius,
    required this.fullWidth,
    required this.bg,
    required this.border,
    required this.child,
  });

  final VoidCallback? onPressed;
  final double height;
  final EdgeInsets padding;
  final double radius;
  final bool fullWidth;
  final Color bg;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
        width: fullWidth ? double.infinity : null,
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border),
        ),
        child: Center(child: child),
      ),
    );
  }
}
