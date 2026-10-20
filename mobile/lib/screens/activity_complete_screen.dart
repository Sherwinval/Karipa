import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/route_model.dart';
import '../services/api_service.dart';
import '../services/unit_preferences.dart';
import '../theme/design_tokens.dart';
import '../widgets/metric_tile.dart';
import '../widgets/route_map_widget.dart';

class ActivityCompleteScreen extends StatefulWidget {
  final String activityType;
  final String recordingMode;
  final double distanceKm;
  final int durationSeconds;
  final int totalElapsedSeconds;
  final DateTime startedAt;
  final DateTime completedAt;
  final String paceOrSpeed;
  final double? averagePaceSecondsPerKm;
  final double? averageSpeedKmh;
  final double? calories;
  final String? calorieUnavailableReason;
  final String? calorieMetCode;
  final double? calorieMetValue;
  final double? calorieWeightKg;
  final double? calorieDurationMinutes;
  final String? calorieMethodVersion;
  final PathRoute? route;
  final List<LatLng> gpsPoints;
  final List<Map<String, dynamic>> gpsData;
  final String idempotencyKey;

  ActivityCompleteScreen({
    super.key,
    required this.activityType,
    this.recordingMode = 'plan_route',
    required this.distanceKm,
    required this.durationSeconds,
    int? totalElapsedSeconds,
    DateTime? startedAt,
    DateTime? completedAt,
    required this.paceOrSpeed,
    this.averagePaceSecondsPerKm,
    this.averageSpeedKmh,
    required this.calories,
    this.calorieUnavailableReason,
    this.calorieMetCode,
    this.calorieMetValue,
    this.calorieWeightKg,
    this.calorieDurationMinutes,
    this.calorieMethodVersion,
    this.route,
    required this.gpsPoints,
    this.gpsData = const [],
    this.idempotencyKey = '',
  })  : totalElapsedSeconds = totalElapsedSeconds ?? durationSeconds,
        startedAt = startedAt ?? DateTime.now(),
        completedAt = completedAt ?? DateTime.now();

  @override
  State<ActivityCompleteScreen> createState() => _ActivityCompleteScreenState();
}

class _ActivityCompleteScreenState extends State<ActivityCompleteScreen> {
  bool _isSaving = false;
  bool _isSaved = false;
  bool _savedLocally = false;
  String? _saveError;

  bool get _isFreeRecording => widget.recordingMode == 'free_recording';

