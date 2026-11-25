import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/design_tokens.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';

class RoutePlanningScreen extends StatefulWidget {
  final String activity;

  const RoutePlanningScreen({super.key, required this.activity});

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  static const _minimumTargetDistanceKm = 3.0;
  static const _maximumTargetDistanceKm = 30.0;
  static const _maximumCustomDistanceKm = 100.0;
  static const _targetDistanceStepKm = 0.5;
  static const _distanceSnapThresholdKm = 0.5;
  static const _sliderTrackHeight = 6.0;
  static const _sliderThumbRadius = 10.0;
  static const _sliderOverlayRadius = 24.0;
  static const _distancePresetsKm = <double>[
    3,
    5,
    10,
    15,
    20,
    25,
    30,
  ];

  double _targetDistanceKm = _minimumTargetDistanceKm;
  final _customDistanceController = TextEditingController();
  final Set<double> _snappedPresetsDuringGesture = {};
  Timer? _snapEmphasisTimer;
  double? _emphasizedPresetKm;
  double? _customTargetDistanceKm;
  String? _customDistanceError;

  bool _avoidMajorRoads = true;
  bool _preferSidewalks = true;
  bool _preferLoop = true;
  late bool _preferCyclingLanes;

  bool _isGenerating = false;
  String? _errorMessage;
  int _activeRequestId = 0;
  String? _activeJobId;
  Timer? _pollTimer;

  bool get _hasCustomDistanceInput =>
      _customDistanceController.text.trim().isNotEmpty;

  bool get _hasInvalidCustomDistance =>
      _hasCustomDistanceInput && _customTargetDistanceKm == null;

  @override
  void initState() {
    super.initState();
    _preferCyclingLanes = widget.activity.toLowerCase() == 'cycling';
  }

  @override
  void dispose() {
    _snapEmphasisTimer?.cancel();
    _pollTimer?.cancel();
    ++_activeRequestId;
    if (_activeJobId != null) {
      unawaited(ApiService.cancelRouteJob(_activeJobId!));
    }
    _customDistanceController.dispose();
    super.dispose();
  }

