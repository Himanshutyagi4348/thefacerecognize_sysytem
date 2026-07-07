import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'constants.dart';
import 'screens/home_screen.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Load available cameras BEFORE app starts
  kDebugLog('Initializing app and loading available cameras');
  cameras = await availableCameras();
  final cameraCount = cameras?.length ?? 0;
  final cameraNames = cameras?.map((c) => c.name).join(', ') ?? 'none';
  kDebugLog('Found $cameraCount camera(s): $cameraNames');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Face Recognition System',

      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        useMaterial3: true,
      ),

      home: const HomeScreen(),
    );
  }
}
