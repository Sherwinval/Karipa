import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../widgets/metric_tile.dart';
import '../widgets/route_map_widget.dart';

class ActivityCompleteScreen extends StatelessWidget {
  final String activityType;
  final double distanceKm;
  final int durationSeconds;
  final String paceOrSpeed;
  final double calories;
  final PathRoute route;
  final List<LatLng> gpsPoints;

  const ActivityCompleteScreen({
    super.key,
    required this.activityType,
    required this.distanceKm,
    required this.durationSeconds,
    required this.paceOrSpeed,
    required this.calories,
    required this.route,
    required this.gpsPoints,
  });

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Activity Summary', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Celebration Badge
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 46,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Activity Complete! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Great job! Your ${activityType.toLowerCase()} workout has been recorded and saved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),

              // Recorded Map Track
              if (gpsPoints.isNotEmpty || route.coordinates.isNotEmpty)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: RouteMapWidget(
                      routePoints: route.coordinates,
                      trackedPoints: gpsPoints,
                      interactive: false,
                      initialZoom: 14.2,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Final Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Distance',
                      value: distanceKm.toStringAsFixed(2),
                      unit: 'km',
                      icon: Icons.straighten,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      label: 'Duration',
                      value: _formatDuration(durationSeconds),
                      icon: Icons.timer_outlined,
                      color: Colors.indigo.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: activityType.toLowerCase() == 'cycling' ? 'Avg Speed' : 'Avg Pace',
                      value: paceOrSpeed,
                      icon: Icons.speed,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      label: 'Burned',
                      value: calories.toStringAsFixed(0),
                      unit: 'kcal',
                      icon: Icons.local_fire_department,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Actions
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                ),
                child: const Text('Back to Home Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/activity_history');
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: const Color(0xFF0D9488),
                  side: const BorderSide(color: Color(0xFF0D9488)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('View All Activity History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
