import 'package:flutter/material.dart';

void main() {
  runApp(const PathCraftApp());
}

class PathCraftApp extends StatelessWidget {
  const PathCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PathCraft',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('PathCraft'),
        ),
      ),
    );
  }
}
