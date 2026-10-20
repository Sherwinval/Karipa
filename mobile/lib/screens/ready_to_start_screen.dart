import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/design_tokens.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_model.dart';
import '../services/unit_preferences.dart';

class ReadyToStartScreen extends StatelessWidget {
  final PathRoute route;
  final String activity;
  final Position? currentLocation;

  const ReadyToStartScreen({
    super.key,
    required this.route,
    required this.activity,
    this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitPreferences>();
    return Scaffold(
      backgroundColor:
          Theme.of(context).colorScheme.surface, // Premium dark layout
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Text(
          'Ready to Start',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Circular activity hero
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [KaripaPalette.coral, KaripaPalette.coral],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: KaripaPalette.midnight.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    activity.toLowerCase() == 'cycling'
                        ? Icons.directions_bike
                        : Icons.directions_run,
                    size: 54,
                    color: KaripaPalette.midnight,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Center(
                child: Text(
                  activity.toUpperCase(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  route.name,
                  style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 36),

              // Summary Stats Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'DISTANCE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          units.formatDistance(route.distanceKm),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                    Container(
                        height: 36,
                        width: 1,
                        color: Theme.of(context).colorScheme.outline),
                    Column(
                      children: [
                        Text(
                          'EST. DURATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          route.formattedDuration,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // GPS Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: KaripaPalette.midnight.withOpacity(0.6),
                              blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'GPS Signal Acquired • High Accuracy Ready',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Start Activity Action
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/active_tracking',
                    arguments: {
                      'route': route,
                      'activity': activity,
                      'initialPosition': currentLocation,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: KaripaPalette.coral,
                  foregroundColor: KaripaPalette.midnight,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: KaripaPalette.midnight.withOpacity(0.4),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'START ACTIVITY',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
