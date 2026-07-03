import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../camera/camera_service.dart';
import '../../core/state/face_state.dart';
import 'recognition_controller.dart';
import 'package:camera/camera.dart';

class RecognizationScreen extends StatefulWidget {
  const RecognizationScreen({super.key});

  @override
  State<RecognizationScreen> createState() => _RecognizationScreenState();
}

class _RecognizationScreenState extends State<RecognizationScreen> {
  late RecognitionController controller;

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
            return Stack(
              children: [
                /// =========================
                /// CAMERA PREVIEW
                /// =========================
                CameraService.instance.controller != null &&
                        CameraService.instance.isInitialized
                    ? CameraPreview(CameraService.instance.controller!)
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
              ],
            );
          },
        ),
      ),
    );
  }
}