  void _cancelActiveGeneration({bool resetLoading = true}) {
    ++_activeRequestId;
    _pollTimer?.cancel();
    _pollTimer = null;
    final previousJobId = _activeJobId;
    _activeJobId = null;
    if (previousJobId != null) {
      unawaited(ApiService.cancelRouteJob(previousJobId));
    }
    if (mounted && resetLoading) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _handleStandardDistanceChanged(double value) {
    if (_isGenerating) _cancelActiveGeneration();
    final previousValue = _targetDistanceKm;
    final isLeavingPreset = _distancePresetsKm.contains(previousValue) &&
        (value - previousValue).abs() <= _targetDistanceStepKm;
    final nearestPreset = _distancePresetsKm.reduce(
      (nearest, preset) =>
          (preset - value).abs() < (nearest - value).abs() ? preset : nearest,
    );
    final shouldSnap = !isLeavingPreset &&
        (nearestPreset - value).abs() <= _distanceSnapThresholdKm;
    final nextValue = shouldSnap ? nearestPreset : value;
    if (nextValue == previousValue) return;
    final didSnap = shouldSnap && nextValue != value;

    setState(() {
      _targetDistanceKm = nextValue;
      if (didSnap) _emphasizedPresetKm = nearestPreset;
    });
    if (didSnap) {
      _snapEmphasisTimer?.cancel();
      _snapEmphasisTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        setState(() => _emphasizedPresetKm = null);
      });
      if (_snappedPresetsDuringGesture.add(nearestPreset)) {
        unawaited(HapticFeedback.selectionClick());
      }
    }
  }

  void _handleCustomDistanceChanged(String input) {
    if (_isGenerating) _cancelActiveGeneration();
    final trimmedInput = input.trim();
    setState(() {
      _customTargetDistanceKm = null;
      if (trimmedInput.isEmpty) {
        _customDistanceError = null;
        return;
      }

      final distance = double.tryParse(trimmedInput);
      if (distance == null || !distance.isFinite) {
        _customDistanceError = 'Enter a valid number of kilometers.';
        return;
      }
      if (distance <= _maximumTargetDistanceKm) {
        _customDistanceError = 'Enter a distance greater than 30 km.';
        return;
      }
      if (distance > _maximumCustomDistanceKm) {
        _customDistanceError = 'Maximum custom distance is 100 km.';
        return;
      }

      final halfStepCount = distance / _targetDistanceStepKm;
      if (!halfStepCount.isFinite ||
          halfStepCount != halfStepCount.roundToDouble()) {
        _customDistanceError = 'Use 0.5 km increments, such as 30.5 km.';
        return;
      }

      _customTargetDistanceKm = distance;
      _customDistanceError = null;
    });
  }

  Future<void> _handleGenerateRoutes() async {
    final distance = _customTargetDistanceKm ?? _targetDistanceKm;
    _cancelActiveGeneration(resetLoading: false);

    final currentRequestId = ++_activeRequestId;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      // 1. Acquire real GPS Location
      final permissionStatus =
          await LocationService.checkAndRequestPermission();

      if (permissionStatus == LocationStatus.serviceDisabled) {
        throw Exception(
            'Location services are turned off on your device. Please enable GPS in your device settings.');
      } else if (permissionStatus == LocationStatus.permissionDenied) {
        throw Exception(
            'Location permission was denied. Allow location access to create routes from your current position, then retry.');
      } else if (permissionStatus == LocationStatus.permissionDeniedForever) {
        throw Exception(
            'Location permission is blocked. Open your device settings to allow location access, then retry route planning.');
      }

      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        throw Exception(
            'Could not determine current GPS position. Please check your signal and try again.');
      }

      if (currentRequestId != _activeRequestId) return;

      // 2. Submit the asynchronous route generation job.
      final jobId = await ApiService.submitAsyncRouteJob(
        activity: widget.activity,
        targetDistanceKm: distance,
        preferences: {
          'avoidMajorRoads': _avoidMajorRoads,
          'preferSidewalks': _preferSidewalks,
          'preferLoop': _preferLoop,
          'preferCyclingInfrastructure': _preferCyclingLanes,
        },
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (currentRequestId != _activeRequestId || !mounted) {
        unawaited(ApiService.cancelRouteJob(jobId));
        return;
      }
      _activeJobId = jobId;

      final startedAt = DateTime.now();
      _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (currentRequestId != _activeRequestId || !mounted) {
          timer.cancel();
          return;
        }
        if (DateTime.now().difference(startedAt) >
            const Duration(seconds: 240)) {
          timer.cancel();
          _cancelActiveGeneration();
          if (mounted) {
            setState(() {
              _errorMessage =
                  'Route generation timed out. Please retry.';
            });
          }
          return;
        }

        try {
          final job = await ApiService.pollRouteJob(jobId);
          if (currentRequestId != _activeRequestId || !mounted) return;
          final status = job['status']?.toString();
          if (status == 'queued' || status == 'processing') return;
          timer.cancel();
          _pollTimer = null;

          if (status == 'completed') {
            final routes = ApiService.parseCompletedJobRoutes(job, null);
            _activeJobId = null;
            setState(() => _isGenerating = false);
            if (routes.isEmpty) {
              setState(() {
                _errorMessage =
                    'No routes could be generated around this area. Try selecting a different distance.';
              });
              return;
            }
            Navigator.pushNamed(
              context,
              '/recommended_routes',
              arguments: {
                'routes': routes,
                'activity': widget.activity,
                'targetDistanceKm': distance,
                'currentLocation': position,
              },
            );
            return;
          }
          if (status == 'cancelled') {
            if (currentRequestId == _activeRequestId) {
              setState(() {
                _isGenerating = false;
                _errorMessage = null;
              });
            }
            return;
          }
          if (status == 'expired') {
            throw Exception(
                'Route generation expired while waiting. Please retry.');
          }
          throw Exception(job['error']?.toString() ??
              'Route generation failed. Please retry.');
        } catch (e) {
          if (currentRequestId != _activeRequestId || !mounted) return;
          timer.cancel();
          _pollTimer = null;
          _activeJobId = null;
          setState(() {
            _isGenerating = false;
            _errorMessage =
                e.toString().replaceAll('Exception:', '').trim();
          });
        }
      });
    } catch (e) {
      if (currentRequestId != _activeRequestId || !mounted) return;
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCustomDistanceInput = _hasCustomDistanceInput;
    final hasInvalidCustomDistance = _hasInvalidCustomDistance;
    final selectedDistanceKm = _customTargetDistanceKm ?? _targetDistanceKm;
    final distanceDisplayText = hasInvalidCustomDistance
        ? 'Fix custom distance'
        : '${selectedDistanceKm.toStringAsFixed(1)} km';
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Plan ${widget.activity.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Target Distance Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.straighten,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 22),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Target Distance (km)',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: 'Selected distance',
                      value: hasInvalidCustomDistance
                          ? 'Custom distance is invalid. Correct it or clear the field to use the standard slider.'
                          : '${selectedDistanceKm.toStringAsFixed(1)} kilometers${_customTargetDistanceKm == null ? '' : ', custom target active'}',
                      child: ExcludeSemantics(
                        child: Text(
                          distanceDisplayText,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: hasInvalidCustomDistance
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final theme = Theme.of(context);
                        final markerTextStyle =
                            theme.textTheme.labelSmall ?? const TextStyle();
                        final emphasizedMarkerStyle = markerTextStyle.copyWith(
                          fontWeight: FontWeight.w800,
                        );
                        final direction = Directionality.of(context);
                        final markerMeasurements =
                            _distancePresetsKm.map((distance) {
                          final label = '${distance.toInt()} km';
                          final textPainter = TextPainter(
                            text: TextSpan(
                              text: label,
                              style: emphasizedMarkerStyle,
                            ),
                            textDirection: direction,
                            textScaler: MediaQuery.textScalerOf(context),
                            maxLines: 1,
                          )..layout();
                          return (
                            distance: distance,
                            label: label,
                            width: textPainter.width,
                            height: textPainter.height,
                          );
                        }).toList(growable: false);
                        final maximumMarkerWidth = markerMeasurements
                            .map((marker) => marker.width)
                            .reduce(
                              (first, second) =>
                                  first > second ? first : second,
                            );
                        final sliderHorizontalInset = math
                            .max(
                              _sliderOverlayRadius,
                              maximumMarkerWidth / 2,
                            )
                            .toDouble();
                        final trackInset =
                            sliderHorizontalInset + _sliderTrackHeight / 2;
                        final markerTrackWidth = math
                            .max(
                              0.0,
                              constraints.maxWidth -
                                  2 * sliderHorizontalInset -
                                  _sliderTrackHeight,
                            )
                            .toDouble();
                        double markerCenter(int index) {
                          final distance = markerMeasurements[index].distance;
                          final valuePosition =
                              (distance - _minimumTargetDistanceKm) /
                                  (_maximumTargetDistanceKm -
                                      _minimumTargetDistanceKm);
                          final visualPosition = direction == TextDirection.ltr
                              ? valuePosition
                              : 1 - valuePosition;
                          return trackInset + visualPosition * markerTrackWidth;
                        }

                        final middlePresetIndex =
                            _distancePresetsKm.indexOf(15);
                        final visibleMarkerIndices = <int>[];
                        bool hasRoomForMarker(int candidateIndex) {
                          final candidate = markerMeasurements[candidateIndex];
                          final candidateCenter = markerCenter(candidateIndex);
                          return visibleMarkerIndices.every((index) {
                            final existing = markerMeasurements[index];
                            final minimumGap =
                                (candidate.width + existing.width) / 2 +
                                    AppSpacing.sm;
                            return (candidateCenter - markerCenter(index))
                                    .abs() >=
                                minimumGap;
                          });
                        }

                        for (final candidateIndex in [
                          0,
                          markerMeasurements.length - 1,
                          middlePresetIndex,
                          2,
                          4,
                          1,
                          5,
                        ]) {
                          if (hasRoomForMarker(candidateIndex)) {
                            visibleMarkerIndices.add(candidateIndex);
                          }
                        }
                        visibleMarkerIndices.sort();

                        final markerLabels = visibleMarkerIndices.map((index) {
                          final marker = markerMeasurements[index];
                          final isSelectedPreset = !hasCustomDistanceInput &&
                              _targetDistanceKm == marker.distance;
                          final isRecentlySnapped = isSelectedPreset &&
                              _emphasizedPresetKm == marker.distance;
                          return Positioned(
                            left: markerCenter(index) - marker.width / 2,
                            top: 0,
                            width: marker.width,
                            height: marker.height,
                            child: IgnorePointer(
                              child: Center(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutBack,
                                  scale: isRecentlySnapped ? 1.12 : 1,
                                  child: Text(
                                    marker.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: markerTextStyle.copyWith(
                                      color: isRecentlySnapped
                                          ? colorScheme.primary
                                          : isSelectedPreset
                                              ? colorScheme.onSurface
                                              : colorScheme.onSurfaceVariant,
                                      fontWeight: isSelectedPreset
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(growable: false);
                        final labelAreaHeight = markerMeasurements
                            .map((marker) => marker.height)
                            .reduce(
                              (first, second) =>
                                  first > second ? first : second,
                            );
                        final sliderTheme = SliderTheme.of(context).copyWith(
                          padding: EdgeInsets.zero,
                          trackHeight: _sliderTrackHeight,
                          trackShape: const RoundedRectSliderTrackShape(),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: _sliderThumbRadius,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: _sliderOverlayRadius,
                          ),
                          activeTrackColor: KaripaPalette.coral,
                          inactiveTrackColor: colorScheme.outlineVariant,
                          thumbColor: KaripaPalette.coral,
                          overlayColor:
                              KaripaPalette.coral.withValues(alpha: 0.16),
                          tickMarkShape: const _DistancePresetTickMarkShape(
                            minimum: _minimumTargetDistanceKm,
                            maximum: _maximumTargetDistanceKm,
                            step: _targetDistanceStepKm,
                            presets: _distancePresetsKm,
                          ),
                          activeTickMarkColor: colorScheme.onPrimary,
                          inactiveTickMarkColor:
                              colorScheme.brightness == Brightness.light
                                  ? KaripaPalette.stone
                                  : KaripaPalette.charcoal,
                          valueIndicatorColor: KaripaPalette.coral,
                          valueIndicatorTextStyle: const TextStyle(
                            color: KaripaPalette.midnight,
                            fontWeight: FontWeight.w600,
                          ),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SliderTheme(
                              data: sliderTheme,
                              child: Semantics(
                                label: hasCustomDistanceInput
                                    ? 'Standard distance slider'
                                    : 'Target distance',
                                hint: hasCustomDistanceInput
                                    ? _customTargetDistanceKm == null
                                        ? 'The custom distance is invalid. Correct or clear the field to use the standard slider.'
                                        : 'The custom target is active. Clear the custom distance field to use this 3 to 30 kilometer slider.'
                                    : 'Drag or tap the track to adjust between 3 and 30 kilometers in 0.5 kilometer increments.',
                                child: Slider(
                                  onChangeStart: (_) =>
                                      _snappedPresetsDuringGesture.clear(),
                                  onChangeEnd: (_) =>
                                      _snappedPresetsDuringGesture.clear(),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: sliderHorizontalInset,
                                  ),
                                  value: _customTargetDistanceKm == null
                                      ? _targetDistanceKm
                                      : _maximumTargetDistanceKm,
                                  min: _minimumTargetDistanceKm,
                                  max: _maximumTargetDistanceKm,
                                  divisions: ((_maximumTargetDistanceKm -
                                              _minimumTargetDistanceKm) /
                                          _targetDistanceStepKm)
                                      .round(),
                                  label: hasCustomDistanceInput
                                      ? 'Standard range only'
                                      : '${_targetDistanceKm.toStringAsFixed(1)} km',
                                  semanticFormatterCallback: (value) =>
                                      '${value.toStringAsFixed(1)} kilometers',
                                  onChanged:
                                      hasCustomDistanceInput || _isGenerating
                                          ? null
                                          : _handleStandardDistanceChanged,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            SizedBox(
                              height: labelAreaHeight,
                              child: Stack(children: markerLabels),
                            ),
                            if (_customTargetDistanceKm != null ||
                                hasInvalidCustomDistance) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                hasInvalidCustomDistance
                                    ? 'Standard slider paused until the custom distance is corrected or cleared.'
                                    : 'Custom target active; standard slider covers 3 to 30 km.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _customDistanceController,
                      enabled: !_isGenerating,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onChanged: _handleCustomDistanceChanged,
                      decoration: InputDecoration(
                        labelText: 'Custom distance (km)',
                        hintText: 'e.g. 30.5',
                        helperText:
                            'Leave blank for slider. Custom: 30.5 to 100 km in 0.5 km steps.',
                        helperMaxLines: 3,
                        errorText: _customDistanceError,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Route Preferences Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(context),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Route Preferences',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Prefer Circular Loop',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: const Text(
                            'Route starts and finishes at your current location',
                            style: TextStyle(fontSize: 12)),
                        value: _preferLoop,
                        onChanged: (v) {
                          if (_isGenerating) _cancelActiveGeneration();
                          setState(() => _preferLoop = v);
                        },
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Avoid Major Roads',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: const Text(
                            'Applied only when routing data supports this preference',
                            style: TextStyle(fontSize: 12)),
                        value: _avoidMajorRoads,
                        onChanged: (v) {
                          if (_isGenerating) _cancelActiveGeneration();
                          setState(() => _avoidMajorRoads = v);
                        },
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Prioritize Sidewalks & Trails',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: const Text(
                            'Sidewalk availability may be unknown in map data',
                            style: TextStyle(fontSize: 12)),
                        value: _preferSidewalks,
                        onChanged: (v) {
                          if (_isGenerating) _cancelActiveGeneration();
                          setState(() => _preferSidewalks = v);
                        },
                      ),
                      if (widget.activity.toLowerCase() == 'cycling') ...[
                        const Divider(),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Cycling Infrastructure',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: const Text(
                              'Cycling infrastructure may be unavailable in map data',
                              style: TextStyle(fontSize: 12)),
                          value: _preferCyclingLanes,
                          onChanged: (v) {
                            if (_isGenerating) _cancelActiveGeneration();
                            setState(() => _preferCyclingLanes = v);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_errorMessage == null) const SizedBox(height: 20),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              ElevatedButton(
                onPressed: _isGenerating
                    ? () => _cancelActiveGeneration()
                    : hasInvalidCustomDistance
                        ? null
                        : _handleGenerateRoutes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KaripaPalette.coral,
                  foregroundColor: KaripaPalette.midnight,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                ),
                child: _isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel_outlined, size: 20),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text('Cancel Generation',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Generate Routes',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: scheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

class _DistancePresetTickMarkShape extends SliderTickMarkShape {
  const _DistancePresetTickMarkShape({
    required this.minimum,
    required this.maximum,
    required this.step,
    required this.presets,
  });

  final double minimum;
  final double maximum;
  final double step;
  final List<double> presets;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) =>
      Size.zero;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required bool isEnabled,
    required TextDirection textDirection,
  }) {
    final trackRect = sliderTheme.trackShape!.getPreferredRect(
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: true,
    );
    final trackPadding = trackRect.height;
    final adjustedTrackWidth = trackRect.width - trackPadding;
    if (adjustedTrackWidth <= 0) return;

    var position =
        (center.dx - trackRect.left - trackPadding / 2) / adjustedTrackWidth;
    if (textDirection == TextDirection.rtl) position = 1 - position;
    final intervalCount = ((maximum - minimum) / step).round();
    final tickIndex = (position * intervalCount).round();
    final distance = minimum + tickIndex * step;
    if (!presets.contains(distance)) return;

    final isOnActiveTrack = textDirection == TextDirection.ltr
        ? center.dx < thumbCenter.dx
        : center.dx > thumbCenter.dx;
    final markerColor = isOnActiveTrack
        ? sliderTheme.activeTickMarkColor!
        : sliderTheme.inactiveTickMarkColor!;
    context.canvas.drawCircle(
      center,
      4.5,
      Paint()..color = markerColor,
    );
  }
}
