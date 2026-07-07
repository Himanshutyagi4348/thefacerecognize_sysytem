import '../constants.dart';

class PoseUtils {
  /// ===============================================================
  /// CHECK IF POSE IS VALID
  /// ===============================================================
  static bool isValidPose(String pose) {
    return kRequiredPoses.contains(pose.toLowerCase());
  }

  /// ===============================================================
  /// NORMALIZE POSE STRING
  /// (prevents "Front", "FRONT", " front ")
  /// ===============================================================
  static String normalize(String pose) {
    return pose.trim().toLowerCase();
  }

  /// ===============================================================
  /// GET NEXT POSE INDEX
  /// ===============================================================
  static int nextPoseIndex(int currentIndex) {
    if (currentIndex < 0) return 0;
    if (currentIndex >= kRequiredPoses.length - 1) {
      return kRequiredPoses.length - 1;
    }
    return currentIndex + 1;
  }

  /// ===============================================================
  /// GET PREVIOUS POSE INDEX
  /// ===============================================================
  static int previousPoseIndex(int currentIndex) {
    if (currentIndex <= 0) return 0;
    return currentIndex - 1;
  }

  /// ===============================================================
  /// GET POSE BY INDEX
  /// ===============================================================
  static String getPose(int index) {
    if (index < 0 || index >= kRequiredPoses.length) {
      return kRequiredPoses.first;
    }
    return kRequiredPoses[index];
  }

  /// ===============================================================
  /// GET INDEX BY POSE
  /// ===============================================================
  static int getIndex(String pose) {
    final normalized = normalize(pose);
    return kRequiredPoses.indexOf(normalized);
  }

  /// ===============================================================
  /// CHECK IF ALL POSES COMPLETED
  /// ===============================================================
  static bool isRegistrationComplete(int currentIndex) {
    return currentIndex >= kRequiredPoses.length;
  }

  /// ===============================================================
  /// GET PROGRESS PERCENTAGE (0–1)
  /// ===============================================================
  static double getProgress(int currentIndex) {
    return (currentIndex / kRequiredPoses.length).clamp(0.0, 1.0);
  }

  /// ===============================================================
  /// SAFE POSE MATCH (STRICT CHECK)
  /// ===============================================================
  static bool matchesRequiredPose(String inputPose, String requiredPose) {
    return normalize(inputPose) == normalize(requiredPose);
  }
}
