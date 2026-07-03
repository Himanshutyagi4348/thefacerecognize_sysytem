import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class BlinkDetector {
  BlinkDetector._();
  static final BlinkDetector instance = BlinkDetector._();

  int _blinkCount = 0;
  bool _eyeClosed = false;

  /// threshold for ML Kit eye open probability
  final double eyeClosedThreshold = 0.4;

  /// =========================
  /// RESET
  /// =========================
  void reset() {
    _blinkCount = 0;
    _eyeClosed = false;
  }

  /// =========================
  /// PROCESS FACE FOR BLINK
  /// =========================
  bool process(Face face) {
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;

    final avgEye = (leftEye + rightEye) / 2;

    /// eyes closed
    if (avgEye < eyeClosedThreshold) {
      _eyeClosed = true;
    }

    /// eyes opened after being closed → blink detected
    if (avgEye > 0.6 && _eyeClosed) {
      _blinkCount++;
      _eyeClosed = false;
    }

    return _blinkCount >= 1;
  }

  /// =========================
  /// GET BLINK COUNT
  /// =========================
  int get blinkCount => _blinkCount;

  /// =========================
  /// CHECK IF USER IS LIVE
  /// =========================
  bool isLive() {
    return _blinkCount >= 1;
  }
}
