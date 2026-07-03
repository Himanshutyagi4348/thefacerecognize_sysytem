import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  TTSService._();

  static final TTSService instance = TTSService._();

  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// =========================
  /// INIT TTS
  /// =========================
  Future<void> init() async {
    if (_isInitialized) return;

    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  /// =========================
  /// SPEAK TEXT
  /// =========================
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();

    if (_isSpeaking) {
      await stop();
    }

    await _tts.speak(text);
  }

  /// =========================
  /// QUEUE SAFE SPEAK (no overlap)
  /// =========================
  Future<void> speakSafe(String text) async {
    if (!_isInitialized) await init();

    if (_isSpeaking) return;

    await _tts.speak(text);
  }

  /// =========================
  /// STOP SPEECH
  /// =========================
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// =========================
  /// GUIDED FACE INSTRUCTIONS
  /// =========================
  Future<void> guideFacePosition(String position) async {
    switch (position.toLowerCase()) {
      case "left":
        await speak("Please move your face to the left");
        break;
      case "right":
        await speak("Please move your face to the right");
        break;
      case "top":
        await speak("Please move your face slightly up");
        break;
      case "bottom":
        await speak("Please move your face slightly down");
        break;
      case "front":
        await speak("Please look straight at the camera");
        break;
      case "blink":
        await speak("Please blink your eyes now");
        break;
      default:
        await speak(position);
    }
  }

  /// =========================
  /// STATUS ANNOUNCEMENT
  /// =========================
  Future<void> announceStatus(String status) async {
    await speakSafe(status);
  }
}
