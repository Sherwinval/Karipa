import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/activity_model.dart';
import 'package:provider/provider.dart';
import '../services/unit_preferences.dart';
import '../widgets/main_tab_scope.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _isLoading = true;
  bool _wasActive = true;
  List<ActivityModel> _activities = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = MainTabScope.maybeOf(context);
    final active = scope == null || scope.index == 2;
    if (active && !_wasActive && !_isLoading) _fetchHistory();
    _wasActive = active;
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getActivities();
      if (mounted) {
        setState(() {
          _activities = list;
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
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
    final units = context.watch<UnitPreferences>();
    return MainSection(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: MainTabScope.maybeOf(context) != null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (route) => false),
              ),
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
            : _errorMessage != null
                ? Center(
                    child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchHistory,
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        )),
                  )
                : _activities.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_toggle_off,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Activities Found',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
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
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Start an Activity'),
                                  ),
                                ],
                              ),
                            )),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _activities.length,
                        itemBuilder: (context, index) {
                          final item = _activities[index];
                          final dateFormatted =
                              DateFormat('MMMM d, yyyy • h:mm a')
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
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                                                item.recordingMode ==
                                                        'free_recording'
                                                    ? 'Free Recording'
                                                    : 'Plan a Route',
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    fontSize: 12),
                                              ),
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
                                    Wrap(
                                      spacing: AppSpacing.lg,
                                      runSpacing: AppSpacing.md,
                                      children: [
                                        _buildMetricCol(
                                            'DISTANCE',
                                            units.formatDistance(
                                                item.distanceKm)),
                                        _buildMetricCol(
                                            'ACTIVE', item.formattedDuration),
                                        _buildMetricCol(
                                          item.activityType.toLowerCase() ==
                                                  'cycling'
                                              ? 'SPEED'
                                              : 'PACE',
                                          item.activityType.toLowerCase() ==
                                                  'cycling'
                                              ? units.formatSpeed(
                                                  item.averageSpeedKmh ?? 0)
                                              : units.formatPace(
                                                  item.averagePaceMinPerKm ??
                                                      0),
                                        ),
                                        _buildMetricCol(
                                          'EST. GROSS CALORIES · PROVISIONAL',
                                          item.calories == null
                                              ? 'Unavailable'
                                              : '${item.calories!.toStringAsFixed(0)} kcal',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Total elapsed: ${_formatDuration(item.totalElapsedSeconds)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
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

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}
