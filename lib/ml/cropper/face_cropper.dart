import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceCropper {
  FaceCropper._();

  /// =========================
  /// CROP FROM FILE (SAFE VERSION)
  /// =========================
  static Future<File?> cropFace(File imageFile, Face face) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      final rect = face.boundingBox;

      // 🔥 SAFE X/Y
      int x = rect.left.toInt().clamp(0, image.width - 1);
      int y = rect.top.toInt().clamp(0, image.height - 1);

      // raw width/height
      int w = rect.width.toInt();
      int h = rect.height.toInt();

      // 🔥 FIX overflow beyond image bounds
      if (x + w > image.width) {
        w = image.width - x;
      }
      if (y + h > image.height) {
        h = image.height - y;
      }

      // 🔥 prevent crash
      if (w <= 0 || h <= 0) return null;

      final cropped = img.copyCrop(image, x, y, w, h);

      final encoded = img.encodeJpg(cropped, quality: 95);

      // 🔥 DO NOT overwrite original image
      final dir = Directory.systemTemp;
      final file = File(
        '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await file.writeAsBytes(encoded);

      return file;
    } catch (e) {
      return null;
    }
  }

  /// =========================
  /// CROP FROM INPUT IMAGE (REAL-TIME)
  /// =========================
  static Future<Uint8List?> cropFaceFromInput(
    InputImage inputImage,
    Face face,
  ) async {
    try {
      final bytes = inputImage.bytes;
      if (bytes == null) return null;

      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final rect = face.boundingBox;

      int x = rect.left.toInt().clamp(0, image.width - 1);
      int y = rect.top.toInt().clamp(0, image.height - 1);

      int w = rect.width.toInt();
      int h = rect.height.toInt();

      if (x + w > image.width) {
        w = image.width - x;
      }
      if (y + h > image.height) {
        h = image.height - y;
      }

      if (w <= 0 || h <= 0) return null;

      final cropped = img.copyCrop(image, x, y, w, h);

      return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
    } catch (e) {
      return null;
    }
  }
}
