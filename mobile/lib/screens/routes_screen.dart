import 'package:flutter/material.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Routes')),
      body: const Center(
        child: Text('Saved and recommended routes will appear here.'),
      ),
    );
  }
}
