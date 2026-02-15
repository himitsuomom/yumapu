// lib/app.dart
import 'package:flutter/material.dart';

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
      home: const Scaffold(
        body: Center(
          child: Text('Welcome to Yu-Map'),
        ),
      ),
    );
  }
}
