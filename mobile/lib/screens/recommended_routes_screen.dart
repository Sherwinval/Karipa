import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/route_model.dart';
import '../services/unit_preferences.dart';
import '../theme/design_tokens.dart';
import '../widgets/karipa_button.dart';
import '../widgets/route_map_widget.dart';
import 'route_presentation.dart';

class RecommendedRoutesScreen extends StatelessWidget {
  final List<PathRoute> routes;
  final String activity;
  final double targetDistanceKm;
  final Position? currentLocation;

  const RecommendedRoutesScreen({
    super.key,
    required this.routes,
    required this.activity,
    required this.targetDistanceKm,
    this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitPreferences>();
    return Scaffold(
      appBar: routeAppBar(context, 'Recommended Routes'),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = routePageInset(constraints.maxWidth);
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  inset, AppSpacing.md, inset, AppSpacing.xl),
              itemCount: routes.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _RouteSummary(
                    activity: activity,
                    target: units.formatDistance(targetDistanceKm, decimals: 1),
                    count: routes.length,
                    firstRoute: routes.firstOrNull,
                    units: units,
                  );
                }
                final route = routes[index - 1];
                return Padding(
                  key: ValueKey(route.id),
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _RouteCard(
                    route: route,
                    units: units,
                    targetDistanceKm: targetDistanceKm,
                    onView: () {
                      Navigator.pushNamed(
                        context,
                        '/route_details',
                        arguments: {
                          'route': route,
                          'activity': activity,
                          'currentLocation': currentLocation,
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.activity,
    required this.target,
    required this.count,
    required this.firstRoute,
    required this.units,
  });

  final String activity;
  final String target;
  final int count;
  final PathRoute? firstRoute;
  final UnitPreferences units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final threshold = firstRoute?.maximumDistanceDeviationKm;
    final closeCandidateAvailable = firstRoute?.closeCandidateAvailable;
    final outsideTolerance =
        threshold != null && closeCandidateAvailable == false;
    final preferenceNotice = firstRoute?.preferenceNotice?.trim();
    final warnings = [
      if (outsideTolerance)
        'No route is within ${units.formatDistance(threshold)} of the target.',
      if (preferenceNotice != null && preferenceNotice.isNotEmpty)
        preferenceNotice,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${routeActivityLabel(activity)} · $target target',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            count == 1 ? '1 route available' : '$count routes available',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.sm,
                  children: [
                    for (final warning in warnings)
                      Text(warning, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          if (firstRoute != null)
            ExpansionTile(
              key: const PageStorageKey('route-ranking-disclosure'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: colors.onSurfaceVariant,
              collapsedIconColor: colors.onSurfaceVariant,
              title: Text('How routes are ranked',
                  style: theme.textTheme.labelLarge),
              children: [
                Text(
                  firstRoute?.rankingSource == 'ai_assisted'
                      ? 'AI explanations and preference signals can break ties between routes within 0.05 km of the closest match.'
                      : 'Deterministic ranking was used. Route validity and actual distance take priority.',
                  style: theme.textTheme.bodySmall,
                ),
                if (!outsideTolerance) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    threshold == null
                        ? 'No distance tolerance was provided by the route service.'
                        : closeCandidateAvailable == true
                            ? 'Only routes within ${units.formatDistance(threshold)} of the target are shown.'
                            : 'Distance tolerance was ${units.formatDistance(threshold)}.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.units,
    required this.targetDistanceKm,
    required this.onView,
  });

  final PathRoute route;
  final UnitPreferences units;
  final double targetDistanceKm;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final supportingText =
        theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
    final distance = units.formatDistance(route.distanceKm);
    final time = route.durationSeconds > 0
        ? 'Est. ${route.formattedDuration}'
        : 'Time estimate unavailable';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border:
            Border.all(color: colors.outlineVariant.withValues(alpha: 0.36)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (route.coordinates.isNotEmpty)
              Semantics(
                image: true,
                label: 'Route map preview',
                child: SizedBox(
                  height: 152,
                  child: RouteMapWidget(
                    routePoints: route.coordinates,
                    interactive: false,
                    initialZoom: 13.8,
                  ),
                ),
              )
            else
              Text('Map preview unavailable', style: supportingText),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(routeDisplayName(route),
                  style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('$distance · $time', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              routeTargetComparison(route, units,
                  requestedTargetKm: targetDistanceKm),
              style: supportingText,
            ),
            if (route.isTopRecommendation) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                route.rankingSource == 'ai_assisted'
                    ? 'AI-assisted recommendation'
                    : 'Recommended',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            KaripaButton.secondary(label: 'View route', onPressed: onView),
          ],
        ),
      ),
    );
  }
}
