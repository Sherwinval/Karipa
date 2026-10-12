import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'karipa_button.dart';
import 'karipa_feedback.dart';
import 'metric_tile.dart';
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
    final lightMode = theme.brightness == Brightness.light;
    // Scope softer card edges to Home, including shared metric/feedback cards.
    final homeTheme = lightMode
        ? theme.copyWith(
            colorScheme: scheme.copyWith(outlineVariant: KaripaPalette.stone),
            cardTheme: theme.cardTheme.copyWith(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
                side: const BorderSide(color: KaripaPalette.stone),
              ),
            ),
          )
        : theme;
    final textScaler = MediaQuery.textScalerOf(context);
    // BottomNavigationBar clamps its internal label scaling. Supplying already
    // scaled font sizes preserves the user's setting without changing its tabs.
    final navigationLabel = theme.textTheme.labelMedium!.copyWith(
      fontSize: textScaler.scale(theme.textTheme.labelMedium!.fontSize!),
    );

    return Theme(
      data: homeTheme,
      child: Scaffold(
        backgroundColor:
            lightMode ? KaripaPalette.homeBackground : scheme.surface,
        appBar: AppBar(
          backgroundColor: KaripaPalette.navy,
          foregroundColor: KaripaPalette.white,
          title: const KaripaLogo(
              width: 180, horizontal: true, blendBackground: true),
          toolbarHeight: 88,
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: IconButton(
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
                    margin, AppSpacing.lg, margin, AppSpacing.xxl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: AppSizes.contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: KaripaPalette.navy,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Hello, $userName',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: KaripaPalette.ivory)),
                              const SizedBox(height: AppSpacing.lg),
                              Semantics(
                                header: true,
                                child: Text('Make your\nnext move.',
                                    style: theme.textTheme.displayMedium
                                        ?.copyWith(color: KaripaPalette.white)),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text('Walk. Jog. Run. Cycle.',
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(color: KaripaPalette.ivory)),
                              const SizedBox(height: AppSpacing.xl),
                              KaripaButton(
                                  label: 'Start activity',
                                  icon: Icons.arrow_outward,
                                  onPressed: onStartActivity),
                              const SizedBox(height: AppSpacing.md),
                              Text('Choose an activity and plan your route.',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: KaripaPalette.ivory)),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        const SectionHeading(
                            title: 'Your activity',
                            subtitle: 'All-time totals'),
                        const SizedBox(height: AppSpacing.lg),
                        if (isLoading) ...[
                          const KaripaProgress(
                              label: 'Updating activity totals'),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        _HomeStats(
                            distance: distance,
                            activityCount: activityCount,
                            activeTime: activeTime,
                            calories: calories),
                        const SizedBox(height: AppSpacing.xxl),
                        LayoutBuilder(builder: (context, section) {
                          const heading =
                              SectionHeading(title: 'Recent activities');
                          final action = TextButton(
                              onPressed: onViewAll,
                              child: const Text('View all'));
                          if (section.maxWidth < 360 ||
                              textScaler.scale(14) > 21) {
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  heading,
                                  action,
                                ]);
                          }
                          return Row(children: [
                            const Expanded(child: heading),
                            const SizedBox(width: AppSpacing.sm),
                            action
                          ]);
                        }),
                        const SizedBox(height: AppSpacing.md),
                        if (isLoading)
                          const KaripaProgress(
                              label: 'Loading recent activities')
                        else if (recentActivities.isEmpty)
                          const KaripaFeedback(
                            title: 'Your first move awaits',
                            message:
                                'No activities recorded yet. Start an activity to plan a route and track your movement.',
                            kind: FeedbackKind.empty,
                          )
                        else
                          ...recentActivities.expand((activity) => [
                                activity,
                                const SizedBox(height: AppSpacing.md)
                              ]),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
              border:
                  Border(top: BorderSide(color: scheme.surfaceContainerLow))),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onNavigationTapped,
            selectedLabelStyle:
                navigationLabel.copyWith(fontWeight: FontWeight.w800),
            unselectedLabelStyle: navigationLabel,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history),
                  label: 'History'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeStats extends StatelessWidget {
  final String distance;
  final String activityCount;
  final String activeTime;
  final String calories;

  const _HomeStats(
      {required this.distance,
      required this.activityCount,
      required this.activeTime,
      required this.calories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
          textTheme: theme.textTheme
              .copyWith(headlineSmall: theme.textTheme.displaySmall)),
      child: LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
        final width = largeText
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              SizedBox(
                  width: width,
                  child: MetricTile(
                      label: 'Distance',
                      value: distance,
                      unit: 'km',
                      icon: Icons.route_outlined)),
              SizedBox(
                  width: width,
                  child: MetricTile(
                      label: 'Activities',
                      icon: Icons.bolt_outlined,
                      value: activityCount,
                      unit: 'total')),
              SizedBox(
                  width: width,
                  child: MetricTile(
                      label: 'Active time',
                      value: activeTime,
                      unit: 'total',
                      icon: Icons.schedule_outlined)),
              SizedBox(
                  width: width,
                  child: MetricTile(
                      label: 'Est. calories',
                      value: calories,
                      unit: 'kcal',
                      icon: Icons.local_fire_department_outlined)),
            ]);
      }),
    );
  }
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
    return Semantics(
      button: true,
      label:
          '$activity, $date, $distance kilometers, duration $duration, estimated calories $calories kilocalories',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(icon, color: scheme.onSurface),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(activity, style: theme.textTheme.labelLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text(date,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ])),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.arrow_forward),
                  ]),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('$distance km',
                            style: theme.textTheme.headlineSmall?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                        Text(duration, style: theme.textTheme.titleMedium),
                      ]),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Est. $calories kcal',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
