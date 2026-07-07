import 'dart:math';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

import '../constants.dart';
import 'package:flutter/foundation.dart';

class EmbeddingService {
  static final EmbeddingService instance = EmbeddingService._internal();
  Interpreter? _interpreter;

  EmbeddingService._internal();

  /// ===============================================================
  /// LOAD MODEL
  /// ===============================================================
Future<void> loadModel() async {
    if (_interpreter != null) {
      debugPrint("MODEL ALREADY LOADED");
      return;
    }

    debugPrint("Loading model...");
    debugPrint("Path = $kFaceModelPath");

    _interpreter = await Interpreter.fromAsset(kFaceModelPath);

    debugPrint("MODEL LOADED SUCCESSFULLY");
    debugPrint(_interpreter.toString());
  }

  /// ===============================================================
  /// GET EMBEDDING FROM IMAGE
  /// ===============================================================
  Future<List<double>> getEmbedding(img.Image image) async {
    kDebugLog('🚀🧠 EmbeddingService: getEmbedding() started');
    await loadModel();

    if (_interpreter == null) {
      throw Exception("Face model is not loaded — cannot generate embedding.");
    }

    final input = _preprocess(image);

    // Output buffer (1 x 192)
    final output = List.generate(1, (_) => List.filled(kEmbeddingSize, 0.0));

    _interpreter!.run(input, output);

    final embedding = List<double>.from(output[0]);

    /// Safety check
    if (embedding.length != kEmbeddingSize) {
      throw Exception("Invalid embedding size: ${embedding.length}");
    }

    final normalized = _normalize(embedding);
    kDebugLog(
      '✅🧠 EmbeddingService: generated normalized embedding (${normalized.length} dims)',
    );
    return normalized;
  }

  /// ===============================================================
  /// FRAME AVERAGING (STABILITY IMPROVEMENT)
  /// ===============================================================
  Future<List<double>> getAveragedEmbedding(List<img.Image> frames) async {
    final embeddings = <List<double>>[];

    for (final frame in frames) {
      final emb = await getEmbedding(frame);
      embeddings.add(emb);
    }

    final avg = List<double>.filled(kEmbeddingSize, 0.0);

    for (final emb in embeddings) {
      for (int i = 0; i < kEmbeddingSize; i++) {
        avg[i] += emb[i];
      }
    }

    for (int i = 0; i < kEmbeddingSize; i++) {
      avg[i] /= embeddings.length;
    }

    return _normalize(avg);
  }

  /// ===============================================================
  /// PREPROCESS IMAGE FOR TFLITE
  /// ===============================================================
  List<List<List<List<double>>>> _preprocess(img.Image image) {
    final resized = img.copyResize(image, width: 112, height: 112);

    // Normalize to [-1, 1]
    final input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(112, (x) {
          final pixel = resized.getPixel(x, y);

          final r = (img.getRed(pixel) / 127.5) - 1.0;
          final g = (img.getGreen(pixel) / 127.5) - 1.0;
          final b = (img.getBlue(pixel) / 127.5) - 1.0;

          return [r, g, b];
        }),
      ),
    );

    return input;
  }

  /// ===============================================================
  /// L2 NORMALIZATION (IMPORTANT FOR COSINE SIMILARITY)
  /// ===============================================================
  List<double> _normalize(List<double> vector) {
    double sum = 0.0;

    for (final v in vector) {
      sum += v * v;
    }

    final norm = sqrt(sum);

    if (norm == 0) return vector;

    return vector.map((e) => e / norm).toList();
  }

  /// ===============================================================
  /// DISPOSE
  /// ===============================================================
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
