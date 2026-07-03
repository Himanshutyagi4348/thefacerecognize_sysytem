import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'dart:async';

class FrameProcessor {
  FrameProcessor._();
  static final FrameProcessor instance = FrameProcessor._();

  /// controls FPS throttling
  DateTime? _lastProcessTime;

  /// allow only 10–15 FPS processing (important for performance)
  final int minFrameIntervalMs = 80;

  bool _isProcessing = false;

  /// =========================
  /// PROCESS FRAME SAFELY
  /// =========================
  Future<Uint8List?> processFrame(CameraImage image) async {
    final now = DateTime.now();

    /// FPS throttling (VERY IMPORTANT)
    if (_lastProcessTime != null) {
      final diff = now.difference(_lastProcessTime!).inMilliseconds;

      if (diff < minFrameIntervalMs) {
        return null; // skip frame
      }
    }

    /// prevent parallel processing
    if (_isProcessing) return null;

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      final Uint8List bytes = _convertYUV420ToUint8List(image);
      return bytes;
    } catch (e) {
      print("Frame processing error: $e");
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// =========================
  /// YUV → BYTE ARRAY CONVERSION
  /// (required for ML models)
  /// =========================
  Uint8List _convertYUV420ToUint8List(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final Uint8List rgb = Uint8List(width * height * 3);

    int index = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;

        final int uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        final int Y = yPlane[yIndex];
        final int U = uPlane[uvIndex];
        final int V = vPlane[uvIndex];

        /// YUV → RGB conversion
        int r = (Y + (1.370705 * (V - 128))).round();
        int g = (Y - (0.337633 * (U - 128)) - (0.698001 * (V - 128))).round();
        int b = (Y + (1.732446 * (U - 128))).round();

        rgb[index++] = r.clamp(0, 255);
        rgb[index++] = g.clamp(0, 255);
        rgb[index++] = b.clamp(0, 255);
      }
    }

    return rgb;
  }
}
