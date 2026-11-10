import 'package:flutter/material.dart';

class ViewfinderPainter extends CustomPainter {
  final double squareSize;
  final double topOffset;
  final double horizontalPadding;
  final double borderRadius;

  ViewfinderPainter({
    required this.squareSize,
    required this.topOffset,
    required this.horizontalPadding,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    final cutout = RRect.fromRectAndRadius(
      Rect.fromLTWH(horizontalPadding, topOffset, squareSize, squareSize),
      Radius.circular(borderRadius),
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutout);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ViewfinderPainter oldDelegate) =>
      squareSize != oldDelegate.squareSize || topOffset != oldDelegate.topOffset;
}