  Map<String, dynamic>? get _routeSummary {
    final route = widget.route;
    if (_isFreeRecording || route == null) return null;
    return {
      'id': route.id,
      'name': route.name,
      'activityType': route.activityType,
      'distanceKm': route.distanceKm,
      'targetDistanceKm': route.targetDistanceKm,
      'absoluteDistanceDeviationKm': route.absoluteDistanceDeviationKm,
      'percentageDistanceDeviation': route.percentageDistanceDeviation,
      'rankingSource': route.rankingSource,
    };
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

  Future<void> _saveActivity() async {
    if (_isSaving || _isSaved) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final result = await ApiService.saveActivity(
        activityType: widget.activityType,
        recordingMode: widget.recordingMode,
        distanceMeters: widget.distanceKm * 1000,
        durationSeconds: widget.durationSeconds,
        totalElapsedSeconds: widget.totalElapsedSeconds,
        targetDistanceMeters: _isFreeRecording || widget.route == null
            ? null
            : widget.route!.targetDistanceKm * 1000,
        routeData: _routeSummary,
        averagePaceSecondsPerKm: widget.averagePaceSecondsPerKm,
        averageSpeedKmh: widget.averageSpeedKmh,
        calories: widget.calories,
        calorieMetCode: widget.calorieMetCode,
        calorieMetValue: widget.calorieMetValue,
        calorieWeightKg: widget.calorieWeightKg,
        calorieDurationMinutes: widget.calorieDurationMinutes,
        calorieMethodVersion: widget.calorieMethodVersion,
        idempotencyKey: widget.idempotencyKey,
        startedAt: widget.startedAt,
        completedAt: widget.completedAt,
        gpsData: widget.gpsData,
      );
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'The activity was not saved.');
      }
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSaved = true;
        _savedLocally = result['localOnly'] == true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _discardActivity() async {
    if (_isSaved || _isSaving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard activity?'),
        content: const Text(
            'This unsaved recording will be discarded and will not appear in history or leaderboard totals.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep reviewing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  bool get _isCycling => widget.activityType.toLowerCase() == 'cycling';

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitPreferences>();
    final theme = Theme.of(context);
    return PopScope(
      canPop: _isSaved,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _discardActivity();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text(_isSaved ? 'Activity Saved' : 'Review Activity'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _isSaved ? Icons.check_circle_outline : Icons.flag_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  _isSaved ? 'Activity saved' : 'Review before saving',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _isSaved
                      ? _savedLocally
                          ? 'Saved on this device. Sign in to save activities to your account.'
                          : 'The server confirmed this activity was saved to your account.'
                      : 'This ${widget.activityType.toLowerCase()} activity is not saved yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.activityType.toUpperCase()} · ${_isFreeRecording ? 'FREE RECORDING' : 'PLAN A ROUTE'}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (widget.gpsPoints.isNotEmpty ||
                    (!_isFreeRecording &&
                        (widget.route?.coordinates.isNotEmpty ?? false))) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      child: RouteMapWidget(
                        routePoints: _isFreeRecording
                            ? const []
                            : widget.route?.coordinates ?? const [],
                        trackedPoints: widget.gpsPoints,
                        interactive: false,
                        initialZoom: 14.2,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'GPS distance',
                        value: units
                            .distanceFromKm(widget.distanceKm)
                            .toStringAsFixed(2),
                        unit: units.distanceUnit,
                        icon: Icons.straighten,
                        color: KaripaPalette.coral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricTile(
                        label: 'Active duration',
                        value: _formatDuration(widget.durationSeconds),
                        icon: Icons.timer_outlined,
                        color: KaripaPalette.coral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Total elapsed',
                        value: _formatDuration(widget.totalElapsedSeconds),
                        icon: Icons.schedule,
                        color: KaripaPalette.coral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricTile(
                        label: _isCycling ? 'Average speed' : 'Average pace',
                        value: widget.paceOrSpeed,
                        icon: Icons.speed,
                        color: KaripaPalette.coral,
                      ),
                    ),
                  ],
                ),
                if (!_isFreeRecording && widget.route != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Planned route: ${units.formatDistance(widget.route!.distanceKm)} actual network distance. Target: ${units.formatDistance(widget.route!.targetDistanceKm)}. Deviation: ${units.formatDistance(widget.route!.absoluteDistanceDeviationKm)} (${widget.route!.percentageDistanceDeviation.toStringAsFixed(1)}%). The GPS distance above is the recorded activity distance.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Estimated gross calories',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.calories == null
                      ? widget.calorieUnavailableReason ??
                          'Unavailable: valid weight and supported activity context are required.'
                      : '${widget.calories!.toStringAsFixed(0)} kcal · estimate',
                  style: theme.textTheme.bodyMedium,
                ),
                if (widget.calories != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Provisional MET ${widget.calorieMetCode ?? 'unknown'} (${widget.calorieMetValue?.toStringAsFixed(1) ?? 'unknown'} MET) × ${widget.calorieWeightKg == null ? 'unknown weight' : units.weightFromKg(widget.calorieWeightKg!).toStringAsFixed(1)} ${units.weightUnit} × ${widget.calorieDurationMinutes?.toStringAsFixed(2) ?? 'unknown'} counted minutes / 60. Adviser review is pending.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Could not save this activity: $_saveError. Retry to submit the same activity safely.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                if (_isSaving)
                  const Center(child: CircularProgressIndicator())
                else if (_isSaved) ...[
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context, '/home', (route) => false),
                    child: const Text('Back to Home'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, '/activity_history'),
                    child: const Text('View Activity History'),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _saveActivity,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                        _saveError == null ? 'Save Activity' : 'Retry Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KaripaPalette.coral,
                      foregroundColor: KaripaPalette.midnight,
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _discardActivity,
                    child: const Text('Discard Activity'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
