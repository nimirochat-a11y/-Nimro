import 'package:flutter/material.dart';

class BorderRoundedButton extends StatelessWidget {
  final String image;
  final Color color;
  final VoidCallback? onTap;
  final double? padding;
  final double? width;
  final double? height;
  final Color? bgColor;

  const BorderRoundedButton(
      {super.key,
      required this.image,
      required this.color,
      this.onTap,
      this.padding,
      this.width,
      this.height,
      this.bgColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: height ?? 34,
        width: width ?? 34,
        padding: EdgeInsets.all(padding ?? 0),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: color)),
        alignment: Alignment.center,
        child: Image.asset(image, color: color, width: 24, height: 24),
      ),
    );
  }
}
