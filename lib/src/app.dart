import 'package:flutter/material.dart';

import 'ui/camera_screen.dart';
import 'ui/vhs_theme.dart';

class VhsCameraApp extends StatelessWidget {
  const VhsCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VHS Camera',
      debugShowCheckedModeBanner: false,
      theme: VhsTheme.data(),
      home: const CameraScreen(),
    );
  }
}
