import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../camera/camera_service.dart';
import '../../camera/frame_processor.dart';
import '../../ml/detection/face_detection_service.dart';
import '../../ml/recognition/face_engine.dart';
import '../../core/state/face_state.dart';

class RecognitionController extends ChangeNotifier {
  StreamSubscription? _streamSub;

  bool isRunning = false;
  bool _isProcessing = false;

  /// =========================
  /// START RECOGNITION
  /// =========================
  Future<void> start() async {
    if (isRunning) return;

    isRunning = true;
    FaceState.updateStatus("Starting recognition...");

    FaceEngine.instance.setMode(FaceMode.recognize);

    _streamSub = CameraService.instance.frameStream.listen((frame) async {
      if (_isProcessing) return;
      _isProcessing = true;

      await _processFrame(frame);

      _isProcessing = false;
    });

    notifyListeners();
  }

  /// =========================
  /// PROCESS FRAME
  /// =========================
  Future<void> _processFrame(dynamic frame) async {
    try {
      /// 1. Convert frame → bytes
      final Uint8List? processed = await FrameProcessor.instance.processFrame(
        frame,
      );

      if (processed == null || processed.isEmpty) return;

      /// 2. Build metadata (IMPORTANT FIX)
      final metadata = InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: InputImageRotation.rotation0deg, // adjust if needed
        format: InputImageFormat.nv21, // common for Android camera
        bytesPerRow: frame.width,
      );

      /// 3. Create InputImage
      final inputImage = InputImage.fromBytes(
        bytes: processed,
        metadata: metadata,
      );

      /// 4. Detect faces
      final faces = await FaceDetectionService.instance.detectFaces(inputImage);

      if (faces.isEmpty) {
        FaceState.updateStatus("No face detected");
        FaceState.faceDetected = false;
        notifyListeners();
        return;
      }

      FaceState.faceDetected = true;

      /// 5. Face recognition
      final result = await FaceEngine.instance.processFrame(
        inputImage: inputImage,
        faces: faces,
      );

      if (result == null) return;

      /// 6. Parse result
      if (result.startsWith("MATCH")) {
        final parts = result.split(" ");

        final name = parts.length > 1 ? parts[1] : "Unknown";
        final score = _extractScore(result);

        FaceState.updateRecognition(name, score);
        FaceState.updateStatus("Welcome $name 👋");
      } else if (result == "UNKNOWN") {
        FaceState.updateRecognition("Unknown", 0.0);
        FaceState.updateStatus("Unknown face ❌");
      } else {
        FaceState.updateStatus(result);
      }

      notifyListeners();
    } catch (e) {
      FaceState.updateStatus("Error: $e");
      notifyListeners();
    }
  }

  /// =========================
  /// EXTRACT SCORE
  /// =========================
  double _extractScore(String text) {
    final match = RegExp(r"\(([^)]+)\)").firstMatch(text);

    if (match != null) {
      return double.tryParse(match.group(1) ?? "0") ?? 0.0;
    }

    return 0.0;
  }

  /// =========================
  /// STOP
  /// =========================
  void stop() {
    isRunning = false;

    _streamSub?.cancel();
    _streamSub = null;

    FaceState.updateStatus("Stopped");
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
