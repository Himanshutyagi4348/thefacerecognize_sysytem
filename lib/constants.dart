import 'package:flutter/foundation.dart';

const int kDatabaseVersion = 1;

const String kDatabaseName = "face_recognition.db";

const String kUsersTable = "users";

const String kEmbeddingsTable = "embeddings";

const String kVerificationLogsTable = "verification_logs";

/// SQLite column names
const String kIdColumn = "id";
const String kUserIdColumn = "user_id";
const String kUserNameColumn = "user_name";
const String kPoseColumn = "pose";
const String kEmbeddingColumn = "embedding";
const String kCreatedAtColumn = "created_at";
const String kConfidenceColumn = "confidence_score";
const String kMatchedColumn = "matched";
const String kTimestampColumn = "timestamp";
const String kAggregationStrategyColumn = "aggregation_strategy";
const List<String> kRequiredPoses = ['front', 'left', 'right', 'up', 'down'];

enum AggregationStrategy { average, maxSimilarity }

/// Debug flags
const bool kEnableDebugLogs = true;

/// Shared debug logging helper used across the app.
void kDebugLog(String message) {
  if (!kEnableDebugLogs) return;
  final timestamp = DateTime.now().toIso8601String();
  debugPrint('[FaceRec][$timestamp] $message');
}

/// Minimum cooldown between TTS utterances when debug logging is enabled.
const Duration kVoiceCooldown = Duration(seconds: 2);

/// Model / embedding configuration
const String kFaceModelPath = 'assets/mobilefacenet.tflite';
const int kEmbeddingSize = 192;

/// Face quality thresholds
const double kMinBrightness = 10.0;
const double kMaxBrightness = 245.0;
const double kBlurThreshold = 100.0;
const double kMinFaceRatio = 0.02;
const double kMaxFaceRatio = 1.0;

/// Similarity / pose weighting
const Map<String, double> kPoseWeights = {
  'front': 1.0,
  'left': 0.9,
  'right': 0.9,
  'up': 0.85,
  'down': 0.85,
};

const double kMatchThreshold = 0.8;
