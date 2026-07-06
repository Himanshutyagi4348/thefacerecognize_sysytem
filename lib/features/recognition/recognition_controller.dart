import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../camera/camera_service.dart';
import '../../camera/frame_processor.dart';
import '../../data/database/face_db.dart';
import '../../ml/detection/face_detection_service.dart';
import '../../ml/recognition/face_engine.dart';
import '../../services/tts_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/state/face_state.dart';

class RecognitionController extends ChangeNotifier {
  StreamSubscription? _streamSub;

  bool isRunning = false;
  bool _isProcessing = false;

  bool adminLoginRequested = false;
  bool isAdminAuthenticated = false;
  bool isRegistering = false;
  String registrationName = "";
  String adminError = "";
  int registrationCount = 0;
  int _lastPromptedStep = -1;
  final List<String> registrationSteps = [
    'Front',
    'Left',
    'Right',
    'Top',
    'Bottom',
  ];
  List<Face> detectedFaces = [];
  Timer? _unknownRedirectTimer;
  bool redirectToRegistrationRequested = false;
  static const Duration unknownFaceRedirectDelay = Duration(seconds: 5);

  String get registrationInstruction {
    if (registrationCount < 0 ||
        registrationCount >= registrationSteps.length) {
      return registrationSteps.last;
    }
    return registrationSteps[registrationCount];
  }

  Size? imageSize;

  void _cancelUnknownRedirect() {
    _unknownRedirectTimer?.cancel();
    _unknownRedirectTimer = null;
    if (redirectToRegistrationRequested) {
      redirectToRegistrationRequested = false;
      notifyListeners();
    }
  }

  void _scheduleUnknownRedirect() {
    if (_unknownRedirectTimer != null || redirectToRegistrationRequested)
      return;
    _unknownRedirectTimer = Timer(unknownFaceRedirectDelay, () {
      redirectToRegistrationRequested = true;
      notifyListeners();
    });
  }

  void clearRedirectRequest() {
    if (!redirectToRegistrationRequested) return;
    redirectToRegistrationRequested = false;
    notifyListeners();
  }

  /// =========================
  /// START RECOGNITION
  /// =========================
  Future<void> start() async {
    if (isRunning) return;

    isRunning = true;
    adminLoginRequested = false;
    isAdminAuthenticated = false;
    isRegistering = false;
    registrationName = "";
    registrationCount = 0;
    adminError = "";
    _cancelUnknownRedirect();

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

      if (adminLoginRequested) {
        _cancelUnknownRedirect();
        return;
      }

      /// 2. Build metadata (IMPORTANT FIX)
      final metadata = InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: InputImageRotation.rotation0deg, // adjust if needed
        format: InputImageFormat.nv21, // common for Android camera
        bytesPerRow: frame.planes[0].bytesPerRow,
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
        detectedFaces = [];
        _cancelUnknownRedirect();
        notifyListeners();
        return;
      }

      detectedFaces = faces;
      imageSize = Size(frame.width.toDouble(), frame.height.toDouble());
      FaceState.faceDetected = true;

      /// 5. Face recognition or registration
      final result = await FaceEngine.instance.processFrame(
        cameraImage: frame,
        inputImage: inputImage,
        faces: faces,
        name: isRegistering ? registrationName : null,
      );

      if (result == null) return;

      /// 6. Parse result
      if (isRegistering) {
        if (result.startsWith("COLLECTING")) {
          final match = RegExp(r"COLLECTING \((\d+)/").firstMatch(result);
          final count = match != null
              ? int.parse(match.group(1)!)
              : registrationCount;
          if (count != registrationCount) {
            registrationCount = count;
            FaceState.updateRegistration(registrationCount, registrationName);
            FaceState.updateStatus(
              "Capture $registrationInstruction face ($registrationCount/${AppConstants.requiredEmbeddings})",
            );
            if (_lastPromptedStep != registrationCount &&
                registrationCount < registrationSteps.length) {
              _lastPromptedStep = registrationCount;
              TTSService.instance.guideFacePosition(
                registrationInstruction.toLowerCase(),
              );
            }
          }
        } else if (result == "REGISTERED") {
          isRegistering = false;
          adminLoginRequested = false;
          FaceEngine.instance.setMode(FaceMode.recognize);
          FaceState.updateStatus("User registered successfully");
          registrationCount = AppConstants.requiredEmbeddings;
          await TTSService.instance.speakSafe("User registered successfully");
        }
      } else if (result.startsWith("MATCH")) {
        final parts = result.split(" ");

        final name = parts.length > 1 ? parts[1] : "Unknown";
        final score = _extractScore(result);

        FaceState.updateRecognition(name, score);
        FaceState.updateStatus("Welcome $name 👋");
        _cancelUnknownRedirect();

        final userId = await FaceDB.getUserIdByName(name);
        if (userId != null) {
          final newAttendance = await FaceDB.markAttendance(userId);
          if (newAttendance) {
            await TTSService.instance.speakSafe("Welcome back, $name");
          }
        }
      } else if (result == "UNKNOWN") {
        FaceState.updateRecognition("Unknown", 0.0);
        FaceState.updateStatus("Unknown face ❌");
        _scheduleUnknownRedirect();
      } else {
        FaceState.updateStatus(result);
        _cancelUnknownRedirect();
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
  /// REQUEST ADMIN LOGIN
  /// =========================
  void requestAdminLogin() {
    _cancelUnknownRedirect();
    adminLoginRequested = true;
    FaceState.updateStatus("Admin login required");
    notifyListeners();
  }

  /// =========================
  /// ADMIN LOGIN
  /// =========================
  Future<bool> loginAdmin({
    required String username,
    required String password,
  }) async {
    final success = await FaceDB.validateAdmin(
      username: username,
      password: password,
    );

    if (!success) {
      adminError = "Invalid username or password";
      notifyListeners();
      return false;
    }

    adminError = "";
    isAdminAuthenticated = true;
    adminLoginRequested = false;
    notifyListeners();
    return true;
  }

  /// =========================
  /// START REGISTRATION
  /// =========================
  void beginRegistration(String name) {
    _cancelUnknownRedirect();
    isRegistering = true;
    registrationName = name;
    registrationCount = 0;
    FaceEngine.instance.setMode(FaceMode.register);
    FaceState.reset();
    FaceState.updateRegistration(0, name);
    FaceState.updateStatus("Registration started for $name");
    notifyListeners();
  }

  /// =========================
  /// STOP
  /// =========================
  void stop() {
    isRunning = false;
    _cancelUnknownRedirect();

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
