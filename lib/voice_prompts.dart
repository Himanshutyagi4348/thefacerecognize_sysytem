

class VoicePrompts {
  VoicePrompts._();

  // ------------------------------------------------------------
  // General
  // ------------------------------------------------------------

  static const String initializing = "Initializing camera.";

  static const String ready = "System ready.";

  static const String processing = "Processing.";

  static const String capturing = "Capturing.";

  static const String holdStill = "Hold still.";

  static const String pleaseWait = "Please wait.";

  // ------------------------------------------------------------
  // Face Detection
  // ------------------------------------------------------------

  static const String noFace = "No face detected.";

  static const String multipleFaces =
      "Multiple faces detected. Only one person should be visible.";

  static const String centerFace = "Center your face inside the frame.";

  static const String moveCloser = "Move closer.";

  static const String moveFarther = "Move farther.";

  static const String faceTooSmall = "Face is too far away.";

  static const String faceTooLarge = "Face is too close.";

  static const String faceDetected = "Face detected.";

  // ------------------------------------------------------------
  // Registration
  // ------------------------------------------------------------

  static const String registrationStarted = "Registration started.";

  static const String registrationComplete =
      "Registration completed successfully.";

  static const String registrationFailed =
      "Registration failed. Please try again.";

  static const String captureFront = "Look straight.";

  static const String captureLeft = "Turn your head left.";

  static const String captureRight = "Turn your head right.";

  static const String captureUp = "Look up.";

  static const String captureDown = "Look down.";

  static const String poseAccepted = "Pose captured.";

  static const String nextPose = "Proceed to the next pose.";

  // ------------------------------------------------------------
  // Verification
  // ------------------------------------------------------------

  static const String verificationStarted = "Verification started.";

  static const String verificationSuccess = "Verification successful.";

  static const String verificationFailed =
      "Face not recognized. Please try again.";

  static const String blinkNow = "Please blink.";

  static const String blinkDetected = "Blink detected.";

  static String welcome(String userName) {
    return "Welcome, $userName.";
  }

  // ------------------------------------------------------------
  // Image Quality
  // ------------------------------------------------------------

  static const String lightingTooDark =
      "Lighting is too dark. Please move to a brighter place.";

  static const String lightingTooBright =
      "Lighting is too bright. Please reduce the light.";

  static const String imageBlurry = "Image is blurry. Hold still.";

  static const String imageQualityGood = "Image quality is good.";

  // ------------------------------------------------------------
  // Guidance
  // ------------------------------------------------------------

  static const String alignFace = "Align your face with the guide.";

  static const String keepEyesOpen = "Keep your eyes open.";

  static const String lookStraight = "Look straight at the camera.";

  static const String stayStill = "Stay still.";

  static const String keepFaceVisible = "Keep your full face visible.";

  // ------------------------------------------------------------
  // Errors
  // ------------------------------------------------------------

  static const String cameraError = "Unable to access the camera.";

  static const String databaseError = "Database error occurred.";

  static const String modelError = "Face recognition model failed to load.";

  static const String unknownError = "Something went wrong.";

  // ------------------------------------------------------------
  // Retry
  // ------------------------------------------------------------

  static const String retry = "Please try again.";

  static const String resetting = "Resetting.";

  // ------------------------------------------------------------
  // Debug (Optional)
  // ------------------------------------------------------------

  static String confidence(double value) {
    return "Confidence ${(value * 100).toStringAsFixed(1)} percent.";
  }

  static String poseCaptured(String pose) {
    return "$pose pose captured.";
  }

  static String poseRequired(String pose) {
    return "Please look $pose.";
  }
}
