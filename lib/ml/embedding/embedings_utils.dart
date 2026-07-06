// embedings_utils.dart
// (You already have this file — move your existing content here.)
import 'dart:math' as math;

class EmbeddingUtils {
  EmbeddingUtils._();

  /// =========================
  /// NORMALIZE VECTOR (L2 NORMALIZATION)
  /// =========================
  static List<double> normalize(List<double> vector) {
    double sum = 0.0;

    for (final v in vector) {
      sum += v * v;
    }

    final norm = sum == 0 ? 1.0 : sum;

    return vector.map((e) => e / norm).toList();
  }

  /// =========================
  /// SAFE NORMALIZATION (BETTER STABILITY)
  /// =========================
  static List<double> safeNormalize(List<double> vector) {
    double sum = 0.0;

    for (final v in vector) {
      sum += v * v;
    }

    final magnitude = sum.sqrt();

    if (magnitude == 0 || magnitude.isNaN) {
      return List.filled(vector.length, 0.0);
    }

    return vector.map((e) => e / magnitude).toList();
  }

  /// =========================
  /// CLIP VALUES (REMOVE NOISE OUTLIERS)
  /// =========================
  static List<double> clip(List<double> vector, double min, double max) {
    return vector.map((e) {
      if (e < min) return min;
      if (e > max) return max;
      return e;
    }).toList();
  }

  /// =========================
  /// COMPUTE VECTOR MAGNITUDE
  /// =========================
  static double magnitude(List<double> vector) {
    double sum = 0.0;

    for (final v in vector) {
      sum += v * v;
    }

    return sum.sqrt();
  }

  /// =========================
  /// CENTER VECTOR (MEAN NORMALIZATION)
  /// =========================
  static List<double> center(List<double> vector) {
    final mean = vector.reduce((a, b) => a + b) / vector.length;

    return vector.map((e) => e - mean).toList();
  }

  /// =========================
  /// L2 DISTANCE NORMALIZATION CHECK
  /// =========================
  static bool isValidEmbedding(List<double> vector) {
    final mag = magnitude(vector);

    return mag > 0.1 && mag < 10.0;
  }
}

extension _Sqrt on double {
  double sqrt() => math.sqrt(this);
}
