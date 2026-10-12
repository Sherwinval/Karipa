import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class ActivitySetupScreen extends StatefulWidget {
  final String activityType;

  const ActivitySetupScreen({super.key, required this.activityType});

  @override
  State<ActivitySetupScreen> createState() => _ActivitySetupScreenState();
}

class _ActivitySetupScreenState extends State<ActivitySetupScreen> {
  final _distanceController = TextEditingController(text: '5');
  bool _isGenerating = false;

  void _generateRoute() {
    setState(() {
      _isGenerating = true;
    });

    // Simulate API call for now
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
      Navigator.pushNamed(context, '/route_details', arguments: {
        'activityType': widget.activityType,
        'distance': _distanceController.text,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Setup ${widget.activityType}')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Target Distance (km)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _distanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: 'km',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateRoute,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: KaripaPalette.coral,
                foregroundColor: KaripaPalette.midnight,
              ),
              child: _isGenerating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: KaripaPalette.midnight, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Generating your route...'),
                      ],
                    )
                  : const Text('Generate Route'),
            ),
          ],
        ),
      ),
    );
  }
}
