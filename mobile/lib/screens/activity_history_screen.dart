import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/activity_model.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _isLoading = true;
  List<ActivityModel> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getActivities();
      if (mounted) {
        setState(() {
          _activities = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cycling':
        return Icons.directions_bike;
      case 'walking':
        return Icons.directions_walk;
      case 'jogging':
      case 'running':
      default:
        return Icons.directions_run;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Activity History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        color: Theme.of(context).colorScheme.onSurface,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.onSurface))
            : _activities.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface),
                          const SizedBox(height: 16),
                          const Text(
                            'No Activities Found',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Completed outdoor workouts recorded through GPS will be saved here automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                  context, '/activity_selection');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: KaripaPalette.coral,
                              foregroundColor: KaripaPalette.midnight,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Start an Activity'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      final item = _activities[index];
                      final dateFormatted = DateFormat('MMMM d, yyyy • h:mm a')
                          .format(item.startedAt);

                      return Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                        margin: const EdgeInsets.only(bottom: 14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/activity_details',
                              arguments: {'activity': item},
                            ).then((_) => _fetchHistory());
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getActivityIcon(item.activityType),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.activityType.toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dateFormatted,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildMetricCol('DISTANCE',
                                        '${item.distanceKm.toStringAsFixed(2)} km'),
                                    _buildMetricCol(
                                        'DURATION', item.formattedDuration),
                                    _buildMetricCol(
                                      item.activityType.toLowerCase() ==
                                              'cycling'
                                          ? 'SPEED'
                                          : 'PACE',
                                      item.activityType.toLowerCase() ==
                                              'cycling'
                                          ? '${(item.averageSpeedKmh ?? 0).toStringAsFixed(1)} km/h'
                                          : item.formattedPace,
                                    ),
                                    _buildMetricCol('CALORIES',
                                        '${item.calories?.toStringAsFixed(0) ?? '0'} kcal'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
