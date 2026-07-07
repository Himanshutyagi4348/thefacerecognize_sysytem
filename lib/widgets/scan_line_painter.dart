import 'package:flutter/material.dart';

class ScanLinePainter extends CustomPainter {
  final double position;

  ScanLinePainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2;

    final y = size.height * position;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter oldDelegate) {
    return oldDelegate.position != position;
  }
}
