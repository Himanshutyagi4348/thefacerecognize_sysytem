import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../constants.dart';

class TTSService {
  static final TTSService instance = TTSService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  DateTime? _lastSpokenTime;

  TTSService._internal();

  /// ===============================================================
  /// INIT TTS
  /// ===============================================================
  Future<void> init() async {
    if (_isInitialized) return;

    kDebugLog('TTSService: Initializing text-to-speech engine');
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _isInitialized = true;
    kDebugLog('TTSService: Initialization complete');
  }

  /// ===============================================================
  /// SPEAK (SAFE WITH COOLDOWN)
  /// ===============================================================
  Future<void> speak(String text) async {
    await init();

    kDebugLog('TTSService: speak() called with text="$text"');

    if (_shouldSkip()) return;

    _lastSpokenTime = DateTime.now();

    await _tts.stop();
    await _tts.speak(text);
  }

  /// ===============================================================
  /// STOP SPEECH
  /// ===============================================================
  Future<void> stop() async {
    await _tts.stop();
  }

  /// ===============================================================
  /// VERIFICATION SPEECH HELPERS
  /// ===============================================================

  Future<void> speakWelcome(String name) async {
    await speak("Welcome $name. Access granted.");
  }

  Future<void> speakUnknown() async {
    await speak("Face not recognized. Please try again.");
  }

  Future<void> speakAccessDenied() async {
    await speak("Access denied. Face not recognized.");
  }

  Future<void> speakRegisterStart() async {
    await speak("Starting registration. Please follow face directions.");
  }

  Future<void> speakPoseInstruction(String pose) async {
    switch (pose) {
      case "front":
        await speak("Look straight at the camera.");
        break;
      case "left":
        await speak("Turn your face to the left.");
        break;
      case "right":
        await speak("Turn your face to the right.");
        break;
      case "up":
        await speak("Look slightly upward.");
        break;
      case "down":
        await speak("Look slightly downward.");
        break;
      default:
        await speak("Please adjust your face position.");
    }
  }

  Future<void> speakError() async {
    await speak("Something went wrong. Please try again.");
  }

  /// ===============================================================
  /// COOLDOWN LOGIC
  /// ===============================================================
  bool _shouldSkip() {
    if (_lastSpokenTime == null) return false;

    final diff = DateTime.now().difference(_lastSpokenTime!);
    final skip = diff < kVoiceCooldown;
    kDebugLog('TTSService: _shouldSkip=$skip (diff=${diff.inMilliseconds}ms)');

    return skip;
  }

  /// ===============================================================
  /// DISPOSE
  /// ===============================================================
  Future<void> dispose() async {
    await _tts.stop();
  }
}
