import 'package:flutter/material.dart';

class SuccessPulse extends StatefulWidget {
  const SuccessPulse({super.key});

  @override
  State<SuccessPulse> createState() => _SuccessPulseState();
}

class _SuccessPulseState extends State<SuccessPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = (0.3 * (1 - _controller.value)).clamp(0.0, 1.0);
        return Container(
          width: 120 + (_controller.value * 40),
          height: 120 + (_controller.value * 40),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.fromRGBO(76, 175, 80, opacity),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
