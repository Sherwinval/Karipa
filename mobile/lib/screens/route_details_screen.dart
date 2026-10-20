import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/design_tokens.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../widgets/status_badge.dart';
import '../widgets/metric_tile.dart';
import '../widgets/route_map_widget.dart';
import '../services/unit_preferences.dart';

class RouteDetailsScreen extends StatelessWidget {
  final PathRoute route;
  final String activity;
  final Position? currentLocation;

  const RouteDetailsScreen({
    super.key,
    required this.route,
    required this.activity,
    this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitPreferences>();
    final userLatLng = currentLocation != null
        ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
        : null;

    final roadTypes =
        (route.features['roadTypes'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(route.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Complete route preview
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: route.coordinates.length >= 2
                      ? RouteMapWidget(
                          routePoints: route.coordinates,
                          currentLocation: userLatLng,
                          interactive: true,
                          initialZoom: 14.2,
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(20),
                          child: const Text(
                            'A complete route preview is unavailable because the routing service did not provide route geometry.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),
            ),

            // Route Details & Metrics Panel
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title and Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          route.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        StatusBadge(
                          text: route.rankingSource == 'ai_assisted'
                              ? 'AI-assisted tie-break'
                              : 'Fallback ranking',
                          color: Theme.of(context).colorScheme.onSurface,
                          icon: Icons.straighten,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Ranking details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${route.rankingSource == 'ai_assisted' ? 'AI-assisted tie-break' : 'Deterministic fallback ranking'}: ${route.reasoning}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: MetricTile(
                            label: 'Actual distance',
                            value: units.distanceFromKm(route.distanceKm).toStringAsFixed(2),
                            unit: units.distanceUnit,
                            icon: Icons.straighten,
                            color: KaripaPalette.coral,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MetricTile(
                            label: 'Routing-service time estimate',
                            value: route.formattedDuration,
                            icon: Icons.timer_outlined,
                            color: KaripaPalette.coral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Requested target: ${units.formatDistance(route.targetDistanceKm)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Absolute deviation: ${units.formatDistance(route.absoluteDistanceDeviationKm)} • Percentage deviation: ${route.percentageDistanceDeviation.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (route.features['isLoop'] is bool) ...[
                      Text(
                        route.features['isLoop'] == true
                            ? 'Route shape: generated loop'
                            : 'Route shape: generated out-and-back',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (roadTypes.isNotEmpty) ...[
                      Text(
                        'Map labels available:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: roadTypes
                            .map((name) => Chip(
                                  label: Text(name,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                  side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Geographic data limitations: the routing response does not verify sidewalks, cycling infrastructure, elevation, or street lighting. Road labels are map data, not a safety assessment.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/ready_to_start',
                          arguments: {
                            'route': route,
                            'activity': activity,
                            'currentLocation': currentLocation,
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KaripaPalette.coral,
                        foregroundColor: KaripaPalette.midnight,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 1,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_run, size: 22),
                          SizedBox(width: 8),
                          Text('Select Route & Prepare',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
