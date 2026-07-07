import 'package:flutter/material.dart';

import '../constants.dart';
import 'package:face_recognition/screens/register_screen.dart' as reg;
import 'package:face_recognition/screens/verify_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// ===============================================================
  /// NAVIGATE TO REGISTER
  /// ===============================================================
  void _goToRegister(BuildContext context) {
    kDebugLog('HomeScreen: Navigating to RegisterScreen');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => reg.RegisterScreen()),
    );
  }

  /// ===============================================================
  /// NAVIGATE TO VERIFY
  /// ===============================================================
  void _goToVerify(BuildContext context) {
    kDebugLog('HomeScreen: Navigating to VerifyScreen');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerifyScreen()),
    );
  }

  /// ===============================================================
  /// UI
  /// ===============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              /// Title
              const Text(
                "Face Recognition System",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              /// REGISTER BUTTON
              ElevatedButton(
                onPressed: () => _goToRegister(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text(
                  "Register Face",
                  style: TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 20),

              /// VERIFY BUTTON
              ElevatedButton(
                onPressed: () => _goToVerify(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text(
                  "Verify Face",
                  style: TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 40),

              /// INFO CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Text(
                      "System Status",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "✔ Face Detection Active\n"
                      "✔ Embedding Model Loaded\n"
                      "✔ SQLite Database Ready",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
