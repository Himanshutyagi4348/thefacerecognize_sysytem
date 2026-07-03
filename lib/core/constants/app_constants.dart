class AppConstants {
  AppConstants._();

  // =========================
  // MODEL CONFIG
  // =========================
  static const String modelPath = "assets/mobilefacenet.tflite";
  static const int embeddingSize = 128;
  static const int inputSize = 112;

  // =========================
  // FACE DETECTION
  // =========================
  static const double minFaceWidthRatio = 0.25;
  static const double maxHeadAngle = 15.0;

  // =========================
  // RECOGNITION THRESHOLDS
  // =========================
  static const double matchThreshold = 0.35; // lower = stricter matching
  static const double unknownThreshold = 0.45;

  // =========================
  // REGISTRATION SETTINGS
  // =========================
  static const int requiredEmbeddings = 5;

  // =========================
  // BLINK / LIVENESS
  // =========================
  static const double eyeClosedThreshold = 0.4;
  static const int requiredBlinks = 1;

  // =========================
  // CAMERA SETTINGS
  // =========================
  static const int minFrameIntervalMs = 80; // ~12 FPS processing
  static const int cameraWidth = 640;
  static const int cameraHeight = 480;

  // =========================
  // DB CONFIG
  // =========================
  static const String dbName = "faces.db";
  static const String userTable = "users";
  static const String embeddingTable = "embeddings";
}
