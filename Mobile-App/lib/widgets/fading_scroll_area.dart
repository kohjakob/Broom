import 'package:flutter/material.dart';

class FadingScrollArea extends StatefulWidget {
  final Widget child;

  const FadingScrollArea({super.key, required this.child});

  @override
  State<FadingScrollArea> createState() => _FadingScrollAreaState();
}

class _FadingScrollAreaState extends State<FadingScrollArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_breathController.value);
        final bottomStop = 0.95 - t * 0.03;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Colors.black, Colors.black, Colors.transparent],
            stops: [0.0, bottomStop, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
