import 'dart:math';

class Distance {
  /// =========================
  /// COSINE SIMILARITY
  /// (MAIN METRIC FOR FACE RECOGNITION)
  /// =========================
  static double cosine(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;

    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// =========================
  /// EUCLIDEAN DISTANCE (optional fallback)
  /// =========================
  static double euclidean(List<double> a, List<double> b) {
    if (a.length != b.length) return double.infinity;

    double sum = 0.0;

    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }

    return sqrt(sum);
  }

  /// =========================
  /// SIMILARITY SCORE NORMALIZATION
  /// Converts cosine (-1 to 1) → (0 to 1)
  /// =========================
  static double normalizeSimilarity(double cosineScore) {
    return (cosineScore + 1) / 2;
  }

  /// =========================
  /// DISTANCE TO CONFIDENCE SCORE
  /// (USED FOR UI DISPLAY)
  /// =========================
  static double confidence(double cosineScore) {
    final normalized = normalizeSimilarity(cosineScore);

    // clamp between 0 and 1
    return normalized.clamp(0.0, 1.0);
  }

  /// =========================
  /// BEST MATCH CHECK
  /// =========================
  static bool isMatch(double score, {double threshold = 0.85}) {
    return score >= threshold;
  }
}
