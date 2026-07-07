import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../constants.dart';

/// Result returned after face detection.
class FaceDetectionResult {
  final img.Image croppedFace;
  final Rect boundingBox;

  FaceDetectionResult({required this.croppedFace, required this.boundingBox});
}

class FaceDetectorService {
  static final FaceDetectorService instance = FaceDetectorService._internal();

  late final FaceDetector _faceDetector;

  FaceDetectorService._internal() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableLandmarks: false,
        enableClassification: false,
        minFaceSize: 0.15,
      ),
    );
  }

  /// ===============================================================
  /// DETECT FROM A STILL PHOTO FILE (used by RegisterScreen)
  /// ===============================================================
  ///
  /// IMPORTANT: this is the ONLY reliable way to feed a JPEG captured
  /// via `CameraController.takePicture()` into ML Kit. Re-encoding the
  /// decoded `img.Image` bytes and calling `InputImage.fromBytes(...)`
  /// with `InputImageFormat.bgra8888` (as the previous implementation
  /// did) is broken on Android: the native ML Kit `fromByteArray` API
  /// only accepts `nv21` byte arrays on Android, and the bytes handed
  /// to it were RGBA (the `image` package's default `getBytes()`
  /// format) mislabeled as BGRA. That mismatch is what was causing
  /// face detection to fail on every single capture, which is why
  /// registration got stuck repeating "please try again" on the very
  /// first pose. Using `InputImage.fromFilePath` lets each platform's
  /// native SDK decode the JPEG itself, so there's no format/byte
  /// mismatch at all.
  ///
  /// [decodedImage] should be the same photo already decoded with the
  /// `image` package (register_screen already does this), so we can
  /// crop the detected face out of it without decoding twice.
  Future<FaceDetectionResult?> detectFromFile(
    String filePath,
    img.Image decodedImage,
  ) async {
    kDebugLog(
      'FaceDetectorService: detectFromFile "$filePath" (${decodedImage.width}x${decodedImage.height})',
    );

    final inputImage = InputImage.fromFilePath(filePath);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      kDebugLog('FaceDetectorService: no face detected');
      return null;
    }

    if (faces.length > 1) {
      kDebugLog('FaceDetectorService: multiple faces detected');
      return null;
    }

    final face = faces.first;
    final safeBox = _clampRect(
      face.boundingBox,
      decodedImage.width,
      decodedImage.height,
    );

    kDebugLog('FaceDetectorService: face box = $safeBox');

    final cropped = img.copyCrop(
      decodedImage,
      safeBox.left.toInt(),
      safeBox.top.toInt(),
      safeBox.width.toInt(),
      safeBox.height.toInt(),
    );

    if (!_isValidFace(cropped)) {
      kDebugLog('FaceDetectorService: face quality failed');
      return null;
    }

    return FaceDetectionResult(croppedFace: cropped, boundingBox: safeBox);
  }

  /// ===============================================================
  /// DETECT FROM A LIVE CAMERA FRAME (used by VerifyScreen)
  /// ===============================================================
  ///
  /// Builds the `InputImage` directly from the native `CameraImage`
  /// planes (nv21 on Android, bgra8888 on iOS) instead of round
  /// tripping through a manually-converted RGB `img.Image`, which had
  /// the same format-mismatch problem as the registration path.
  ///
  /// [rgbFrame] is the RGB conversion of the same frame (already
  /// produced by VerifyScreen for other purposes) — used only to crop
  /// out the final face image for the embedding model.
  Future<FaceDetectionResult?> detectFromCameraImage(
    CameraImage cameraImage,
    img.Image rgbFrame, {
    required InputImageRotation rotation,
  }) async {
    final inputImage = _buildInputImageFromCameraImage(cameraImage, rotation);

    if (inputImage == null) {
      kDebugLog(
        'FaceDetectorService: unsupported camera image format for detection '
        '(${cameraImage.format.group})',
      );
      return null;
    }

    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      kDebugLog('FaceDetectorService: no face detected');
      return null;
    }

    if (faces.length > 1) {
      kDebugLog('FaceDetectorService: multiple faces detected');
      return null;
    }

    final face = faces.first;
    final safeBox = _clampRect(
      face.boundingBox,
      rgbFrame.width,
      rgbFrame.height,
    );

    kDebugLog('FaceDetectorService: face box = $safeBox');

    final cropped = img.copyCrop(
      rgbFrame,
      safeBox.left.toInt(),
      safeBox.top.toInt(),
      safeBox.width.toInt(),
      safeBox.height.toInt(),
    );

    if (!_isValidFace(cropped)) {
      kDebugLog('FaceDetectorService: face quality failed');
      return null;
    }

    return FaceDetectionResult(croppedFace: cropped, boundingBox: safeBox);
  }

  /// ===============================================================
  /// BUILD A NATIVE InputImage FROM A CameraImage
  /// ===============================================================
  InputImage? _buildInputImageFromCameraImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    if (Platform.isAndroid) {
      // Android's `camera` plugin delivers YUV420 as 3 separate planes.
      // ML Kit's fromBytes on Android only accepts a single NV21 plane,
      // so we have to pack Y + interleaved V/U ourselves.
      if (image.format.group != ImageFormatGroup.yuv420 ||
          image.planes.length < 3) {
        return null;
      }

      final nv21 = _yuv420ToNv21(image);

      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    if (Platform.isIOS) {
      // iOS delivers a single bgra8888 plane already — safe to use as-is.
      if (image.format.group != ImageFormatGroup.bgra8888 ||
          image.planes.isEmpty) {
        return null;
      }

      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    return null;
  }

  /// Packs a 3-plane YUV420 CameraImage into a single NV21 byte array
  /// (Y plane followed by interleaved V,U samples).
  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final uvSize = (width * height) ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    int offset = 0;

    // Y plane — copy row by row in case bytesPerRow != width (padding).
    for (int row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    // Interleaved V,U (NV21 order) at half resolution.
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final uvIndex = row * uvRowStride + col * uvPixelStride;
        nv21[offset++] = vPlane.bytes[uvIndex];
        nv21[offset++] = uPlane.bytes[uvIndex];
      }
    }

    return nv21;
  }

  /// ===============================================================
  /// KEEP BOX INSIDE IMAGE
  /// ===============================================================
  Rect _clampRect(Rect rect, int width, int height) {
    double left = rect.left.clamp(0, width - 1);
    double top = rect.top.clamp(0, height - 1);

    double right = rect.right.clamp(left + 1, width.toDouble());

    double bottom = rect.bottom.clamp(top + 1, height.toDouble());

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// ===============================================================
  /// FACE QUALITY CHECK
  /// ===============================================================
  bool _isValidFace(img.Image face) {
    final brightness = _calculateBrightness(face);

    if (brightness < kMinBrightness || brightness > kMaxBrightness) {
      return false;
    }

    final ratio = face.width / face.height;

    if (ratio < 0.5 || ratio > 2.0) {
      return false;
    }

    return true;
  }

  /// ===============================================================
  /// BRIGHTNESS
  /// ===============================================================
  double _calculateBrightness(img.Image image) {
    double total = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        total +=
            (img.getRed(pixel) + img.getGreen(pixel) + img.getBlue(pixel)) / 3;
      }
    }

    return total / (image.width * image.height);
  }

  /// ===============================================================
  /// DISPOSE
  /// ===============================================================
  Future<void> dispose() async {
    await _faceDetector.close();
  }
}
