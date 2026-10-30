import 'package:flutter/material.dart';
import '../demo_theme.dart';

class DemoPill extends StatelessWidget {
  const DemoPill(this.text, {super.key, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
            color: demoGreen,
          ),
        ),
      );
}
