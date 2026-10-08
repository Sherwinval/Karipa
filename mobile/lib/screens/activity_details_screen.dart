import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/activity_model.dart';
import '../widgets/metric_tile.dart';
import '../widgets/route_map_widget.dart';
import '../services/api_service.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final ActivityModel activity;

  const ActivityDetailsScreen({super.key, required this.activity});

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: const Text('Are you sure you want to permanently delete this workout? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    final ok = await ApiService.deleteActivity(widget.activity.id);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete activity. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final isCycling = a.activityType.toLowerCase() == 'cycling';
    final dateFormatted = DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(a.startedAt);

    // Extract geometry coordinates from routeData if available
    final routePoints = <LatLng>[];
    if (a.routeData != null &&
        a.routeData!['geometry'] != null &&
        a.routeData!['geometry']['coordinates'] is List) {
      final coords = a.routeData!['geometry']['coordinates'] as List;
      for (var c in coords) {
        if (c is List && c.length >= 2) {
          routePoints.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('${a.activityType.toUpperCase()} Workout', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isDeleting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _isDeleting ? null : _handleDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Banner
              Text(
                dateFormatted,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),

              // Interactive Route & GPS Map
              Container(
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: RouteMapWidget(
                    routePoints: routePoints.isNotEmpty ? routePoints : a.gpsPoints,
                    trackedPoints: a.gpsPoints.isNotEmpty ? a.gpsPoints : null,
                    interactive: true,
                    initialZoom: 14.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Distance',
                      value: a.distanceKm.toStringAsFixed(2),
                      unit: 'km',
                      icon: Icons.straighten,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      label: 'Duration',
                      value: a.formattedDuration,
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
                      label: isCycling ? 'Avg Speed' : 'Avg Pace',
                      value: isCycling
                          ? '${(a.averageSpeedKmh ?? 0).toStringAsFixed(1)} km/h'
                          : a.formattedPace,
                      icon: Icons.speed,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      label: 'Calories Burned',
                      value: a.calories?.toStringAsFixed(0) ?? '0',
                      unit: 'kcal',
                      icon: Icons.local_fire_department,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // GPS Points Recorded summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.gps_fixed, color: Color(0xFF0D9488)),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GPS TRACKING FIDELITY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${a.gpsPoints.length} verified coordinate checkpoints recorded',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
