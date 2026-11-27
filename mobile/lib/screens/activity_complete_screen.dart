import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/route_model.dart';
import '../services/api_service.dart';
import '../services/unit_preferences.dart';
import '../theme/design_tokens.dart';
import '../widgets/activity_confirmation_dialog.dart';
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
  final _actionsKey = GlobalKey();
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
      _revealActionFeedback();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = error.toString().replaceFirst('Exception: ', '');
      });
      _revealActionFeedback();
    }
  }

  void _revealActionFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final actions = _actionsKey.currentContext;
      if (actions != null && Scrollable.maybeOf(actions) != null) {
        Scrollable.ensureVisible(actions, alignment: 1);
      }
    });
  }

  Future<void> _discardActivity() async {
    if (_isSaved || _isSaving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => const ActivityConfirmationDialog(
        title: 'Discard activity?',
        message: 'You’ll lose this recording and its metrics.',
        cancelLabel: 'Keep reviewing',
        confirmLabel: 'Discard activity',
        destructive: true,
      ),
    );
    if (discard == true && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  bool get _isCycling => widget.activityType.toLowerCase() == 'cycling';

  static final _paceOrSpeedWithUnit =
      RegExp(r'^(\S+) (min/km|min/mi|/km|/mi|km/h|mph)$');

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
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final margin = AppSpacing.pageMargin(constraints.maxWidth);
              final pinActions = constraints.maxHeight >= 540 &&
                  MediaQuery.textScalerOf(context).scale(16) <= 20;
              final actions = _buildActions(context);
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        margin,
                        AppSpacing.xl,
                        margin,
                        AppSpacing.xl,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppSizes.contentMaxWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._buildReview(context, units),
                              if (!pinActions) ...[
                                const SizedBox(height: AppSpacing.xl),
                                actions,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (pinActions)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          margin,
                          AppSpacing.md,
                          margin,
                          AppSpacing.sm,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppSizes.contentMaxWidth,
                            ),
                            child: actions,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReview(BuildContext context, UnitPreferences units) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final activity = widget.activityType;
    final activityLabel = activity.isEmpty
        ? 'Activity'
        : '${activity[0].toUpperCase()}${activity.substring(1).toLowerCase()}';
    final route = _isFreeRecording ? null : widget.route;
    final routePoints = route?.coordinates ?? const <LatLng>[];
    final paceOrSpeed = _paceOrSpeedWithUnit.firstMatch(widget.paceOrSpeed);

    return [
      Semantics(
        header: true,
        child: Text('Review activity', style: theme.textTheme.headlineSmall),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        '$activityLabel · ${_isFreeRecording ? 'Free recording' : 'Planned route'}',
        style: muted,
      ),
      if (!_isSaved) ...[
        const SizedBox(height: AppSpacing.md),
        Text(
          'Not saved yet',
          style: theme.textTheme.labelLarge,
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      _ReviewMetrics(metrics: [
        _ReviewMetric(
          label: 'GPS distance',
          value: units.distanceFromKm(widget.distanceKm).toStringAsFixed(2),
          unit: units.distanceUnit,
          icon: Icons.straighten,
        ),
        _ReviewMetric(
          label: 'Active duration',
          value: _formatDuration(widget.durationSeconds),
          icon: Icons.timer_outlined,
        ),
        _ReviewMetric(
          label: 'Total elapsed',
          value: _formatDuration(widget.totalElapsedSeconds),
          icon: Icons.schedule,
        ),
        _ReviewMetric(
          label: _isCycling ? 'Average speed' : 'Average pace',
          value: paceOrSpeed?.group(1) ?? widget.paceOrSpeed,
          unit: paceOrSpeed?.group(2),
          icon: Icons.speed,
        ),
      ]),
      if (widget.gpsPoints.isNotEmpty || routePoints.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: 148,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.panel),
            child: RouteMapWidget(
              routePoints: routePoints,
              trackedPoints: widget.gpsPoints,
              interactive: false,
              initialZoom: 14.2,
            ),
          ),
        ),
      ],
      if (route != null) ...[
        const SizedBox(height: AppSpacing.lg),
        Text('Planned route', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Network distance ${units.formatDistance(route.distanceKm)} · '
          'Target ${units.formatDistance(route.targetDistanceKm)}\n'
          'Deviation ${units.formatDistance(route.absoluteDistanceDeviationKm)} '
          '(${route.percentageDistanceDeviation.toStringAsFixed(1)}%)',
          style: muted,
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      Text('Estimated gross calories', style: theme.textTheme.titleSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(
        widget.calories == null
            ? 'Unavailable'
            : '${widget.calories!.toStringAsFixed(0)} kcal · estimate',
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        widget.calories == null
            ? widget.calorieUnavailableReason ??
                'Valid weight and supported activity context are required.'
            : 'Provisional MET ${widget.calorieMetCode ?? 'unknown'} '
                '(${widget.calorieMetValue?.toStringAsFixed(1) ?? 'unknown'} MET) '
                '× ${widget.calorieWeightKg == null ? 'unknown weight' : units.weightFromKg(widget.calorieWeightKg!).toStringAsFixed(1)} '
                '${units.weightUnit} × ${widget.calorieDurationMinutes?.toStringAsFixed(2) ?? 'unknown'} '
                'counted minutes / 60. Adviser review is pending.',
        style: muted,
      ),
    ];
  }

  Widget _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = _saveError;
    final primaryStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
    );
    final secondaryStyle = TextButton.styleFrom(
      minimumSize: const Size.fromHeight(AppSizes.touchTarget),
      foregroundColor: scheme.onSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
    return Column(
      key: _actionsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              'Could not save this activity.\n$error',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_isSaved) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _savedLocally ? 'Saved on this device' : 'Saved to your account',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            ),
            style: primaryStyle,
            child: const Text('Back to Home', textAlign: TextAlign.center),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/activity_history',
              (route) => false,
            ),
            style: secondaryStyle,
            child: const Text('View Activity History',
                textAlign: TextAlign.center),
          ),
        ] else ...[
          FilledButton(
            onPressed: _isSaving ? null : _saveActivity,
            style: primaryStyle,
            child: Semantics(
              liveRegion: _isSaving,
              child: Text(
                _isSaving
                    ? 'Saving…'
                    : error == null
                        ? 'Save activity'
                        : 'Retry save',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _isSaving ? null : _discardActivity,
            style: secondaryStyle,
            child: const Text('Discard activity', textAlign: TextAlign.center),
          ),
        ],
      ],
    );
  }
}

