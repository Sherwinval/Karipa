import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'package:provider/provider.dart';
import '../services/unit_preferences.dart';
import 'karipa_button.dart';
import 'karipa_feedback.dart';
import 'section_heading.dart';
import 'karipa_logo.dart';

/// Home presentation only. The screen owns fetching, totals and navigation.
class HomeDashboard extends StatelessWidget {
  final String userName;
  final bool isLoading;
  final String distance;
  final String activityCount;
  final String activeTime;
  final String calories;
  final List<Widget> recentActivities;
  final int currentIndex;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onNavigationTapped;
  final VoidCallback onProfile;
  final VoidCallback onStartActivity;
  final VoidCallback onViewAll;

  const HomeDashboard(
      {super.key,
      required this.userName,
      required this.isLoading,
      required this.distance,
      required this.activityCount,
      required this.activeTime,
      required this.calories,
      required this.recentActivities,
      required this.currentIndex,
      required this.onRefresh,
      required this.onNavigationTapped,
      required this.onProfile,
      required this.onStartActivity,
      required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = context.watch<UnitPreferences>();

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light
          ? KaripaPalette.homeBackground
          : scheme.surface,
      appBar: AppBar(
        backgroundColor: KaripaPalette.navy,
        foregroundColor: KaripaPalette.white,
        toolbarHeight: kToolbarHeight,
        title: const KaripaLogo(
          width: 148,
          horizontal: true,
          blendBackground: true,
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: IconButton(
              constraints: const BoxConstraints(
                  minWidth: AppSizes.touchTarget,
                  minHeight: AppSizes.touchTarget),
              tooltip: 'Open profile',
              color: KaripaPalette.white,
              onPressed: onProfile,
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: scheme.onPrimary,
          backgroundColor: scheme.primary,
          child: LayoutBuilder(builder: (context, constraints) {
            final margin = AppSpacing.pageMargin(constraints.maxWidth);
            return SingleChildScrollView(
              key: const ValueKey('home-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  margin, AppSpacing.lg, margin, AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HomeStart(userName: userName, onStart: onStartActivity),
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        children: [
                          const SectionHeading(title: 'Your progress'),
                          Text('All-time',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (isLoading) ...[
                        const KaripaProgress(label: 'Updating activity totals'),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      _HomeStats(
                        distance: distance,
                        activityCount: activityCount,
                        activeTime: activeTime,
                        calories: calories,
                        distanceUnit: units.distanceUnit,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        children: [
                          const SectionHeading(title: 'Recent activities'),
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(
                                  AppSizes.touchTarget, AppSizes.touchTarget),
                              foregroundColor: scheme.onSurface,
                            ),
                            onPressed: onViewAll,
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                      if (isLoading)
                        const KaripaProgress(label: 'Loading recent activities')
                      else if (recentActivities.isEmpty)
                        const _HomeEmptyHistory()
                      else
                        for (final activity in recentActivities) ...[
                          activity,
                          const SizedBox(height: AppSpacing.sm),
                        ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: _HomeNavigation(
        currentIndex: currentIndex,
        onTap: onNavigationTapped,
      ),
    );
  }
}

class _HomeStart extends StatelessWidget {
  const _HomeStart({required this.userName, required this.onStart});

  final String userName;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KaripaPalette.navy,
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Hello, $userName',
                style: type.labelMedium?.copyWith(color: KaripaPalette.ivory)),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              header: true,
              child: Text('Make your next move.',
                  style: type.headlineMedium
                      ?.copyWith(color: KaripaPalette.white)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Walk, jog, run, or cycle.',
                style: type.bodyMedium?.copyWith(color: KaripaPalette.ivory)),
            const SizedBox(height: AppSpacing.lg),
            KaripaButton(
                label: 'Start activity',
                icon: Icons.arrow_outward,
                onPressed: onStart),
          ],
        ),
      ),
    );
  }
}

class _HomeStats extends StatelessWidget {
  const _HomeStats({
    required this.distance,
    required this.activityCount,
    required this.activeTime,
    required this.calories,
    required this.distanceUnit,
  });

  final String distance;
  final String activityCount;
  final String activeTime;
  final String calories;
  final String distanceUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle =
        theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant);
    final caloriesAvailable = calories != 'Unavailable';

    return DecoratedBox(
      decoration: _homePanel(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              final metrics = [
                _HomeMetric(
                  label: 'Distance',
                  value: distance,
                  unit: distanceUnit,
                  style: theme.textTheme.displaySmall,
                ),
                _HomeMetric(
                    label: 'Activities',
                    value: activityCount,
                    style: theme.textTheme.titleMedium),
                _HomeMetric(
                    label: 'Active time',
                    value: activeTime,
                    style: theme.textTheme.titleMedium),
              ];
              if (constraints.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18) {
                return Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.md,
                  children: metrics,
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: metrics[0]),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 3, child: metrics[1]),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 3, child: metrics[2]),
                ],
              );
            }),
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: _homeBoundary(scheme)),
            ExpansionTile(
              minTileHeight: AppSizes.touchTarget,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
              expandedAlignment: AlignmentDirectional.centerStart,
              shape: const Border(),
              collapsedShape: const Border(),
              expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                  ? AnimationStyle.noAnimation
                  : null,
              title: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.md,
                children: [
                  Text('Est. calories', style: labelStyle),
                  Text(
                    caloriesAvailable ? '$calories kcal' : '—',
                    semanticsLabel: caloriesAvailable
                        ? null
                        : 'Estimated calories unavailable',
                    style: theme.textTheme.labelLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
              children: [
                Text(
                    '${caloriesAvailable ? '' : 'No applicable estimates are available. '}'
                    'Only activities with an applicable MET estimate are included. Estimates are provisional and adviser review is pending.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMetric extends StatelessWidget {
  const _HomeMetric(
      {required this.label,
      required this.value,
      required this.style,
      this.unit});

  final String label;
  final String value;
  final String? unit;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(text: value, children: [
            if (unit != null) TextSpan(text: ' $unit', style: labelStyle),
          ]),
          style: style
              ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

class _HomeEmptyHistory extends StatelessWidget {
  const _HomeEmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your first activity starts here.',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text('Completed activities will appear here.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _destinations = [
    ('Home', Icons.dashboard_outlined, Icons.dashboard),
    ('Leaderboard', Icons.leaderboard_outlined, Icons.leaderboard),
    ('History', Icons.history_outlined, Icons.history),
    ('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      fontSize: 12,
      letterSpacing: 0,
    );
    return Material(
      color: scheme.surface,
      shape: Border(top: BorderSide(color: _homeBoundary(scheme))),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widestLabel = TextPainter(
              text: TextSpan(text: _destinations[1].$1, style: labelStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final useTwoRows =
                widestLabel.width + AppSpacing.sm > constraints.maxWidth / 4;
            widestLabel.dispose();
            if (useTwoRows) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row(context, labelStyle, 0, 2),
                  _row(context, labelStyle, 2, 4),
                ],
              );
            }
            return _row(context, labelStyle, 0, _destinations.length);
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, TextStyle style, int start, int end) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = start; index < end; index++)
            Expanded(child: _destination(context, index, style)),
        ],
      ),
    );
  }

  Widget _destination(BuildContext context, int index, TextStyle style) {
    final (label, icon, selectedIcon) = _destinations[index];
    final selected = index == currentIndex;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => onTap(index),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: selected
                      ? ShapeDecoration(
                          color: scheme.primary, shape: const StadiumBorder())
                      : null,
                  child: Icon(selected ? selectedIcon : icon,
                      size: AppSizes.compactIcon,
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(label,
                    textAlign: TextAlign.center,
                    style: style.copyWith(
                      color:
                          selected ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : null,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _homeBoundary(ColorScheme scheme) =>
    Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.16), scheme.surface);

BoxDecoration _homePanel(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return BoxDecoration(
    color: theme.brightness == Brightness.light
        ? scheme.surface
        : scheme.surfaceContainer,
    border: Border.all(color: _homeBoundary(scheme)),
    borderRadius: BorderRadius.circular(AppRadii.panel),
  );
}

/// Formatted values and the original navigation closure come from HomeScreen.
class HomeRecentActivityCard extends StatelessWidget {
  final String activity;
  final IconData icon;
  final String date;
  final String distance;
  final String duration;
  final String calories;
  final VoidCallback onTap;

  const HomeRecentActivityCard(
      {super.key,
      required this.activity,
      required this.icon,
      required this.date,
      required this.distance,
      required this.duration,
      required this.calories,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = context.watch<UnitPreferences>();
    final panel = _homePanel(context);
    final activityName = activity.isEmpty
        ? 'Activity'
        : activity[0].toUpperCase() + activity.substring(1).toLowerCase();
    final calorieText = calories == 'Unavailable'
        ? 'Calorie estimate unavailable'
        : 'Est. $calories kcal';
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final metric = theme.textTheme.labelLarge
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return Semantics(
      button: true,
      label:
          '$activityName, $date, $distance ${units.distanceUnit}, duration $duration, $calorieText',
      child: Material(
        color: panel.color,
        shape: RoundedRectangleBorder(
            borderRadius: panel.borderRadius!, side: panel.border!.top),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.panel),
          onTap: onTap,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon, color: scheme.onSurface),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(activityName,
                                style: theme.textTheme.titleSmall),
                            Text(date, style: muted),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.xs,
                          children: [
                            Text('$distance ${units.distanceUnit}',
                                style: metric),
                            Text(duration, style: metric),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(calorieText, style: muted),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
