import 'dart:math';

import '../constants.dart';
import '../models/embedding_model.dart';

class SimilarityUtils {
  /// ===============================================================
  /// COSINE SIMILARITY
  /// ===============================================================
  static double cosineSimilarity(List<double> a, List<double> b) {
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

  /// ===============================================================
  /// SINGLE POSE SCORE
  /// ===============================================================
  static double compareSinglePose(
    List<double> inputEmbedding,
    EmbeddingModel storedEmbedding,
  ) {
    return cosineSimilarity(inputEmbedding, storedEmbedding.embedding);
  }

  /// ===============================================================
  /// MULTI-POSE MATCH (CORE LOGIC)
  /// ===============================================================
  static double compareMultiPose(
    List<double> inputEmbedding,
    List<EmbeddingModel> storedEmbeddings,
  ) {
    double totalScore = 0.0;
    double totalWeight = 0.0;

    for (final stored in storedEmbeddings) {
      final pose = stored.pose;
      final weight = kPoseWeights[pose] ?? 1.0;

      final score = cosineSimilarity(inputEmbedding, stored.embedding);

      totalScore += score * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return 0.0;

    return totalScore / totalWeight;
  }

  /// ===============================================================
  /// BEST MATCH SCORE (FOR VERIFICATION)
  /// ===============================================================
  static double getBestMatchScore(
    List<double> inputEmbedding,
    List<EmbeddingModel> storedEmbeddings,
  ) {
    kDebugLog(
      'SimilarityUtils: getBestMatchScore for ${storedEmbeddings.length} stored embeddings',
    );
    double bestScore = 0.0;

    for (final stored in storedEmbeddings) {
      final score = cosineSimilarity(inputEmbedding, stored.embedding);

      if (score > bestScore) {
        bestScore = score;
      }
    }

    return bestScore;
  }

  /// ===============================================================
  /// FINAL VERIFICATION RESULT
  /// ===============================================================
  static bool isMatch(double score) {
    final matched = score >= kMatchThreshold;
    kDebugLog(
      'SimilarityUtils: isMatch score=$score threshold=$kMatchThreshold matched=$matched',
    );
    return matched;
  }

  /// ===============================================================
  /// CONFIDENCE NORMALIZATION (0–100%)
  /// ===============================================================
  static double normalizeConfidence(double score) {
    // cosine similarity is -1 to 1 → convert to 0–1
    final normalized = (score + 1) / 2;
    return (normalized * 100).clamp(0, 100);
  }
}
