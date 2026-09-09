import 'package:flutter/material.dart';
import 'package:nimiro/utilities/color_res.dart';

class ThemeBlurBg extends StatefulWidget {
  const ThemeBlurBg({super.key});

  @override
  State<ThemeBlurBg> createState() => _ThemeBlurBgState();
}

class _ThemeBlurBgState extends State<ThemeBlurBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = Curves.easeInOut.transform(_controller.value);
          final begin = Alignment.lerp(
            Alignment.topLeft,
            Alignment(-0.25 + progress * .5, -0.75),
            progress,
          )!;
          final end = Alignment.lerp(
            Alignment.bottomRight,
            Alignment(0.8, 0.35 + progress * .45),
            progress,
          )!;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: const [
                  Color(0xFF020817),
                  ColorRes.themeColor,
                  Color(0xFF0A2B5E),
                  Color(0xFF07152F),
                ],
                stops: const [0.0, 0.35, 0.72, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
