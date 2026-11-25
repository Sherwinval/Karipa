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
  static const _inaccurateFixMessage =
      'GPS accuracy is too low to record this fix. Distance uses accurate GPS fixes only.';
  static const _staleFixMessage =
      'No recent accurate GPS fix. Recorded distance is not increasing until location updates resume.';
  static const _backgroundPauseMessage =
      'Recording paused because Karipa left the foreground. Background tracking is not supported; resume manually when the app is open.';

  // Active duration tracking (excluding paused intervals)
  Timer? _timer;
  final _metricTick = ValueNotifier(0);
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
          _locationMessage = _staleFixMessage;
        });
      }
    });
  }

  void _startActiveTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _metricTick.value++;
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
            _locationMessage = _inaccurateFixMessage;
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
      _locationMessage = _backgroundPauseMessage;
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
    _metricTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitPreferences>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = theme.brightness == Brightness.light
        ? const Color(0xFFF5F4EF)
        : scheme.surface;
    final activity = widget.activity;
    final activityName = activity.isEmpty
        ? 'Activity'
        : activity[0].toUpperCase() + activity.substring(1).toLowerCase();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _confirmFinishActivity();
      },
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: false,
          child: _RecordingWidth(
            horizontalInset: 0,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainer,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.control),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_isPaused ? Icons.pause : Icons.circle,
                                        size: _isPaused ? 14 : 8,
                                        color: _isPaused
                                            ? scheme.onSurfaceVariant
                                            : scheme.primary),
                                    const SizedBox(width: AppSpacing.xs),
                                    Flexible(
                                      child: Text(
                                        _isPaused ? 'Paused' : 'Tracking live',
                                        style: theme.textTheme.labelMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Text(activityName,
                                style: theme.textTheme.titleSmall),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close recording',
                        icon: const Icon(Icons.close),
                        onPressed: _confirmFinishActivity,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Size the map from the viewport before entering the scroll view.
                      final mapHeight =
                          (constraints.maxHeight * 0.39).clamp(140.0, 290.0);
                      return SingleChildScrollView(
                        key: const PageStorageKey('recording-content'),
                        // The side gutters allow a page swipe alongside the map.
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RepaintBoundary(
                              child: SizedBox(
                                height: mapHeight,
                                child: RouteMapWidget(
                                  routePoints:
                                      widget.route?.coordinates ?? const [],
                                  trackedPoints: _trackedLatLngs,
                                  currentLocation: _currentPosition,
                                  interactive: true,
                                  initialZoom: 15.5,
                                ),
                              ),
                            ),
                            _buildGpsStatus(context),
                            const SizedBox(height: AppSpacing.md),
                            ValueListenableBuilder(
                              valueListenable: _metricTick,
                              builder: (context, _, __) =>
                                  _buildMetrics(context, units),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _isFinished
            ? null
            : SafeArea(
                top: false,
                child: _RecordingWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(height: 1, color: _recordingBorder(scheme)),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: _RecordingPair(
                          minColumnWidth: 128,
                          first: _recordingButton(
                            context,
                            label: _isPaused ? 'Resume' : 'Pause',
                            icon: _isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_circle_outline,
                            onPressed: _togglePause,
                          ),
                          second: _recordingButton(
                            context,
                            label: 'Finish & Review',
                            icon: Icons.stop_outlined,
                            onPressed: _confirmFinishActivity,
                            primary: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildGpsStatus(BuildContext context) {
    final message = _locationMessage == _backgroundPauseMessage && !_isPaused
        ? null
        : _locationMessage;
    final waiting = message == _inaccurateFixMessage ||
        message == _staleFixMessage ||
        (!_isPaused && message == null && _lastAcceptedGpsAt == null);
    if (!waiting && message == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (title, summary) = switch (message) {
      _backgroundPauseMessage => (
          'Recording paused in the background',
          'Resume when Karipa is open.',
        ),
      _ when waiting => (
          'Waiting for accurate GPS',
          'Distance will update once GPS accuracy improves.',
        ),
      _ => ('GPS needs attention', message!),
    };

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
            scheme.onSurface.withValues(alpha: 0.05), scheme.surface),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(waiting ? Icons.gps_not_fixed : Icons.info_outline,
                    color: scheme.onSurfaceVariant, size: AppSizes.compactIcon),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(summary,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _RecordingDisclosure(
            key: const PageStorageKey('gps-details'),
            title: 'GPS details',
            details:
                '${message == null || message == summary ? '' : '$message\n\n'}'
                'Only accepted GPS fixes contribute to distance. A calorie estimate requires at least two accepted fixes and measured movement. Calorie availability does not affect the other metrics.',
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(BuildContext context, UnitPreferences units) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final calorieResult = _calorieResult;
    final calories = calorieResult.estimate?.calories;
    final calorieDetail = _profileWeightLoadFailed
        ? 'Profile weight could not be loaded. Other activity metrics are unaffected.'
        : calorieResult.unavailableReason;
    final about = _isFreeRecording
        ? 'Free Recording uses GPS observations only, without a predefined route or target distance.'
        : 'Remaining route distance and finish time are unavailable because route progress is not map-matched.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordingPair(
          minColumnWidth: 138,
          first: _PrimaryRecordingMetric(
            label: 'Recorded distance',
            value: units.distanceFromKm(_traveledDistanceKm).toStringAsFixed(2),
            unit: units.distanceUnit,
          ),
          second: _PrimaryRecordingMetric(
            label: 'Active time',
            value: _formattedActiveTime,
            detail: 'Elapsed ${_formatSeconds(_totalElapsedSeconds)}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _RecordingPair(
          minColumnWidth: 138,
          first: _RecordingMetricCard(
            label: _isCycling ? 'Speed' : 'Pace',
            value: _formattedPaceOrSpeed,
            icon: Icons.speed,
          ),
          second: _RecordingMetricCard(
            label: 'Est. gross calories',
            value: calories == null
                ? 'Unavailable'
                : '${calories.toStringAsFixed(0)} kcal',
            icon: Icons.local_fire_department_outlined,
          ),
        ),
        if (!_isFreeRecording) ...[
          const SizedBox(height: AppSpacing.md),
          _RecordingPair(
            minColumnWidth: 138,
            first: const _RecordingMetricCard(
                label: 'Est. remaining',
                value: 'Unavailable',
                icon: Icons.flag_outlined),
            second: _RecordingMetricCard(
                label: 'Est. finish',
                value: _formattedEta,
                icon: Icons.timelapse),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (!_isPaused)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.smartphone_outlined, size: 16, color: muted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text('Keep Karipa open while recording.',
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: muted))),
            ],
          ),
        _RecordingDisclosure(
          key: const PageStorageKey('about-recording'),
          icon: Icons.info_outline,
          title: _isFreeRecording
              ? 'About free recording'
              : 'About route recording',
          details: '$about\n\n'
              'MET category examples are provisional and await adviser review. Keep Karipa open. Background tracking and offline synchronization are not supported.'
              '${calories == null && calorieDetail != null ? '\n\nEstimated gross calories: $calorieDetail' : ''}',
        ),
      ],
    );
  }

  Widget _recordingButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control)),
        side: BorderSide.none,
        backgroundColor: primary ? scheme.primary : scheme.surfaceContainer,
        foregroundColor: primary ? scheme.onPrimary : scheme.onSurface,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          Icon(icon, size: AppSizes.compactIcon),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

Color _recordingBorder(ColorScheme scheme) =>
    Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.16), scheme.surface);

class _RecordingWidth extends StatelessWidget {
  const _RecordingWidth({
    required this.child,
    this.horizontalInset = AppSpacing.lg,
  });

  final Widget child;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) => Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalInset),
            child: child,
          ),
        ),
      );
}

