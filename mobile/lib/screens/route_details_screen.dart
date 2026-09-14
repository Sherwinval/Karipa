import 'package:flutter/material.dart';

class RouteDetailsScreen extends StatelessWidget {
  const RouteDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final activityType = args?['activityType'] ?? 'Activity';
    final distance = args?['distance'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Route Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.map, size: 64, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AI Generated Route',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Activity: $activityType • Distance: $distance km'),
            const SizedBox(height: 16),
            const Text(
              'This route was generated based on your preferences. It features a mostly flat terrain with scenic views along the path.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Activity'),
            ),
          ],
        ),
      ),
    );
  }
}
