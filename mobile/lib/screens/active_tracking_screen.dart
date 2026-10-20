import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/design_tokens.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/calorie_estimation_service.dart';
import '../widgets/route_map_widget.dart';
import '../services/unit_preferences.dart';

class ActiveTrackingScreen extends StatefulWidget {
  final PathRoute? route;
  final String activity;
  final String recordingMode;
  final Position? initialPosition;

  const ActiveTrackingScreen({
    super.key,
    this.route,
    required this.activity,
    this.recordingMode = 'plan_route',
    this.initialPosition,
  });

  @override
  State<ActiveTrackingScreen> createState() => _ActiveTrackingScreenState();
}

class _ActiveTrackingScreenState extends State<ActiveTrackingScreen>
    with WidgetsBindingObserver {
  // Activity state
  bool _isPaused = false;
  bool _isFinished = false;

  // Real GPS & movement data
  StreamSubscription<RecordedPoint>? _locationSubscription;
  Timer? _gpsFreshnessTimer;
  final List<RecordedPoint> _recordedGpsPoints = [];
  RecordedPoint? _previousDistancePoint;
  final List<LatLng> _trackedLatLngs = [];
  LatLng? _currentPosition;
  DateTime? _lastAcceptedGpsAt;
  String? _locationMessage;

  // Active duration tracking (excluding paused intervals)
  Timer? _timer;
  final Stopwatch _activeStopwatch = Stopwatch();
  final Stopwatch _elapsedStopwatch = Stopwatch();
  DateTime _startedAt = DateTime.now();
  late final String _idempotencyKey;

  // Live metrics
  double _traveledDistanceMeters = 0.0;
  double? _profileWeightKg;
  bool _profileWeightLoadFailed = false;

  double get _traveledDistanceKm => _traveledDistanceMeters / 1000.0;
  int get _activeSeconds => _activeStopwatch.elapsed.inSeconds;
  int get _totalElapsedSeconds => _elapsedStopwatch.elapsed.inSeconds;

  bool get _isCycling => widget.activity.toLowerCase() == 'cycling';

  CalorieEstimateResult get _calorieResult => estimateGrossSessionCalories(
        activityType: widget.activity,
        weightKg: _profileWeightKg,
        distanceMeters: _traveledDistanceMeters,
        durationSeconds: _activeSeconds,
        acceptedGpsFixCount: _recordedGpsPoints.length,
      );

  GrossCalorieEstimate? get _calorieEstimate => _calorieResult.estimate;

  double? get _estimatedGrossCalories => _calorieEstimate?.calories;

  // Pace in seconds per km
  double get _paceSecondsPerKm {
    if (_traveledDistanceKm < 0.05 || _activeSeconds < 5) return 0.0;
    return _activeSeconds / _traveledDistanceKm;
  }

  // Speed in km/h
  double get _speedKmh {
    if (_activeSeconds < 5 || _traveledDistanceKm < 0.05) return 0.0;
    final hours = _activeSeconds / 3600.0;
    return _traveledDistanceKm / hours;
  }

  String get _formattedPaceOrSpeed {
    final units = context.read<UnitPreferences>();
    if (_isCycling) {
      return units.formatSpeed(_speedKmh);
    }
    if (_paceSecondsPerKm == 0.0) return '--:-- ${units.paceUnit}';
    return units.formatPace(_paceSecondsPerKm / 60);
  }

  String get _formattedActiveTime {
    final h = _activeSeconds ~/ 3600;
    final m = (_activeSeconds % 3600) ~/ 60;
    final s = _activeSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _formattedEta {
    return 'Unavailable';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startedAt = DateTime.now();
    _activeStopwatch.start();
    _elapsedStopwatch.start();
    _idempotencyKey = 'tracking-${_startedAt.toUtc().microsecondsSinceEpoch}';

    if (widget.initialPosition != null) {
      _currentPosition = LatLng(
        widget.initialPosition!.latitude,
        widget.initialPosition!.longitude,
      );
    }

    _startActiveTimer();
    unawaited(_startGpsStream());
    _loadProfileWeight();
    _gpsFreshnessTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final lastUpdate = _lastAcceptedGpsAt;
      if (_isPaused || lastUpdate == null || !mounted) return;
      if (DateTime.now().difference(lastUpdate) > const Duration(seconds: 15)) {
        setState(() {
          _locationMessage =
              'No recent accurate GPS fix. Recorded distance is not increasing until location updates resume.';
        });
      }
    });
  }

  void _startActiveTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadProfileWeight() async {
    try {
      final profile = await ApiService.getProfile();
      final value = profile['weightKg'];
      if (!mounted) return;
      setState(() {
        _profileWeightKg = value is num ? value.toDouble() : null;
        _profileWeightLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileWeightKg = null;
        _profileWeightLoadFailed = true;
      });
    }
  }

  Future<void> _startGpsStream() async {
    if (_isFinished) return;
    _locationSubscription?.cancel();
    final permissionStatus = await LocationService.checkAndRequestPermission();
    if (!mounted || _isFinished) return;
    if (permissionStatus != LocationStatus.ready) {
      setState(
          () => _locationMessage = _locationStatusMessage(permissionStatus));
      return;
    }

    _locationSubscription = LocationService.getTrackingStream().listen(
      (recordedPoint) {
        if (_isPaused || _isFinished) return;

        setState(() {
          _currentPosition = recordedPoint.toLatLng();

          if (recordedPoint.accuracy > 30.0) {
            _locationMessage =
                'GPS accuracy is too low to record this fix. Distance uses accurate GPS fixes only.';
            return;
          }

          final lastPoint = _previousDistancePoint;
          if (lastPoint != null) {
            _traveledDistanceMeters +=
                GpsSegmentDistance.acceptedMeters(lastPoint, recordedPoint);
          }

          _recordedGpsPoints.add(recordedPoint);
          _previousDistancePoint = recordedPoint;
          _trackedLatLngs.add(recordedPoint.toLatLng());
          _lastAcceptedGpsAt = recordedPoint.timestamp;
          _locationMessage = null;
        });
      },
      onError: (Object error) {
        unawaited(_handleGpsStreamError());
      },
    );
  }

  Future<void> _handleGpsStreamError() async {
    try {
      final status = await LocationService.checkPermission();
      if (!mounted) return;
      setState(() {
        _locationMessage = status == LocationStatus.ready
            ? 'GPS updates stopped. Recorded distance is based only on fixes already received.'
            : _locationStatusMessage(status);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationMessage =
            'GPS is unavailable. Recorded distance is based only on fixes already received.';
      });
    }
  }

  String _locationStatusMessage(LocationStatus status) {
    return switch (status) {
      LocationStatus.serviceDisabled =>
        'Location services are off. Turn on GPS to record additional distance.',
      LocationStatus.permissionDenied =>
        'Location permission is denied. Allow access in device settings to resume GPS recording.',
      LocationStatus.permissionDeniedForever =>
        'Location permission is blocked. Allow access in device settings to resume GPS recording.',
      LocationStatus.lowAccuracy =>
        'GPS accuracy is low. Recorded distance will not include inaccurate fixes.',
      LocationStatus.error =>
        'GPS is unavailable. Recorded distance will not be replaced by planned route distance.',
      LocationStatus.ready => 'GPS is ready.',
    };
  }

  void _togglePause() {
    if (_isFinished) return;
    final wasPaused = _isPaused;
    if (_isPaused) {
      _activeStopwatch.start();
    } else {
      _activeStopwatch.stop();
    }
    setState(() {
      _isPaused = !_isPaused;
      _previousDistancePoint = null;
    });
    if (wasPaused) unawaited(_startGpsStream());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive ||
        _isPaused ||
        _isFinished) {
      return;
    }
    _activeStopwatch.stop();
    setState(() {
      _isPaused = true;
      _previousDistancePoint = null;
      _locationMessage =
          'Recording paused because Karipa left the foreground. Background tracking is not supported; resume manually when the app is open.';
    });
  }

  Future<void> _confirmFinishActivity() async {
    if (_isFinished) return;
    final shouldFinish = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish Activity?'),
        content: const Text(
          'Finish recording and review your actual GPS metrics? The activity will not be saved until you choose Save.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Activity'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KaripaPalette.coral,
              foregroundColor: KaripaPalette.midnight,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finish Activity'),
          ),
        ],
      ),
    );

    if (shouldFinish == true) {
      _finishAndReviewActivity();
    }
  }

  void _finishAndReviewActivity() {
    if (_isFinished) return;
    _activeStopwatch.stop();
    _elapsedStopwatch.stop();
    _isPaused = true;
    _isFinished = true;
    _timer?.cancel();
    unawaited(_locationSubscription?.cancel());
    _gpsFreshnessTimer?.cancel();
    final completedAt = DateTime.now();
    final gpsDataList = _recordedGpsPoints.map((p) => p.toJson()).toList();
    Navigator.pushReplacementNamed(
      context,
      '/activity_complete',
      arguments: {
        'activityType': widget.activity,
        'recordingMode': widget.recordingMode,
        'distanceKm': _traveledDistanceKm,
        'durationSeconds': _activeSeconds,
        'activeDurationSeconds': _activeSeconds,
        'totalElapsedSeconds': completedAt.difference(_startedAt).inSeconds,
        'startedAt': _startedAt,
        'completedAt': completedAt,
        'paceOrSpeed': _formattedPaceOrSpeed,
        'averagePaceSecondsPerKm':
            _isCycling || _paceSecondsPerKm == 0 ? null : _paceSecondsPerKm,
        'averageSpeedKmh': !_isCycling || _speedKmh == 0 ? null : _speedKmh,
        'calories': _estimatedGrossCalories,
        'calorieUnavailableReason': _calorieResult.unavailableReason,
        'calorieMetCode': _calorieEstimate?.metCode,
        'calorieMetValue': _calorieEstimate?.metValue,
        'calorieWeightKg': _calorieEstimate?.weightKg,
        'calorieDurationMinutes': _calorieEstimate?.durationMinutes,
        'calorieMethodVersion': _calorieEstimate?.methodVersion,
        'route': widget.route,
        'idempotencyKey': _idempotencyKey,
        'gpsData': gpsDataList,
        'gpsPoints': _trackedLatLngs,
      },
    );
  }

  bool get _isFreeRecording => widget.recordingMode == 'free_recording';

  String _formatSeconds(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _locationSubscription?.cancel();
    _gpsFreshnessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitPreferences>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _confirmFinishActivity();
      },
      child: Scaffold(
        backgroundColor:
            Theme.of(context).colorScheme.surface, // Sleek dark tracking UI
        body: SafeArea(
          child: Column(
            children: [
              // Header bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isPaused
                                ? Theme.of(context).colorScheme.surfaceContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isPaused ? 'PAUSED' : 'TRACKING LIVE',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.activity.toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Theme.of(context).colorScheme.onSurface),
                      onPressed: _confirmFinishActivity,
                    ),
                  ],
                ),
              ),

              // Interactive live Map
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: RouteMapWidget(
                      routePoints: widget.route?.coordinates ?? const [],
                      trackedPoints: _trackedLatLngs,
                      currentLocation: _currentPosition,
                      interactive: true,
                      initialZoom: 15.5,
                    ),
                  ),
                ),
              ),

              if (_locationMessage != null || _profileWeightKg == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_locationMessage != null)
                        Text(
                          _locationMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (_estimatedGrossCalories == null)
                        Text(
                          _profileWeightLoadFailed
                              ? 'Gross calorie estimate unavailable: profile weight could not be loaded. Other activity metrics are unaffected.'
                              : '${_calorieResult.unavailableReason ?? 'Gross calorie estimate unavailable.'} Other activity metrics are unaffected.',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),

              // Tracking Metrics Dashboard
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Large Primary Metric Display (Distance & Time)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'RECORDED DISTANCE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    units
                                        .distanceFromKm(_traveledDistanceKm)
                                        .toStringAsFixed(2),
                                    style: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    units.distanceUnit,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                              height: 48,
                              width: 1,
                              color: Theme.of(context).colorScheme.outline),
                          Column(
                            children: [
                              Text(
                                'ACTIVE TIME',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formattedActiveTime,
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Elapsed ${_formatSeconds(_totalElapsedSeconds)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Secondary Metrics Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildDarkMetricCard(
                              _isCycling ? 'SPEED' : 'PACE',
                              _formattedPaceOrSpeed,
                              Icons.speed,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDarkMetricCard(
                              'EST. GROSS CALORIES · PROVISIONAL',
                              _estimatedGrossCalories == null
                                  ? 'Unavailable'
                                  : '${_estimatedGrossCalories!.toStringAsFixed(0)} kcal',
                              Icons.local_fire_department,
                            ),
                          ),
                        ],
                      ),
                      if (!_isFreeRecording) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDarkMetricCard(
                                'EST. REMAINING',
                                'Unavailable',
                                Icons.flag_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDarkMetricCard(
                                'EST. FINISH',
                                _formattedEta,
                                Icons.timelapse,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _isFreeRecording
                            ? 'Free Recording uses GPS observations only; no route or target distance is used. MET category examples are provisional and await adviser review. Keep Karipa open; background tracking and offline synchronization are not supported.'
                            : 'Remaining route distance and finish time are unavailable because route progress is not map-matched. MET category examples are provisional and await adviser review. Keep Karipa open; background tracking and offline synchronization are not supported.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 8),

                      // Control Actions (Pause/Resume & Finish)
                      if (!_isFinished)
                        Row(
                          children: [
                            // Pause / Resume Button
                            Expanded(
                              flex: 1,
                              child: ElevatedButton.icon(
                                onPressed: _togglePause,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isPaused
                                      ? KaripaPalette.coral
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainer,
                                  foregroundColor: _isPaused
                                      ? KaripaPalette.midnight
                                      : Theme.of(context).colorScheme.onSurface,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: Icon(
                                    _isPaused ? Icons.play_arrow : Icons.pause,
                                    size: 22),
                                label: Text(
                                  _isPaused ? 'Resume' : 'Pause',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Finish Button
                            Expanded(
                              flex: 1,
                              child: ElevatedButton.icon(
                                onPressed: _confirmFinishActivity,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: KaripaPalette.coral,
                                  foregroundColor: KaripaPalette.midnight,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.stop, size: 22),
                                label: const Text(
                                  'Finish & Review',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 14, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
