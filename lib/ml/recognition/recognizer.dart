import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class Recognizer {
  Recognizer._();
  static final Recognizer instance = Recognizer._();

  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  /// =========================
  /// LOAD TFLITE MODEL
  /// =========================
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');

      _isModelLoaded = true;
      debugPrint("✅ Face model loaded successfully");
    } catch (e) {
      debugPrint("❌ Model load error: $e");
    }
  }

  /// =========================
  /// GET EMBEDDING FROM IMAGE
  /// INPUT: Cropped face image
  /// OUTPUT: 128-D embedding vector
  /// =========================
  Future<List<double>> getEmbedding(Uint8List imageBytes) async {
    if (!_isModelLoaded || _interpreter == null) {
      throw Exception("Model not loaded");
    }

    // 1. Decode image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception("Invalid image");
    }

    // 2. Resize to model input (usually 112x112)
    image = img.copyResize(image, width: 112, height: 112);

    // 3. Convert to input tensor
    var input = _imageToByteListFloat32(image);

    // 4. Output buffer (128-d embedding)
    var output = List.filled(1 * 128, 0.0).reshape([1, 128]);

    // 5. Run inference
    _interpreter!.run(input, output);

    // 6. Flatten result
    List<double> embedding = List<double>.from(
      output[0].map((e) => e.toDouble()),
    );

    return embedding;
  }

  /// =========================
  /// IMAGE → TENSOR
  /// =========================
  List<List<List<List<double>>>> _imageToByteListFloat32(img.Image image) {
    final input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(112, (x) {
          final pixel = image.getPixel(x, y);

          return [
            (img.getRed(pixel) - 127.5) / 128.0,
            (img.getGreen(pixel) - 127.5) / 128.0,
            (img.getBlue(pixel) - 127.5) / 128.0,
          ];
        }),
      ),
    );

    return input;
  }

  /// =========================
  /// OPTIONAL: EMBEDDING NORMALIZATION
  /// =========================
  List<double> normalize(List<double> vector) {
    double sum = 0;

    for (var v in vector) {
      sum += v * v;
    }

    double norm = sqrt(sum);

    return vector.map((e) => e / norm).toList();
  }
}
