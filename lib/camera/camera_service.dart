import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';

class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  CameraController? _controller;
  bool _isInitialized = false;

  /// stream of frames
  final StreamController<CameraImage> _frameStream =
      StreamController<CameraImage>.broadcast();

  Stream<CameraImage> get frameStream => _frameStream.stream;

  /// =========================
  /// INIT CAMERA
  /// =========================
  Future<void> initialize() async {
    final cameras = await availableCameras();

    _controller = CameraController(
      cameras.first,
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

    print("📷 Camera initialized");
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
