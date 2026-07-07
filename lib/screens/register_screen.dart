import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../constants.dart';
import '../models/embedding_model.dart';
import '../models/user_model.dart';
import '../db/embedding_db.dart';

import 'package:face_recognition/services/face_detector_service.dart' as fds;
import 'package:face_recognition/services/embedding_service.dart' as embs;
import 'package:face_recognition/services/tts_service.dart' as tts;

class RegisterScreen extends StatefulWidget {
  final String? userId;

  const RegisterScreen({super.key, this.userId});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  CameraController? _cameraController;
  fds.FaceDetectionResult? _faceResult;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isSwitchingCamera = false;

  final TextEditingController _userIdController = TextEditingController();
  String _currentUserId = 'unknown';
  bool _registrationStarted = false;
  int _poseIndex = 0;
  bool _isProcessing = false;

  final List<EmbeddingModel> _embeddings = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await embs.EmbeddingService.instance.loadModel();
    await _initCamera();
  }

  /// ===============================================================
  /// INIT CAMERA
  /// ===============================================================
  Future<void> _initCamera() async {
    kDebugLog('RegisterScreen: loading available cameras');
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      kDebugLog('RegisterScreen: no cameras found');
      return;
    }

    _cameraController = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    kDebugLog(
      'RegisterScreen: camera initialized (${_cameras[_selectedCameraIndex].name})',
    );

    setState(() {});
  }

  Future<void> switchCamera(CameraDescription newCamera) async {
    if (_isSwitchingCamera) return;

    _isSwitchingCamera = true;

    try {
      final oldController = _cameraController;

      _cameraController = null;
      setState(() {}); // remove preview immediately

      await oldController?.dispose();
      _selectedCameraIndex = _cameras.indexOf(newCamera);

      final newController = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await newController.initialize();

      if (!mounted) return;

      _cameraController = newController;
    } catch (e) {
      debugPrint("Camera switch error: $e");
    }

    _isSwitchingCamera = false;

    if (mounted) setState(() {});
  }

  /// ===============================================================
  /// START POSE FLOW
  /// ===============================================================
  Future<void> _startPoseFlow() async {
    kDebugLog('RegisterScreen: starting pose flow for user $_currentUserId');
    await tts.TTSService.instance.speakRegisterStart();

    await _requestPose();
  }

  Future<void> _beginRegistration() async {
    final enteredUserId = _userIdController.text.trim();
    if (enteredUserId.isEmpty) {
      await tts.TTSService.instance.speak(
        "Please enter a user name before starting registration.",
      );
      return;
    }

    _currentUserId = enteredUserId;
    _registrationStarted = true;
    setState(() {});

    await _startPoseFlow();
  }

  /// ===============================================================
  /// REQUEST CURRENT POSE
  /// ===============================================================
  Future<void> _requestPose() async {
    final pose = kRequiredPoses[_poseIndex];
    kDebugLog('RegisterScreen: requesting pose "$pose" (index $_poseIndex)');

    await tts.TTSService.instance.speakPoseInstruction(pose);

    Future.delayed(const Duration(seconds: 2), () {
      _capturePose();
    });
  }

  /// ===============================================================
  /// CAPTURE POSE EMBEDDING
  /// ===============================================================
  Future<void> _capturePose() async {
    if (_isProcessing || _cameraController == null) return;

    _isProcessing = true;
    kDebugLog(
      'RegisterScreen: capturing pose $_poseIndex for user $_currentUserId',
    );

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        kDebugLog('RegisterScreen: failed to decode captured image');
        await tts.TTSService.instance.speakError();
        _isProcessing = false;
        return;
      }

      /// 1. Detect + crop face
      /// NOTE: we detect straight from the captured JPEG file path
      /// (not from re-encoded bytes) — this is what actually fixes
      /// registration. See FaceDetectorService.detectFromFile for why.
      final result = await fds.FaceDetectorService.instance.detectFromFile(
        image.path,
        decoded,
      );

      if (result == null) {
        kDebugLog('RegisterScreen: face detection failed for pose $_poseIndex');

        await tts.TTSService.instance.speakError();

        _faceResult = null;

        if (mounted) {
          setState(() {});
        }

        _isProcessing = false;

        if (mounted) {
          await _requestPose(); // retry the same pose
        }
        return;
      }

      _faceResult = result;

      if (mounted) {
        setState(() {});
      }

      final face = result.croppedFace;

      /// 2. Generate embedding
      final embedding = await embs.EmbeddingService.instance.getEmbedding(face);

      kDebugLog(
        'RegisterScreen: generated embedding for pose ${kRequiredPoses[_poseIndex]}',
      );

      /// 3. Save embedding model
      final model = EmbeddingModel(
        userId: _currentUserId,
        pose: kRequiredPoses[_poseIndex],
        embedding: embedding,
        createdAt: DateTime.now(),
      );

      _embeddings.add(model);

      /// 4. Move to next pose
      _poseIndex++;

      if (_poseIndex < kRequiredPoses.length) {
        setState(() {});
        _isProcessing = false;
        await _requestPose();
      } else {
        _isProcessing = false;
        await _completeRegistration();
      }
    } catch (e) {
      kDebugLog('RegisterScreen: error during capture: $e');
      await tts.TTSService.instance.speakError();
      _isProcessing = false;

      if (mounted) {
        await _requestPose(); // retry the same pose
      }
    }
  }

  /// ===============================================================
  /// COMPLETE REGISTRATION
  /// ===============================================================
  Future<void> _completeRegistration() async {
    kDebugLog(
      'RegisterScreen: completing registration for user $_currentUserId, saving ${_embeddings.length} embeddings',
    );

    await EmbeddingDb.instance.upsertUser(
      UserModel(
        userId: _currentUserId,
        userName: _currentUserId,
        createdAt: DateTime.now(),
      ),
    );

    await EmbeddingDb.instance.insertEmbeddingsBatch(_embeddings);

    await tts.TTSService.instance.speak("Registration completed");

    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// ===============================================================
  /// UI
  /// ===============================================================
  @override
  Widget build(BuildContext context) {
    final pose = kRequiredPoses[_poseIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                //face box
                if (_faceResult != null)
                  Positioned(
                    left: _faceResult!.boundingBox.left,
                    top: _faceResult!.boundingBox.top,
                    width: _faceResult!.boundingBox.width,
                    height: _faceResult!.boundingBox.height,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.height,
                      height: _cameraController!.value.previewSize!.width,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),

                /// Overlay
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox.shrink(),
                            IconButton(
                              onPressed: () => switchCamera(
                                _cameras[(_selectedCameraIndex + 1) %
                                    _cameras.length],
                              ),
                              icon: const Icon(
                                Icons.flip_camera_android,
                                color: Colors.white,
                              ),
                              tooltip: 'Switch camera',
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        if (!_registrationStarted) ...[
                          TextField(
                            controller: _userIdController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter user name',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white12,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _beginRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 24,
                              ),
                            ),
                            child: const Text('Start Registration'),
                          ),
                        ] else ...[
                          Text(
                            "Registering User: $_currentUserId",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            "Pose: $pose",
                            style: const TextStyle(
                              color: Colors.yellow,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            "Step ${_poseIndex + 1} / ${kRequiredPoses.length}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                /// Progress bar
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: LinearProgressIndicator(
                      value: _poseIndex / kRequiredPoses.length,
                      backgroundColor: Colors.white24,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// ===============================================================
  /// DISPOSE
  /// ===============================================================
  @override
  void dispose() {
    _cameraController?.dispose();
    _userIdController.dispose();
    super.dispose();
  }
}
