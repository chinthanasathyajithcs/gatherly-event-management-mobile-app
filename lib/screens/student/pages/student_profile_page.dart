import 'package:flutter/material.dart';

import '../widgets/student_tab_placeholder.dart';

class StudentProfilePage extends StatelessWidget {
  const StudentProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudentTabPlaceholder(title: 'Profile');
  }
}
