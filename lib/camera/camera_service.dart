import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  CameraController? _controller;
  bool _isInitialized = false;
  final List<CameraDescription> _availableCameras = [];
  int _cameraIndex = 0;

  /// stream of frames
  final StreamController<CameraImage> _frameStream =
      StreamController<CameraImage>.broadcast();

  Stream<CameraImage> get frameStream => _frameStream.stream;

  CameraDescription? get currentCamera =>
      _availableCameras.isNotEmpty ? _availableCameras[_cameraIndex] : null;

  CameraLensDirection get currentLensDirection =>
      _controller?.description.lensDirection ?? CameraLensDirection.front;

  /// =========================
  /// INIT CAMERA
  /// =========================
  Future<void> initialize() async {
    final cameras = await availableCameras();
    _availableCameras.clear();
    _availableCameras.addAll(cameras);

    if (_availableCameras.isEmpty) {
      throw Exception("No cameras available");
    }

    _cameraIndex = 0;
    await _setupCamera(_availableCameras[_cameraIndex]);
  }

  /// =========================
  /// SWITCH CAMERA
  /// =========================
  Future<void> flipCamera() async {
    if (_availableCameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _availableCameras.length;
    await _setupCamera(_availableCameras[_cameraIndex]);
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    try {
      await _controller?.dispose();
    } catch (_) {}

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    _isInitialized = true;

    _controller!.startImageStream((CameraImage image) {
      if (!_frameStream.isClosed) {
        _frameStream.add(image);
      }
    });

    debugPrint("📷 Camera initialized: ${camera.lensDirection}");
  }

  /// =========================
  /// GET LIVE STREAM
  /// =========================
  Stream<CameraImage> getFrames() {
    if (!_isInitialized) {
      throw Exception("Camera not initialized");
    }
    return frameStream;
  }

  /// =========================
  /// STOP CAMERA STREAM
  /// =========================
  Future<void> stop() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _frameStream.close();
    _isInitialized = false;
  }

  /// =========================
  /// CAMERA PREVIEW
  /// =========================
  CameraController? get controller => _controller;

  bool get isInitialized => _isInitialized;
}