class _ReviewMetrics extends StatelessWidget {
  const _ReviewMetrics({required this.metrics});

  final List<_ReviewMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final cardWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        final twoColumns = scaler.scale(16) <= 20 &&
            cardWidth >= 124 &&
            metrics.every((metric) {
              final painter = TextPainter(
                text: TextSpan(
                    text: metric.value, style: metric.valueStyle(context)),
                textScaler: scaler,
                textDirection: Directionality.of(context),
              )..layout();
              final fits = painter.width <= cardWidth - 2 * AppSpacing.md;
              painter.dispose();
              return fits;
            });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: [
            if (twoColumns)
              for (var i = 0; i < metrics.length; i += 2)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.md,
                    children: [
                      for (final metric in [metrics[i], metrics[i + 1]])
                        Expanded(
                          child: metric.buildCard(
                            context,
                            paired: true,
                            reserveUnitSpace: metrics[i].unit != null ||
                                metrics[i + 1].unit != null,
                          ),
                        ),
                    ],
                  ),
                )
            else
              for (final metric in metrics) metric.buildCard(context),
          ],
        );
      },
    );
  }
}

class _ReviewMetric {
  const _ReviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.unit,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? unit;

  TextStyle? valueStyle(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return (value == 'Unavailable' ? text.titleMedium : text.headlineSmall)
        ?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  Widget buildCard(
    BuildContext context, {
    bool paired = false,
    bool reserveUnitSpace = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final unitStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Semantics(
      container: true,
      label: '$label: $value${unit == null ? '' : ' $unit'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        child: Column(
          mainAxisSize: paired ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(label, style: labelStyle)),
              ],
            ),
            if (paired) const Spacer(),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: valueStyle(context)),
            if (unit != null || reserveUnitSpace) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(unit ?? ' ', style: unitStyle),
            ],
          ],
        ),
      ),
    );
  }
}
