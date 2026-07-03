import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// =========================
  /// REQUEST ALL REQUIRED PERMISSIONS
  /// =========================
  Future<bool> requestAll() async {
    final camera = await Permission.camera.request();
    final storage = await Permission.storage.request();
    final mic = await Permission.microphone.request();

    return camera.isGranted && storage.isGranted && mic.isGranted;
  }

  /// =========================
  /// CHECK CAMERA PERMISSION
  /// =========================
  Future<bool> cameraGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// =========================
  /// REQUEST CAMERA ONLY
  /// =========================
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// =========================
  /// REQUEST STORAGE ONLY
  /// =========================
  Future<bool> requestStorage() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// =========================
  /// REQUEST MICROPHONE (for future liveness / voice)
  /// =========================
  Future<bool> requestMic() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// =========================
  /// OPEN SETTINGS (if denied permanently)
  /// =========================
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// =========================
  /// CHECK ALL STATUS
  /// =========================
  Future<Map<String, bool>> checkAll() async {
    return {
      "camera": await Permission.camera.isGranted,
      "storage": await Permission.storage.isGranted,
      "mic": await Permission.microphone.isGranted,
    };
  }
}
