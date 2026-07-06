import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../embedding/embedings_utils.dart';

import '../recognition/recognizer.dart';
import '../../data/database/face_db.dart';
import '../../core/constants/app_constants.dart';
import '../../core/state/face_state.dart';
import '../../core/utils/distance.dart';

enum FaceMode { register, recognize }

class FaceEngine {
  FaceEngine._();
  static final FaceEngine instance = FaceEngine._();

  FaceMode mode = FaceMode.recognize;

  bool _isProcessing = false;

  /// temporary embeddings during registration
  final List<List<double>> _tempEmbeddings = [];

  String? currentUserName;

  /// =========================
  /// MAIN ENTRY (CALL THIS PER FRAME)
  /// =========================
  Future<String?> processFrame({
    required CameraImage cameraImage,
    required InputImage inputImage,
    required List<Face> faces,
    String? name,
  }) async {
    if (_isProcessing) return null;
    if (faces.isEmpty) return null;

    _isProcessing = true;

    try {
      final face = faces.first;

      final cropped = await _cropFaceFromInput(cameraImage, face);
      if (cropped == null) return null;

      // 2. Get embedding
      final rawEmbedding = await Recognizer.instance.getEmbedding(cropped);

      final embedding = EmbeddingUtils.normalize(rawEmbedding);

      // =========================
      // REGISTER MODE
      // =========================
      if (mode == FaceMode.register) {
        currentUserName = name;

        _tempEmbeddings.add(embedding);
        FaceState.updateRegistration(
          _tempEmbeddings.length,
          currentUserName ?? '',
        );

        // collect required samples
        if (_tempEmbeddings.length >= AppConstants.requiredEmbeddings &&
            currentUserName != null) {
          await FaceDB.insertFaceBatch(
            name: currentUserName!,
            imagePath: '',
            embeddings: _tempEmbeddings,
          );

          _tempEmbeddings.clear();

          return "REGISTERED";
        }

        return "COLLECTING (${_tempEmbeddings.length}/${AppConstants.requiredEmbeddings})";
      }
      // =========================
      // RECOGNITION MODE
      // =========================
      else {
        final allFaces = await FaceDB.getAllFaces();

        String? bestMatch;
        double bestScore = 0;

        for (final faceData in allFaces) {
          for (final dbEmbedding in faceData.embeddings) {
            final score = Distance.cosine(embedding, dbEmbedding);

            if (score > bestScore) {
              bestScore = score;
              bestMatch = faceData.name;
            }
          }
        }

        if (bestScore >= AppConstants.matchThreshold) {
          return "MATCH: $bestMatch ($bestScore)";
        } else {
          return "UNKNOWN";
        }
      }
    } catch (e) {
      return "ERROR: $e";
    } finally {
      _isProcessing = false;
    }
  }

  /// =========================
  /// SWITCH MODES
  /// =========================
  void setMode(FaceMode newMode) {
    mode = newMode;
    _tempEmbeddings.clear();
  }

  /// =========================
  /// RESET
  /// =========================
  void reset() {
    _tempEmbeddings.clear();
    currentUserName = null;
  }

  /// =========================
  /// REALTIME FACE CROPPING FROM CAMERA IMAGE
  /// =========================
  Future<Uint8List?> _cropFaceFromInput(CameraImage image, Face face) async {
    try {
      final width = image.width;
      final height = image.height;
      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;

      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      final img.Image convertedImage = img.Image(width, height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);

          final int Y = yPlane[y * width + x];
          final int U = uPlane[uvIndex];
          final int V = vPlane[uvIndex];

          int r = (Y + 1.370705 * (V - 128)).round();
          int g = (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128)).round();
          int b = (Y + 1.732446 * (U - 128)).round();

          convertedImage.setPixelRgba(
            x,
            y,
            r.clamp(0, 255),
            g.clamp(0, 255),
            b.clamp(0, 255),
          );
        }
      }

      final rect = face.boundingBox;
      int x = rect.left.toInt().clamp(0, convertedImage.width - 1);
      int y = rect.top.toInt().clamp(0, convertedImage.height - 1);
      int w = rect.width.toInt();
      int h = rect.height.toInt();

      if (x + w > convertedImage.width) {
        w = convertedImage.width - x;
      }
      if (y + h > convertedImage.height) {
        h = convertedImage.height - y;
      }

      if (w <= 0 || h <= 0) return null;

      final cropped = img.copyCrop(convertedImage, x, y, w, h);
      return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
    } catch (_) {
      return null;
    }
  }
}