class _RecordingPair extends StatelessWidget {
  const _RecordingPair(
      {required this.minColumnWidth,
      required this.first,
      required this.second});

  final double minColumnWidth;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    final minimum =
        minColumnWidth * (MediaQuery.textScalerOf(context).scale(16) / 16);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= minimum * 2 + AppSpacing.md) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: second),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, const SizedBox(height: AppSpacing.md), second],
      );
    });
  }
}

class _PrimaryRecordingMetric extends StatelessWidget {
  const _PrimaryRecordingMetric({
    required this.label,
    required this.value,
    this.unit,
    this.detail,
  });

  final String label;
  final String value;
  final String? unit;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text(label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(color: muted)),
        const SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(text: value, children: [
            if (unit != null)
              TextSpan(
                  text: ' $unit',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ]),
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (detail != null)
          Text(detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}

class _RecordingMetricCard extends StatelessWidget {
  const _RecordingMetricCard(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: _recordingBorder(scheme)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: Text(label,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant))),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _RecordingDisclosure extends StatelessWidget {
  const _RecordingDisclosure({
    super.key,
    required this.title,
    required this.details,
    this.icon,
  });

  final String title;
  final String details;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      minTileHeight: AppSizes.touchTarget,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      textColor: theme.colorScheme.onSurface,
      iconColor: theme.colorScheme.onSurfaceVariant,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(title, style: theme.textTheme.bodySmall)),
        ],
      ),
      children: [
        Text(details,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
