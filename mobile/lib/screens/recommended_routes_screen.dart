import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../widgets/status_badge.dart';
import '../widgets/route_map_widget.dart';

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
    final userLatLng = currentLocation != null
        ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Recommended Routes',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Header summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.explore,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${activity.toUpperCase()} • ${targetDistanceKm.toStringAsFixed(1)} KM TARGET',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${routes.length} Candidate Routes Ranked by AI',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            ...routes
                .map((route) => _buildRouteCard(context, route, userLatLng)),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(
      BuildContext context, PathRoute route, LatLng? userLocation) {
    final isTop = route.isTopRecommendation;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTop
              ? Theme.of(context).colorScheme.outline
              : Theme.of(context).colorScheme.outline,
          width: isTop ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isTop
                ? KaripaPalette.midnight.withOpacity(0.12)
                : KaripaPalette.midnight.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Badges bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(
                  text: route.matchLabel,
                  color: Theme.of(context).colorScheme.onSurface,
                  icon: isTop ? Icons.star : Icons.thumb_up_alt_outlined,
                ),
                StatusBadge(
                  text: route.suitability,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${route.score.toStringAsFixed(0)}% MATCH',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Route Name & Metrics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.name,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMetricChip(context, Icons.straighten,
                        '${route.distanceKm.toStringAsFixed(2)} km'),
                    const SizedBox(width: 12),
                    _buildMetricChip(
                        context, Icons.timer_outlined, route.formattedDuration),
                    if (route.features['isLoop'] == true) ...[
                      const SizedBox(width: 12),
                      _buildMetricChip(context, Icons.loop, 'Loop Circuit'),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  route.reasoning,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Real Map Preview snippet
          if (route.coordinates.isNotEmpty)
            Container(
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: RouteMapWidget(
                  routePoints: route.coordinates,
                  currentLocation: userLocation,
                  interactive: false,
                  initialZoom: 13.8,
                ),
              ),
            ),

          // View Details Action
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
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
              style: ElevatedButton.styleFrom(
                backgroundColor: isTop
                    ? KaripaPalette.coral
                    : Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: isTop
                    ? KaripaPalette.midnight
                    : Theme.of(context).colorScheme.onSurface,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('View Route Details',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
