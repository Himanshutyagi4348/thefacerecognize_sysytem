import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../../camera/camera_service.dart';
import '../../core/state/face_state.dart';
import '../../widgets/face_painter.dart';
import '../registration/registration_screen.dart';
import 'recognition_controller.dart';
import 'package:camera/camera.dart';

class RecognizationScreen extends StatefulWidget {
  const RecognizationScreen({super.key});

  @override
  State<RecognizationScreen> createState() => _RecognizationScreenState();
}

class _RecognizationScreenState extends State<RecognizationScreen> {
  late RecognitionController controller;
  final TextEditingController _adminUserController = TextEditingController();
  final TextEditingController _adminPassController = TextEditingController();
  final TextEditingController _registerNameController = TextEditingController();
  bool _hasNavigatedToRegistration = false;

  @override
  void initState() {
    super.initState();

    controller = RecognitionController();

    /// start camera once
    CameraService.instance.initialize();

    /// start recognition
    controller.start();
  }

  @override
  void dispose() {
    controller.dispose();
    _adminUserController.dispose();
    _adminPassController.dispose();
    _registerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<RecognitionController>(
          builder: (context, ctrl, _) {
            if (ctrl.redirectToRegistrationRequested &&
                !ctrl.adminLoginRequested &&
                !ctrl.isRegistering &&
                !_hasNavigatedToRegistration) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (!ctrl.adminLoginRequested && !ctrl.isRegistering) {
                  _hasNavigatedToRegistration = true;
                  ctrl.clearRedirectRequest();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistrationScreen(),
                    ),
                  ).then((_) {
                    _hasNavigatedToRegistration = false;
                  });
                }
              });
            }

            return Stack(
              children: [
                /// =========================
                /// CAMERA PREVIEW
                /// =========================
                CameraService.instance.controller != null &&
                        CameraService.instance.isInitialized
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(CameraService.instance.controller!),
                          if (ctrl.detectedFaces.isNotEmpty &&
                              ctrl.imageSize != null)
                            CustomPaint(
                              painter: FacePainter(
                                faces: ctrl.detectedFaces,
                                imageSize: ctrl.imageSize!,
                                rotation: InputImageRotation.rotation0deg,
                                label: FaceState.recognizedName,
                                isFrontCamera:
                                    CameraService
                                        .instance
                                        .currentLensDirection ==
                                    CameraLensDirection.front,
                              ),
                            ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),

                /// =========================
                /// TOP STATUS BAR
                /// =========================
                Positioned(
                  top: 60,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          FaceState.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 6),

                        /// confidence bar
                        LinearProgressIndicator(
                          value: FaceState.confidence,
                          backgroundColor: Colors.grey,
                          color: Colors.green,
                          minHeight: 5,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: SafeArea(
                    child: IconButton(
                      icon: const Icon(
                        Icons.cameraswitch,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () async {
                        await CameraService.instance.flipCamera();
                        setState(() {});
                      },
                    ),
                  ),
                ),

                /// =========================
                /// BOTTOM USER INFO
                /// =========================
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          FaceState.recognizedName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "Confidence: ${(FaceState.confidence * 100).toStringAsFixed(1)}%",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                if (ctrl.adminLoginRequested)
                  Positioned.fill(
                    child: Container(
                      color: const Color.fromRGBO(0, 0, 0, 0.65),
                      child: _buildGlassPopup(context, ctrl),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlassPopup(BuildContext context, RecognitionController ctrl) {
    return Align(
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.25),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Admin Login Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _adminUserController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Username',
                    hintStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _adminPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (ctrl.adminError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    ctrl.adminError,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final username = _adminUserController.text.trim();
                          final password = _adminPassController.text.trim();
                          final ok = await ctrl.loginAdmin(
                            username: username,
                            password: password,
                          );

                          if (!mounted) return;
                          if (ok) {
                            _showRegistrationForm(this.context, ctrl);
                          }
                        },
                        child: const Text('Login'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRegistrationForm(BuildContext context, RecognitionController ctrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text(
            'Register User',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _registerNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter user name',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Once you press Start, the camera will capture 5 angles automatically.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _registerNameController.text.trim();
                if (name.isEmpty) return;
                ctrl.beginRegistration(name);
                Navigator.pop(context);
              },
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
  }
}
