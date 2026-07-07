import 'dart:math';
import 'dart:ui';
import 'package:image/image.dart' as img;

import '../constants.dart';

class ImageQuality {
  /// ===============================================================
  /// CHECK FULL IMAGE QUALITY
  /// ===============================================================
  ///
  /// [fullFrame] is the entire camera frame, and [faceBox] is the
  /// detected face's bounding box within that frame (e.g. from
  /// `FaceDetectionResult.boundingBox`). Passing both lets us check
  /// how much of the frame the face actually occupies — a single
  /// image on its own has no "face ratio" to measure.
  static bool isValidFaceImage(img.Image fullFrame, Rect faceBox) {
    final brightness = _calculateBrightness(fullFrame);
    final blurScore = _calculateBlurScore(fullFrame);
    final faceRatio = _calculateFaceRatio(fullFrame, faceBox);

    if (brightness < kMinBrightness || brightness > kMaxBrightness) {
      return false;
    }

    if (blurScore < kBlurThreshold) {
      return false;
    }

    if (faceRatio < kMinFaceRatio || faceRatio > kMaxFaceRatio) {
      return false;
    }

    return true;
  }

  /// ===============================================================
  /// BRIGHTNESS (0–255)
  /// ===============================================================
  static double _calculateBrightness(img.Image image) {
    double total = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        final r = img.getRed(pixel).toDouble();
        final g = img.getGreen(pixel).toDouble();
        final b = img.getBlue(pixel).toDouble();

        total += (r + g + b) / 3;
      }
    }

    return total / (image.width * image.height);
  }

  /// ===============================================================
  /// BLUR SCORE (LAPLACIAN APPROX)
  /// Higher = sharper image
  /// ===============================================================
  static double _calculateBlurScore(img.Image image) {
    double variance = 0;
    double mean = 0;
    int count = 0;

    List<double> values = [];

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = img.getRed(image.getPixel(x, y)).toDouble();

        final left = img.getRed(image.getPixel(x - 1, y)).toDouble();
        final right = img.getRed(image.getPixel(x + 1, y)).toDouble();
        final up = img.getRed(image.getPixel(x, y - 1)).toDouble();
        final down = img.getRed(image.getPixel(x, y + 1)).toDouble();

        final laplacian = (4 * center) - (left + right + up + down);

        values.add(laplacian);
        mean += laplacian;
        count++;
      }
    }

    mean /= count;

    for (final v in values) {
      variance += pow(v - mean, 2);
    }

    return variance / count;
  }

  /// ===============================================================
  /// FACE SIZE RATIO CHECK
  /// ===============================================================
  ///
  /// Ratio of the detected face box's area to the full frame's area.
  /// (Previously this compared an image to itself and always
  /// returned 1.0 — now it actually measures how much of the frame
  /// the face occupies, using the real bounding box.)
  static double _calculateFaceRatio(img.Image fullFrame, Rect faceBox) {
    final totalPixels = fullFrame.width * fullFrame.height;
    if (totalPixels == 0) return 0.0;

    final facePixels = faceBox.width * faceBox.height;

    return (facePixels / totalPixels).clamp(0.0, 1.0);
  }

  /// ===============================================================
  /// QUICK SCORE (0–1)
  /// ===============================================================
  static double qualityScore(img.Image image) {
    double score = 1.0;

    final brightness = _calculateBrightness(image);
    final blur = _calculateBlurScore(image);

    if (brightness < kMinBrightness || brightness > kMaxBrightness) {
      score -= 0.3;
    }

    if (blur < kBlurThreshold) {
      score -= 0.5;
    }

    return score.clamp(0.0, 1.0);
  }
}
