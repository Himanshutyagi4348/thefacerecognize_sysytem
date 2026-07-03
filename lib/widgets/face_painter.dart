// face_painter.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final String? label;
  final bool isFrontCamera;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.rotation,
    this.label,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.green;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final face in faces) {
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
        rotation: rotation,
      );

      canvas.drawRect(rect, paint);

      if (label != null) {
        final textSpan = TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 14,
            backgroundColor: Colors.black54,
          ),
        );

        textPainter.text = textSpan;
        textPainter.layout();

        textPainter.paint(canvas, Offset(rect.left, rect.top - 18));
      }
    }
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
    required InputImageRotation rotation,
  }) {
    double scaleX = widgetSize.width / imageSize.width;
    double scaleY = widgetSize.height / imageSize.height;

    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      scaleX = widgetSize.width / imageSize.height;
      scaleY = widgetSize.height / imageSize.width;
    }

    double left = rect.left * scaleX;
    double right = rect.right * scaleX;
    double top = rect.top * scaleY;
    double bottom = rect.bottom * scaleY;

    // Front camera mirroring fix
    if (isFrontCamera) {
      final newLeft = widgetSize.width - right;
      final newRight = widgetSize.width - left;
      left = newLeft;
      right = newRight;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.label != label ||
        oldDelegate.imageSize != imageSize;
  }
}
