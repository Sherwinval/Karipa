import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class ActivitySelectionScreen extends StatefulWidget {
  const ActivitySelectionScreen({super.key});

  @override
  State<ActivitySelectionScreen> createState() =>
      _ActivitySelectionScreenState();
}

class _ActivitySelectionScreenState extends State<ActivitySelectionScreen> {
  String _selectedActivity = 'running';

  final List<Map<String, dynamic>> _activities = [
    {
      'id': 'walking',
      'title': 'Walking',
      'subtitle': 'Low impact, scenic strolls and pedestrian paths',
      'icon': Icons.directions_walk,
      'color': KaripaPalette.coral,
    },
    {
      'id': 'jogging',
      'title': 'Jogging',
      'subtitle': 'Moderate aerobic pace, park loops and quiet streets',
      'icon': Icons.directions_run,
      'color': KaripaPalette.coral,
    },
    {
      'id': 'running',
      'title': 'Running',
      'subtitle': 'Higher tempo workouts with smooth continuous pavement',
      'icon': Icons.directions_run_outlined,
      'color': KaripaPalette.coral,
    },
    {
      'id': 'cycling',
      'title': 'Cycling',
      'subtitle': 'Bike lanes, wider paved roads, and distance circuits',
      'icon': Icons.directions_bike,
      'color': KaripaPalette.coral,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Choose Activity',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose an activity and how you want to record it.',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Plan a route before recording, or start Free Recording without a target distance or route.',
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _activities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = _activities[index];
                    final isSelected = _selectedActivity == item['id'];
                    final color = item['color'] as Color;

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedActivity = item['id']);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? KaripaPalette.midnight
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: KaripaPalette.midnight
                                  .withValues(alpha: isSelected ? 0.14 : 0.08),
                              blurRadius: isSelected ? 16 : 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(item['icon'] as IconData,
                                  color: KaripaPalette.midnight, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'],
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['subtitle'],
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? KaripaPalette.coral
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.outline
                                      : Theme.of(context).colorScheme.outline,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 16, color: KaripaPalette.midnight)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/route_planning',
                    arguments: {'activity': _selectedActivity},
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: KaripaPalette.coral,
                  foregroundColor: KaripaPalette.midnight,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                ),
                child: const Text(
                  'Continue to Route Planning',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/active_tracking',
                    arguments: {
                      'activity': _selectedActivity,
                      'recordingMode': 'free_recording',
                    },
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.outline),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Start Free Recording',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
