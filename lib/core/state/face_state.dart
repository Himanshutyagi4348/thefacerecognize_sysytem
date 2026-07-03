import '../enums/face_mode.dart';

class FaceState {
  FaceState._();

  /// =========================
  /// SYSTEM MODE
  /// =========================
  static FaceMode mode = FaceMode.recognize;

  /// =========================
  /// REGISTRATION STATE
  /// =========================
  static String currentUser = "";
  static int collectedEmbeddings = 0;
  static int requiredEmbeddings = 5;

  /// =========================
  /// LIVE STATUS
  /// =========================
  static String status = "Idle";

  /// =========================
  /// FACE FLAGS
  /// =========================
  static bool faceDetected = false;
  static bool isBlinkDetected = false;
  static bool isLive = false;

  /// =========================
  /// RECOGNITION RESULT
  /// =========================
  static String recognizedName = "Unknown";
  static double confidence = 0.0;

  /// =========================
  /// RESET STATE
  /// =========================
  static void reset() {
    currentUser = "";
    collectedEmbeddings = 0;
    status = "Idle";
    faceDetected = false;
    isBlinkDetected = false;
    isLive = false;
    recognizedName = "Unknown";
    confidence = 0.0;
  }

  /// =========================
  /// UPDATE STATUS
  /// =========================
  static void updateStatus(String newStatus) {
    status = newStatus;
  }

  /// =========================
  /// UPDATE RECOGNITION RESULT
  /// =========================
  static void updateRecognition(String name, double score) {
    recognizedName = name;
    confidence = score;
  }

  /// =========================
  /// UPDATE REGISTRATION PROGRESS
  /// =========================
  static void updateRegistration(int count, String user) {
    collectedEmbeddings = count;
    currentUser = user;
  }
}
