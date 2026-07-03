import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionService {
  FaceDetectionService._();
  static final FaceDetectionService instance = FaceDetectionService._();

  late final FaceDetector _detector;

  bool _isInitialized = false;

  /// =========================
  /// INIT DETECTOR
  /// =========================
  void init() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast, // real-time friendly
        enableLandmarks: true,
        enableClassification: true, // for blink detection later
        enableTracking: true,
      ),
    );

    _isInitialized = true;
  }

  /// =========================
  /// PROCESS FRAME
  /// =========================
  Future<List<Face>> detectFaces(InputImage inputImage) async {
    if (!_isInitialized) {
      throw Exception("FaceDetector not initialized");
    }

    final faces = await _detector.processImage(inputImage);

    return faces;
  }

  /// =========================
  /// SINGLE FACE CHECK
  /// =========================
  Future<Face?> getMainFace(InputImage inputImage) async {
    final faces = await detectFaces(inputImage);

    if (faces.isEmpty) return null;

    /// return biggest face (best for recognition accuracy)
    faces.sort((a, b) {
      final aSize = a.boundingBox.width * a.boundingBox.height;
      final bSize = b.boundingBox.width * b.boundingBox.height;

      return bSize.compareTo(aSize);
    });

    return faces.first;
  }

  /// =========================
  /// DISPOSE
  /// =========================
  void dispose() {
    _detector.close();
  }
}
