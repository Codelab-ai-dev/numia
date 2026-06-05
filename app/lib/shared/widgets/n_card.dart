import 'package:flutter/material.dart';
import 'n_glass_card.dart';

enum NCardVariant { default_, featured, glass }

/// Legacy NCard — delegates to NGlassCard for the new glassmorphism design.
class NCard extends StatelessWidget {
  const NCard({
    super.key,
    required this.child,
    this.variant = NCardVariant.default_,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final NCardVariant variant;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glassVariant = switch (variant) {
      NCardVariant.default_  => NGlassVariant.default_,
      NCardVariant.featured  => NGlassVariant.featured,
      NCardVariant.glass     => NGlassVariant.default_,
    };

    return NGlassCard(
      variant: glassVariant,
      padding: padding,
      onTap: onTap,
      child: child,
    );
  }
}
