import 'package:flutter/material.dart';

import 'data/database/face_db.dart';
import 'features/home/HomeScreen.dart';
import 'features/recognition/recognization_screen.dart';
import 'ml/detection/face_detection_service.dart';
import 'ml/recognition/recognizer.dart';
import 'services/permission_service.dart';
import 'services/tts_service.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  /// =========================
  /// APP INITIALIZATION
  /// =========================
  Future<void> _initApp() async {
    await PermissionService.instance.requestAll();

    await FaceDB.init();
    FaceDetectionService.instance.init();
    await Recognizer.instance.loadModel();
    await TTSService.instance.init();

    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Recognition System',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: _initialized ? const HomeScreen() : const _LoadingScreen(),
    );
  }
}

/// =========================
/// LOADING SCREEN
/// =========================
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
