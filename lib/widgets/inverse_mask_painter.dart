import 'package:flutter/material.dart';

class InverseMaskPainter extends CustomPainter {
  final Rect hole;

  InverseMaskPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;

    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(fullRect),
      Path()..addOval(hole),
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
