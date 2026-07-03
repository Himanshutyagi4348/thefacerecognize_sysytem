// HomeScreen.dart
// (You already have this file — move your existing content here.)
import 'package:flutter/material.dart';

import '../recognition/recognization_screen.dart';
import '../registration/registration_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Face Recognition System",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 50),

              /// =========================
              /// REGISTER BUTTON
              /// =========================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegistrationScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Register Face",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// =========================
              /// RECOGNIZE BUTTON
              /// =========================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecognizationScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Recognize Face",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "Real-time AI Face Detection + Liveness",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
