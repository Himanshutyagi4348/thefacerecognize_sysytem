import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../embedings_utils.dart';
import '../recognition/recognizer.dart';
import '../../data/database/face_db.dart';
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
    required InputImage inputImage,
    required List<Face> faces,
    String? name,
  }) async {
    if (_isProcessing) return null;
    if (faces.isEmpty) return null;

    _isProcessing = true;

    try {
      final face = faces.first;

      // 1. Crop face (you already have cropper, integrate later if needed)
      final cropped = await _cropFaceFromInput(inputImage, face);
      if (cropped == null) return null;

      // 2. Get embedding
      final rawEmbedding =
          await Recognizer.instance.getEmbedding(cropped);

      final embedding = EmbeddingUtils.normalize(rawEmbedding);

      // =========================
      // REGISTER MODE
      // =========================
      if (mode == FaceMode.register) {
        currentUserName = name;

        _tempEmbeddings.add(embedding);

        // collect 5 samples
        if (_tempEmbeddings.length >= 5 && currentUserName != null) {
          await FaceDB.insertFaceBatch(
            name: currentUserName!,
            embeddings: _tempEmbeddings,
          );

          _tempEmbeddings.clear();

          return "REGISTERED";
        }

        return "COLLECTING (${_tempEmbeddings.length}/5)";
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

        if (bestScore > 0.85) {
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
  /// FAKE CROPPING WRAPPER
  /// (we will replace with your FaceCropper next file)
  /// =========================
  Future<Uint8List?> _cropFaceFromInput(
    InputImage image,
    Face face,
  ) async {
    // TEMP: you will connect your FaceCropper here
    return image.bytes;
  }
}