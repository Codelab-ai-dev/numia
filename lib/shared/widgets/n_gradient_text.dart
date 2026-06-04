import 'package:flutter/material.dart';
import '../constants/n_colors.dart';

class NGradientText extends StatelessWidget {
  const NGradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = NColors.gradH,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}
