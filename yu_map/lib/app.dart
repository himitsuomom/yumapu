// lib/app.dart
import 'package:flutter/material.dart';
import 'package:yu_map/presentation/screens/map_screen.dart';

class YuMapApp extends StatelessWidget {
  const YuMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yu-Map',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
