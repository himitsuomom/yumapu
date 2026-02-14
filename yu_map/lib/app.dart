// lib/app.dart
import 'package:flutter/material.dart';
import 'package:yu_map/ui/screens/settings_screen.dart';
import 'package:yu_map/ui/screens/review_photo_screen.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/reviews': (context) => const ReviewPhotoScreen(facilityId: 'sample-facility-id'),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yu-Map'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Yu-Map',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              child: const Text('設定画面へ'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/reviews');
              },
              child: const Text('レビュー画面へ'),
            ),
          ],
        ),
      ),
    );
  }
}
