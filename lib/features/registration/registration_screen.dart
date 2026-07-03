import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../data/database/face_db.dart';
import '../../ml/cropper/face_cropper.dart';
import '../../widgets/face_painter.dart';
import '../../ml/recognition/recognizer.dart';
import '../../ml/embedding/embedings_utils.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final ImagePicker imagePicker = ImagePicker();
  final TextEditingController nameController = TextEditingController();

  File? _imageFile;
  ui.Image? uiImage;
  List<Face> faces = [];

  late FaceDetector faceDetector;
  bool modelLoaded = false;

  @override
  void initState() {
    super.initState();

    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: false,
        enableClassification: false,
      ),
    );

    _initModel();
  }

  /// =========================
  /// LOAD MODEL
  /// =========================
  Future<void> _initModel() async {
    try {
      await Recognizer.instance.loadModel();
      modelLoaded = true;
    } catch (e) {
      debugPrint("Model Load Error: $e");
    }
  }

  /// =========================
  /// CAMERA
  /// =========================
  Future<void> _imgFromCamera() async {
    final picked = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (picked == null) return;

    _imageFile = await _fixRotation(File(picked.path));
    await _processImage();
  }

  /// =========================
  /// FACE DETECTION
  /// =========================
  Future<void> _processImage() async {
    if (_imageFile == null) return;

    final inputImage = InputImage.fromFilePath(_imageFile!.path);
    faces = await faceDetector.processImage(inputImage);

    final bytes = await _imageFile!.readAsBytes();
    uiImage = await decodeImageFromList(bytes);

    setState(() {});
  }

  /// =========================
  /// FIX ORIENTATION
  /// =========================
  Future<File> _fixRotation(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return file;

    final fixed = img.bakeOrientation(image);
    return await file.writeAsBytes(img.encodeJpg(fixed));
  }

  /// =========================
  /// REGISTER FACE
  /// =========================
  Future<void> registerFace() async {
    if (!modelLoaded) return;

    if (_imageFile == null || nameController.text.isEmpty) {
      _show("Capture image + enter name");
      return;
    }

    if (faces.isEmpty) {
      _show("No face detected");
      return;
    }

    try {
      final cropped = await FaceCropper.cropFace(_imageFile!, faces.first);
      if (cropped == null) return;

      final bytes = await cropped.readAsBytes();

      final embedding = EmbeddingUtils.normalize(
        await Recognizer.instance.getEmbedding(bytes),
      );

      final embeddings = <List<double>>[embedding];

      final dir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(_imageFile!.path);
      final savedImage = await _imageFile!.copy('${dir.path}/$fileName');

      await FaceDB.insertFaceBatch(
        name: nameController.text,
        imagePath: savedImage.path,
        embeddings: embeddings,
      );

      _show("Face Registered Successfully ✅");

      setState(() {
        _imageFile = null;
        uiImage = null;
        faces.clear();
        nameController.clear();
      });
    } catch (e) {
      _show("Error: $e");
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    faceDetector.close();
    nameController.dispose();
    super.dispose();
  }

  /// =========================
  /// UI
  /// =========================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1f4037), Color(0xFF99f2c8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    "Face Registration",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// IMAGE VIEW
                  Container(
                    width: size * 0.85,
                    height: size * 0.85,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _imageFile == null
                          ? Image.asset("images/logo.png", fit: BoxFit.cover)
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(_imageFile!, fit: BoxFit.contain),

                                if (uiImage != null)
                                  CustomPaint(
                                    painter: FacePainter(
                                      faces: faces,
                                      imageSize: Size(
                                        uiImage!.width.toDouble(),
                                        uiImage!.height.toDouble(),
                                      ),
                                      rotation: InputImageRotation.rotation0deg,
                                      isFrontCamera: true,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// NAME INPUT
                  TextField(
                    controller: nameController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "Enter Name",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// CAMERA BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _imgFromCamera,
                      child: const Text("Open Camera"),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// REGISTER BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: registerFace,
                      child: const Text("Register Face"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
