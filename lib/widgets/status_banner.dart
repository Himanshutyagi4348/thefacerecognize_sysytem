// status_banner.dart (NEW)
// Shows real-time status messages (e.g. "Face not detected", "Hold still").
import 'package:flutter/material.dart';

class StatusBanner extends StatelessWidget {
  final String message;
  const StatusBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black54,
      child: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
