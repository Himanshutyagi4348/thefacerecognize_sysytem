

import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceQualityChecker {
  FaceQualityChecker._();
  static final FaceQualityChecker instance = FaceQualityChecker._();

  /// minimum face size (relative)
  final double minFaceWidthRatio = 0.25;

  /// max face angle allowed
  final double maxHeadAngle = 15.0;

  /// =========================
  /// MAIN QUALITY CHECK
  /// =========================
  bool isGoodFace(Face face, Size imageSize) {
    return _checkSize(face, imageSize) &&
        _checkHeadAngle(face) &&
        _checkOcclusion(face);
  }

  /// =========================
  /// FACE SIZE CHECK
  /// =========================
  bool _checkSize(Face face, Size imageSize) {
    final box = face.boundingBox;

    final faceWidthRatio = box.width / imageSize.width;

    return faceWidthRatio >= minFaceWidthRatio;
  }

  /// =========================
  /// HEAD ANGLE CHECK
  /// =========================
  bool _checkHeadAngle(Face face) {
    final rotY = face.headEulerAngleY ?? 0; // left/right
    final rotZ = face.headEulerAngleZ ?? 0; // tilt

    return rotY.abs() < maxHeadAngle && rotZ.abs() < maxHeadAngle;
  }

  /// =========================
  /// OCCLUSION CHECK (basic heuristic)
  /// =========================
  bool _checkOcclusion(Face face) {
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;

    /// if both eyes heavily blocked → reject
    if (leftEye < 0.2 && rightEye < 0.2) {
      return false;
    }

    return true;
  }
}
