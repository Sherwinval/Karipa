import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../widgets/status_badge.dart';
import '../widgets/metric_tile.dart';
import '../widgets/route_map_widget.dart';

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
    final userLatLng = currentLocation != null
        ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
        : null;

    final roadTypes =
        (route.features['roadTypes'] as List?)?.cast<String>() ?? [];
    final elevationGain = route.features['elevationGainM'] ?? 20;

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
            // Interactive Map Header
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: RouteMapWidget(
                    routePoints: route.coordinates,
                    currentLocation: userLatLng,
                    interactive: true,
                    initialZoom: 14.2,
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
                          text: '${route.score.toStringAsFixed(0)}% Match',
                          color: Theme.of(context).colorScheme.onSurface,
                          icon: Icons.auto_awesome,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Suitability & Reasoning
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'AI Recommendation: ${route.reasoning}',
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
                            label: 'Distance',
                            value: route.distanceKm.toStringAsFixed(2),
                            unit: 'km',
                            icon: Icons.straighten,
                            color: KaripaPalette.coral,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MetricTile(
                            label: 'Est. Time',
                            value: route.formattedDuration,
                            icon: Icons.timer_outlined,
                            color: KaripaPalette.coral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: MetricTile(
                            label: 'Elevation Gain',
                            value: '+$elevationGain',
                            unit: 'm',
                            icon: Icons.terrain,
                            color: KaripaPalette.coral,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MetricTile(
                            label: 'Type',
                            value: route.features['isLoop'] == true
                                ? 'Loop'
                                : 'Out & Back',
                            icon: Icons.alt_route,
                            color: KaripaPalette.coral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Roads Analyzed
                    if (roadTypes.isNotEmpty) ...[
                      Text(
                        'Road Characteristics Analyzed:',
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
