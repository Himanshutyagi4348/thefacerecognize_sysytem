import 'package:face_recognition/widgets/face_painter.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../camera/camera_service.dart';
import '../core/state/face_state.dart';

class CameraView extends StatelessWidget {
  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;

  const CameraView({
    super.key,
    required this.faces,
    required this.imageSize,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    final controller = CameraService.instance.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        /// =========================
        /// CAMERA PREVIEW
        /// =========================
        CameraPreview(controller),

        /// =========================
        /// FACE OVERLAY
        /// =========================
        CustomPaint(
          painter: FacePainter(
            faces: faces,
            imageSize: imageSize,
            rotation: rotation,
            label: FaceState.recognizedName,
          ),
          child: Container(),
        ),
      ],
    );
  }
}
