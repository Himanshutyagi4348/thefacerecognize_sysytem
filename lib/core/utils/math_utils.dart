import 'dart:math';

class MathUtils {
  MathUtils._();

  /// =========================
  /// VECTOR NORMALIZATION
  /// =========================
  static List<double> normalize(List<double> vector) {
    double sum = 0.0;

    for (final v in vector) {
      sum += v * v;
    }

    final magnitude = sqrt(sum);

    if (magnitude == 0) return vector;

    return vector.map((e) => e / magnitude).toList();
  }

  /// =========================
  /// DOT PRODUCT
  /// =========================
  static double dot(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw Exception("Vector size mismatch");
    }

    double result = 0.0;

    for (int i = 0; i < a.length; i++) {
      result += a[i] * b[i];
    }

    return result;
  }

  /// =========================
  /// MEAN OF VECTOR
  /// =========================
  static double mean(List<double> values) {
    if (values.isEmpty) return 0.0;

    double sum = 0.0;

    for (final v in values) {
      sum += v;
    }

    return sum / values.length;
  }

  /// =========================
  /// CLAMP VALUE
  /// =========================
  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// =========================
  /// EUCLIDEAN DISTANCE
  /// =========================
  static double euclidean(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw Exception("Vector size mismatch");
    }

    double sum = 0.0;

    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }

    return sqrt(sum);
  }

  /// =========================
  /// COSINE SIMILARITY
  /// =========================
  static double cosineSimilarity(List<double> a, List<double> b) {
    final dotProduct = dot(a, b);
    final normA = sqrt(dot(a, a));
    final normB = sqrt(dot(b, b));

    if (normA == 0 || normB == 0) return 0.0;

    return dotProduct / (normA * normB);
  }

  /// =========================
  /// COSINE DISTANCE
  /// =========================
  static double cosineDistance(List<double> a, List<double> b) {
    return 1 - cosineSimilarity(a, b);
  }

  /// =========================
  /// AVERAGE OF MULTIPLE VECTORS
  /// (VERY IMPORTANT FOR ACCURACY)
  /// =========================
  static List<double> averageVectors(List<List<double>> vectors) {
    if (vectors.isEmpty) return [];

    final length = vectors.first.length;
    List<double> avg = List.filled(length, 0.0);

    for (final vec in vectors) {
      for (int i = 0; i < length; i++) {
        avg[i] += vec[i];
      }
    }

    for (int i = 0; i < length; i++) {
      avg[i] /= vectors.length;
    }

    return avg;
  }
}
