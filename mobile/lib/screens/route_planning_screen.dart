import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/design_tokens.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../utils/planning_duration.dart';

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
  static const _sliderTrackHeight = 12.0;
  static const _sliderThumbRadius = 12.0;
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
  bool _showCustomDistance = false;

  List<({String label, double km})> get _quickPresets =>
      switch (widget.activity.toLowerCase()) {
        'walking' => [
            (label: '3 km', km: 3),
            (label: '5 km', km: 5),
            (label: '10 km', km: 10)
          ],
        'cycling' => [
            (label: '10 km', km: 10),
            (label: '20 km', km: 20),
            (label: '30 km', km: 30),
            (label: '50 km', km: 50)
          ],
        _ => [
            (label: '5K', km: 5),
            (label: '10K', km: 10),
            (label: 'Half 21K', km: 21),
            (label: '~42.5K', km: 42.5)
          ],
      };

  void _selectPreset(double km) {
    if (_isGenerating) return;
    FocusScope.of(context).unfocus();
    if (km > _maximumTargetDistanceKm) {
      _customDistanceController.text = km.toStringAsFixed(1);
      _handleCustomDistanceChanged(_customDistanceController.text);
      setState(() => _showCustomDistance = true);
    } else {
      _customDistanceController.clear();
      setState(() {
        _customTargetDistanceKm = null;
        _customDistanceError = null;
        _targetDistanceKm = km;
      });
    }
  }

  void _returnToSlider() {
    FocusScope.of(context).unfocus();
    _customDistanceController.clear();
    _handleCustomDistanceChanged('');
    setState(() => _showCustomDistance = false);
  }

  bool _avoidMajorRoads = true;
  bool _preferSidewalks = true;
  bool _preferLoop = true;
  late bool _preferCyclingLanes;

  bool _isGenerating = false;
  String? _errorMessage;
  final _errorKey = GlobalKey();

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
    _customDistanceController.dispose();
    super.dispose();
  }

  void _handleStandardDistanceChanged(double value) {
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
    if (_isGenerating || _hasInvalidCustomDistance) return;
    FocusScope.of(context).unfocus();
    final distance = _customTargetDistanceKm ?? _targetDistanceKm;

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

      // 2. Call backend Route Generation API
      final routes = await ApiService.generateRoutes(
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

      if (!mounted) return;
      setState(() => _isGenerating = false);

      if (routes.isEmpty) {
        throw Exception(
            'No routes could be generated around this area. Try selecting a different distance.');
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final errorContext = _errorKey.currentContext;
        if (!mounted || errorContext == null) return;
        Scrollable.ensureVisible(errorContext,
            alignment: 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160));
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
      backgroundColor: colorScheme.brightness == Brightness.light
          ? const Color(0xFFF5F4EF)
          : colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Plan ${widget.activity.isEmpty ? 'Activity' : widget.activity[0].toUpperCase() + widget.activity.substring(1).toLowerCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.brightness == Brightness.light
            ? const Color(0xFFF5F4EF)
            : colorScheme.surface,
        elevation: 0,
      ),
      bottomNavigationBar: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
              child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: AppSizes.contentMaxWidth),
                    child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isGenerating || hasInvalidCustomDistance
                              ? null
                              : _handleGenerateRoutes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KaripaPalette.coral,
                            foregroundColor: KaripaPalette.midnight,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            side: BorderSide.none,
                          ),
                          child: _isGenerating
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: KaripaPalette.midnight,
                                          strokeWidth: 2),
                                    ),
                                    SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                          'Generating & Ranking Routes...',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                        )),
                  )),
            )),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: math.max(
                  AppSpacing.pageMargin(MediaQuery.sizeOf(context).width),
                  (MediaQuery.sizeOf(context).width -
                          AppSizes.contentMaxWidth) /
                      2),
              vertical: AppSpacing.lg),
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
                            'Target Distance',
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
                        child: Text.rich(
                          hasInvalidCustomDistance
                              ? TextSpan(text: distanceDisplayText)
                              : TextSpan(
                                  text: selectedDistanceKm.toStringAsFixed(1),
                                  children: [
                                    TextSpan(
                                        text: ' km',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge)
                                  ],
                                ),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: hasInvalidCustomDistance
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final preset in _quickPresets)
                            ChoiceChip(
                              label: Text(preset.label),
                              showCheckmark: false,
                              selectedColor: KaripaPalette.coral,
                              backgroundColor:
                                  colorScheme.brightness == Brightness.light
                                      ? const Color(0xFFF0EFEB)
                                      : colorScheme.surfaceContainerHighest,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              labelStyle: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: selectedDistanceKm == preset.km &&
                                              !hasInvalidCustomDistance
                                          ? KaripaPalette.midnight
                                          : colorScheme.onSurface),
                              selected: !hasInvalidCustomDistance &&
                                  selectedDistanceKm == preset.km,
                              onSelected: _isGenerating
                                  ? null
                                  : (_) => _selectPreset(preset.km),
                            ),
                        ]),
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
                                  scale: isRecentlySnapped &&
                                          !MediaQuery.disableAnimationsOf(
                                              context)
                                      ? 1.12
                                      : 1,
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
                          trackShape: const _GlassSliderTrackShape(),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: _sliderThumbRadius,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: _sliderOverlayRadius,
                          ),
                          activeTrackColor: KaripaPalette.coral,
                          inactiveTrackColor:
                              colorScheme.brightness == Brightness.light
                                  ? const Color(0xFFDDDAD2)
                                  : colorScheme.outlineVariant,
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
                                  value: _targetDistanceKm,
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
                    Text('Snaps to common distances.',
                        style: Theme.of(context).textTheme.bodySmall),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          alignment: AlignmentDirectional.centerStart,
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          foregroundColor:
                              colorScheme.brightness == Brightness.light
                                  ? const Color(0xFFAD340D)
                                  : colorScheme.primary),
                      onPressed: _isGenerating
                          ? null
                          : () => setState(
                              () => _showCustomDistance = !_showCustomDistance),
                      icon: Icon(
                          _showCustomDistance ? Icons.expand_less : Icons.add),
                      label: Text(_showCustomDistance
                          ? 'Hide custom distance'
                          : 'Enter a custom distance'),
                    ),
                    if (!_showCustomDistance)
                      Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('30.5–100 km',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: colorScheme.onSurfaceVariant))),
                    if (_showCustomDistance)
                      TextField(
                        controller: _customDistanceController,
                        enabled: !_isGenerating,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.done,
                        onChanged: _handleCustomDistanceChanged,
                        decoration: InputDecoration(
                          labelText: 'Custom distance (km)',
                          hintText: 'e.g. 30.5',
                          helperText: '30.5?100 km, in 0.5 km steps.',
                          helperMaxLines: 3,
                          errorText: _customDistanceError,
                        ),
                      ),
                    if (hasCustomDistanceInput)
                      TextButton(
                        onPressed: _isGenerating ? null : _returnToSlider,
                        child: const Text('Return to standard slider'),
                      ),
                    const Divider(height: AppSpacing.xl),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text('Estimated time',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium)),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                              child: Text(
                                  hasInvalidCustomDistance
                                      ? 'Enter a valid distance'
                                      : planningDuration(widget.activity,
                                              selectedDistanceKm)
                                          .duration,
                                  textAlign: TextAlign.end,
                                  style:
                                      Theme.of(context).textTheme.titleMedium)),
                        ]),
                    const SizedBox(height: AppSpacing.xs),
                    if (!hasInvalidCustomDistance)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          planningDuration(widget.activity, selectedDistanceKm)
                              .assumption,
                          textAlign: TextAlign.end,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                            'Start and finish at your current location.',
                            style: TextStyle(fontSize: 12)),
                        value: _preferLoop,
                        onChanged: _isGenerating
                            ? null
                            : (v) => setState(() => _preferLoop = v),
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Avoid Major Roads',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: const Text('When supported by routing data.',
                            style: TextStyle(fontSize: 12)),
                        value: _avoidMajorRoads,
                        onChanged: _isGenerating
                            ? null
                            : (v) => setState(() => _avoidMajorRoads = v),
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Prioritize Sidewalks & Trails',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: const Text('When available in map data.',
                            style: TextStyle(fontSize: 12)),
                        value: _preferSidewalks,
                        onChanged: _isGenerating
                            ? null
                            : (v) => setState(() => _preferSidewalks = v),
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
                          onChanged: _isGenerating
                              ? null
                              : (v) => setState(() => _preferCyclingLanes = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_errorMessage == null) const SizedBox(height: 20),
              if (_errorMessage != null)
                Container(
                  key: _errorKey,
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
                        child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 13),
                            )),
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
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(
          color: scheme.brightness == Brightness.light
              ? const Color(0xFFDDDAD2)
              : scheme.outlineVariant),
    );
  }
}

class _GlassSliderTrackShape extends RoundedRectSliderTrackShape {
  const _GlassSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(context, offset,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        enableAnimation: enableAnimation,
        textDirection: textDirection,
        thumbCenter: thumbCenter,
        secondaryOffset: secondaryOffset,
        isDiscrete: isDiscrete,
        isEnabled: isEnabled,
        additionalActiveTrackHeight: 0);
    final rect = getPreferredRect(
        parentBox: parentBox,
        offset: offset,
        sliderTheme: sliderTheme,
        isEnabled: isEnabled,
        isDiscrete: isDiscrete);
    if (rect.width <= 8 || rect.height <= 0) return;
    final highlight =
        Rect.fromLTWH(rect.left + 4, rect.top + 2, rect.width - 8, 2);
    context.canvas.drawRRect(
        RRect.fromRectAndRadius(highlight, const Radius.circular(2)),
        Paint()
          ..color = Colors.white.withValues(alpha: isEnabled ? 0.32 : 0.12));
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
      2.5,
      Paint()..color = markerColor,
    );
  }
}
