import 'package:flutter/material.dart';

class StudentTabPlaceholder extends StatelessWidget {
  final String title;

  const StudentTabPlaceholder({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0D1B2E),
        ),
      ),
    );
  }
}
