import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../constants.dart';
import '../db/embedding_db.dart';
import 'package:face_recognition/services/face_detector_service.dart' as fds;
import 'package:face_recognition/services/embedding_service.dart' as embs;
import 'package:face_recognition/services/tts_service.dart' as tts;
import '../utils/similarity_utils.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isProcessing = false;
  bool _isVerified = false;
  bool _isDenied = false;

  // StreamSubscription? _cameraStream; // camera controller handles stream lifecycle

  @override
  void initState() {
    super.initState();
    kDebugLog('VerifyScreen: initState');
    _initialize();
  }

  Future<void> _initialize() async {
    await embs.EmbeddingService.instance.loadModel();
    await _initCamera();
  }

  /// ===============================================================
  /// INIT CAMERA
  /// ===============================================================
  Future<void> _initCamera() async {
    kDebugLog('VerifyScreen: loading available cameras');
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      kDebugLog('VerifyScreen: no cameras found');
      return;
    }

    _cameraController = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    kDebugLog(
      'VerifyScreen: camera initialized (${_cameras[_selectedCameraIndex].name})',
    );
    _startStream();
    setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _cameraController == null) return;

    await _cameraController!.dispose();

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    kDebugLog(
      'VerifyScreen: switching camera to index $_selectedCameraIndex (${_cameras[_selectedCameraIndex].name})',
    );
    _cameraController = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    _startStream();
    setState(() {});
  }

  /// ===============================================================
  /// START FRAME STREAM
  /// ===============================================================
  void _startStream() {
    kDebugLog('VerifyScreen: starting camera image stream');
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessing || _isVerified || _isDenied) return;

      _isProcessing = true;

      try {
        final frame = _convertCameraImage(image);
        kDebugLog('VerifyScreen: processing new camera frame');

        /// 1. Detect face
        /// Built straight from the native CameraImage planes (nv21 on
        /// Android / bgra8888 on iOS) instead of the RGB-converted
        /// `frame` — ML Kit's Android fromBytes API only accepts nv21,
        /// so detection was silently failing on every frame before.
        /// `frame` is still used below purely for cropping the face
        /// out for the embedding model.
        final detection = await fds.FaceDetectorService.instance
            .detectFromCameraImage(
              image,
              frame,
              rotation: _rotationForCamera(_cameras[_selectedCameraIndex]),
            );

        if (detection == null) {
          kDebugLog('VerifyScreen: no face detected in frame');
          _isProcessing = false;
          return;
        }

        final cropped = detection.croppedFace;
        final faceBox = detection.boundingBox;

        kDebugLog('VerifyScreen: face detected, generating embedding');

        /// 2. Get embedding
        final embedding = await embs.EmbeddingService.instance.getEmbedding(
          cropped,
        );

        /// 3. Get all users
        final userIds = await EmbeddingDb.instance.getRegisteredUserIds();

        bool found = false;

        for (final userId in userIds) {
          final storedEmbeddings = await EmbeddingDb.instance
              .getEmbeddingModels(userId);

          final score = SimilarityUtils.getBestMatchScore(
            embedding,
            storedEmbeddings,
          );
          kDebugLog('VerifyScreen: score for user "$userId" = $score');

          if (SimilarityUtils.isMatch(score)) {
            found = true;
            _isVerified = true;

            await tts.TTSService.instance.speakWelcome(userId);

            if (mounted) {
              setState(() {});
            }
            break;
          }
        }

        if (!found) {
          kDebugLog('VerifyScreen: no matching user found — access denied');
          _isDenied = true;

          await tts.TTSService.instance.speakAccessDenied();

          if (mounted) {
            setState(() {});
          }

          _scheduleDeniedReset();
        }
      } catch (e) {
        kDebugLog('VerifyScreen: error during verification stream: $e');
        await tts.TTSService.instance.speakError();
      }

      _isProcessing = false;
    });
  }

  /// ===============================================================
  /// RESUME SCANNING AFTER A DENIAL
  /// ===============================================================
  void _scheduleDeniedReset() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _isDenied = false;
      });
    });
  }

  /// ===============================================================
  /// ROTATION FOR ML KIT (based on the camera's actual sensor
  /// orientation, instead of a hardcoded value that was wrong for
  /// some cameras/devices)
  /// ===============================================================
  InputImageRotation _rotationForCamera(CameraDescription camera) {
    switch (camera.sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  /// ===============================================================
  /// CONVERT CAMERA IMAGE → IMAGE PACKAGE FORMAT
  /// ===============================================================
  img.Image _convertCameraImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final imgData = img.Image(width, height);

    if (image.format.group == ImageFormatGroup.yuv420 &&
        image.planes.length >= 3) {
      final planeY = image.planes[0];
      final planeU = image.planes[1];
      final planeV = image.planes[2];

      final uvRowStride = planeU.bytesPerRow;
      final uvPixelStride = planeU.bytesPerPixel ?? 1;
      final uvRowStrideV = planeV.bytesPerRow;
      final uvPixelStrideV = planeV.bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * planeY.bytesPerRow + x;
          final uvIndex = (x ~/ 2) * uvPixelStride + (y ~/ 2) * uvRowStride;
          final uvIndexV = (x ~/ 2) * uvPixelStrideV + (y ~/ 2) * uvRowStrideV;

          final yValue = planeY.bytes[yIndex];
          final uValue = planeU.bytes[uvIndex];
          final vValue = planeV.bytes[uvIndexV];

          final yAdjusted = yValue.toDouble();
          final uAdjusted = uValue.toDouble() - 128;
          final vAdjusted = vValue.toDouble() - 128;

          int r = (yAdjusted + 1.402 * vAdjusted).round();
          int g = (yAdjusted - 0.344136 * uAdjusted - 0.714136 * vAdjusted)
              .round();
          int b = (yAdjusted + 1.772 * uAdjusted).round();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          imgData.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    } else if (image.format.group == ImageFormatGroup.bgra8888 &&
        image.planes.isNotEmpty) {
      final plane = image.planes[0];
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final i = y * plane.bytesPerRow + x * 4;
          final b = plane.bytes[i];
          final g = plane.bytes[i + 1];
          final r = plane.bytes[i + 2];
          imgData.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    } else {
      kDebugLog('VerifyScreen: unsupported image format ${image.format.group}');
    }

    return imgData;
  }

  /// ===============================================================
  /// UI
  /// ===============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(_cameraController!),

                /// Overlay
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: _switchCamera,
                              icon: const Icon(
                                Icons.flip_camera_android,
                                color: Colors.white,
                              ),
                              tooltip: 'Switch camera',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isVerified
                              ? "ACCESS GRANTED"
                              : _isDenied
                              ? "ACCESS DENIED"
                              : "Scanning Face...",
                          style: TextStyle(
                            color: _isVerified
                                ? Colors.green
                                : _isDenied
                                ? Colors.red
                                : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                /// Success indicator
                if (_isVerified)
                  const Center(
                    child: Icon(Icons.verified, color: Colors.green, size: 120),
                  ),

                /// Denied indicator
                if (_isDenied)
                  const Center(
                    child: Icon(Icons.cancel, color: Colors.red, size: 120),
                  ),
              ],
            ),
    );
  }

  /// ===============================================================
  /// DISPOSE
  /// ===============================================================
  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
