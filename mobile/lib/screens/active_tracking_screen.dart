import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../widgets/route_map_widget.dart';

class ActiveTrackingScreen extends StatefulWidget {
  final PathRoute route;
  final String activity;
  final Position? initialPosition;

  const ActiveTrackingScreen({
    super.key,
    required this.route,
    required this.activity,
    this.initialPosition,
  });

  @override
  State<ActiveTrackingScreen> createState() => _ActiveTrackingScreenState();
}

class _ActiveTrackingScreenState extends State<ActiveTrackingScreen> {
  // Activity state
  bool _isPaused = false;
  bool _isSaving = false;

  // Real GPS & movement data
  StreamSubscription<RecordedPoint>? _locationSubscription;
  final List<RecordedPoint> _recordedGpsPoints = [];
  final List<LatLng> _trackedLatLngs = [];
  LatLng? _currentPosition;

  // Active duration tracking (excluding paused intervals)
  Timer? _timer;
  int _activeSeconds = 0;
  DateTime _startedAt = DateTime.now();

  // Live metrics
  double _traveledDistanceMeters = 0.0;
  double _caloriesBurned = 0.0;

  double get _traveledDistanceKm => _traveledDistanceMeters / 1000.0;

  double get _remainingDistanceKm {
    final rem = widget.route.distanceKm - _traveledDistanceKm;
    return rem > 0 ? rem : 0.0;
  }

  bool get _isCycling => widget.activity.toLowerCase() == 'cycling';

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
    if (_isCycling) {
      return '${_speedKmh.toStringAsFixed(1)} km/h';
    }
    if (_paceSecondsPerKm == 0.0) return '--:--';
    final paceSec = _paceSecondsPerKm.round();
    final m = paceSec ~/ 60;
    final s = paceSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} /km';
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
    if (_remainingDistanceKm == 0) return 'Complete';
    if (_isCycling) {
      if (_speedKmh < 1.0) return '--';
      final remHours = _remainingDistanceKm / _speedKmh;
      final remMins = (remHours * 60).round();
      return '$remMins min';
    }

    if (_paceSecondsPerKm == 0.0) return '--';
    final remSec = (_remainingDistanceKm * _paceSecondsPerKm).round();
    final remMins = remSec ~/ 60;
    return '$remMins min';
  }

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();

    if (widget.initialPosition != null) {
      _currentPosition = LatLng(
        widget.initialPosition!.latitude,
        widget.initialPosition!.longitude,
      );
    }

    _startActiveTimer();
    _startGpsStream();
  }

  void _startActiveTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        setState(() {
          _activeSeconds++;
          _calculateCalories();
        });
      }
    });
  }

  void _calculateCalories() {
    // MET values: Walking 3.5, Jogging 7.0, Running 9.8, Cycling 7.5
    double met = 9.8;
    final act = widget.activity.toLowerCase();
    if (act == 'walking') {
      met = 3.5;
    } else if (act == 'jogging') {
      met = 7.0;
    } else if (act == 'cycling') {
      met = 7.5;
    }

    const assumedWeightKg = 70.0;
    final hours = _activeSeconds / 3600.0;
    _caloriesBurned = met * assumedWeightKg * hours;
  }

  void _startGpsStream() {
    _locationSubscription?.cancel();
    _locationSubscription = LocationService.getTrackingStream().listen(
      (recordedPoint) {
        if (_isPaused) return;

        setState(() {
          _currentPosition = recordedPoint.toLatLng();

          // Calculate real movement delta from last recorded point
          if (_recordedGpsPoints.isNotEmpty) {
            final lastPoint = _recordedGpsPoints.last;
            final deltaMeters = Geolocator.distanceBetween(
              lastPoint.latitude,
              lastPoint.longitude,
              recordedPoint.latitude,
              recordedPoint.longitude,
            );

            // Accumulate actual movement (filter stationary drift < 1.5m)
            if (deltaMeters >= 1.5) {
              _traveledDistanceMeters += deltaMeters;
            }
          }

          _recordedGpsPoints.add(recordedPoint);
          _trackedLatLngs.add(recordedPoint.toLatLng());
        });
      },
      onError: (err) {
        debugPrint('GPS stream error: $err');
      },
    );
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _confirmFinishActivity() async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish Activity?'),
        content: const Text(
          'Are you sure you want to finish and save your workout? Your GPS track and performance metrics will be finalized.',
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
      _finishAndSaveActivity();
    }
  }

  Future<void> _finishAndSaveActivity() async {
    _timer?.cancel();
    _locationSubscription?.cancel();

    setState(() => _isSaving = true);

    final completedAt = DateTime.now();

    final gpsDataList = _recordedGpsPoints.map((p) => p.toJson()).toList();

    try {
      await ApiService.saveActivity(
        activityType: widget.activity,
        distanceMeters: _traveledDistanceMeters,
        durationSeconds: _activeSeconds,
        averagePaceSecondsPerKm:
            _paceSecondsPerKm > 0 ? _paceSecondsPerKm : null,
        averageSpeedKmh: _speedKmh > 0 ? _speedKmh : null,
        calories: _caloriesBurned,
        startedAt: _startedAt,
        completedAt: completedAt,
        gpsData: gpsDataList,
        routeData: widget.route.rawJson,
      );
    } catch (e) {
      debugPrint('Failed to save activity to backend: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/activity_complete',
      arguments: {
        'activityType': widget.activity,
        'distanceKm': _traveledDistanceKm,
        'durationSeconds': _activeSeconds,
        'paceOrSpeed': _formattedPaceOrSpeed,
        'calories': _caloriesBurned,
        'route': widget.route,
        'gpsPoints': _trackedLatLngs,
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      routePoints: widget.route.coordinates,
                      trackedPoints: _trackedLatLngs,
                      currentLocation: _currentPosition,
                      interactive: true,
                      initialZoom: 15.5,
                    ),
                  ),
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
                                'DISTANCE',
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
                                    _traveledDistanceKm.toStringAsFixed(2),
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
                                    'km',
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
                              'CALORIES',
                              '${_caloriesBurned.toStringAsFixed(0)} kcal',
                              Icons.local_fire_department,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDarkMetricCard(
                              'REMAINING',
                              '${_remainingDistanceKm.toStringAsFixed(2)} km',
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
                      const Spacer(),

                      // Control Actions (Pause/Resume & Finish)
                      if (_isSaving)
                        Center(
                          child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.onSurface),
                        )
                      else
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
                                  'Finish',
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
