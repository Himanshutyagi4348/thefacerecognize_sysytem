import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../camera/frame_processor.dart';
import '../../camera/camera_service.dart';
import '../../ml/detection/face_detection_service.dart';
import '../../ml/recognition/face_engine.dart';
import '../../core/enums/face_mode.dart' hide FaceMode;
import '../../core/state/face_state.dart';

class RegistrationController extends ChangeNotifier {
  /// =========================
  /// STATE
  /// =========================
  String status = "Initializing...";
  bool isRunning = false;

  StreamSubscription? _frameSub;
  bool _isProcessing = false;

  /// =========================
  /// START REGISTRATION
  /// =========================
  Future<void> start(String name) async {
    if (isRunning) return;

    isRunning = true;
    status = "Starting registration...";
    notifyListeners();

    FaceEngine.instance.setMode(FaceMode.register);
    FaceEngine.instance.currentUserName = name;

    status = "Look at camera 👀";
    notifyListeners();

    _frameSub = CameraService.instance.frameStream.listen((frame) async {
      if (_isProcessing) return;
      _isProcessing = true;

      await _processFrame(frame, name);

      _isProcessing = false;
    });
  }

  /// =========================
  /// PROCESS FRAME
  /// =========================
  Future<void> _processFrame(CameraImage frame, String name) async {
    try {
      final processed = await FrameProcessor.instance.processFrame(frame);

      if (processed == null || processed.isEmpty) return;

      final inputImage = InputImage.fromBytes(
        bytes: processed,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.width,
        ),
      );

      final faces = await FaceDetectionService.instance.detectFaces(inputImage);

      if (faces.isEmpty) {
        status = "No face detected";
        notifyListeners();
        return;
      }

      final result = await FaceEngine.instance.processFrame(
        inputImage: inputImage,
        faces: faces,
        name: name,
      );

      if (result == null) return;

      status = result;
      notifyListeners();

      if (result == "REGISTERED") {
        stop();
      }
    } catch (e) {
      status = "Error: $e";
      notifyListeners();
    }
  }

  /// =========================
  /// STOP
  /// =========================
  void stop() {
    isRunning = false;
    _frameSub?.cancel();
    _frameSub = null;

    status = "Stopped";
    notifyListeners();
  }

  /// =========================
  /// RESET
  /// =========================
  void reset() {
    stop();
    FaceEngine.instance.reset();
    status = "Ready";
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
