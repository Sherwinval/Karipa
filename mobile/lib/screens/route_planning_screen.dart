import 'package:flutter/material.dart';
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
  static const _targetDistanceStepKm = 0.5;

  double _targetDistanceKm = _minimumTargetDistanceKm;

  bool _avoidMajorRoads = true;
  bool _preferSidewalks = true;
  bool _preferLoop = true;
  late bool _preferCyclingLanes;

  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _preferCyclingLanes = widget.activity.toLowerCase() == 'cycling';
  }

  Future<void> _handleGenerateRoutes() async {
    final distance = _targetDistanceKm;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                    Text(
                      '${_targetDistanceKm.toStringAsFixed(1)} km',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: KaripaPalette.coral,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: KaripaPalette.coral,
                        inactiveTrackColor: colorScheme.outlineVariant,
                        thumbColor: KaripaPalette.coral,
                        overlayColor:
                            KaripaPalette.coral.withValues(alpha: 0.16),
                        valueIndicatorColor: KaripaPalette.coral,
                        valueIndicatorTextStyle: const TextStyle(
                          color: KaripaPalette.midnight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Slider(
                        value: _targetDistanceKm,
                        min: _minimumTargetDistanceKm,
                        max: _maximumTargetDistanceKm,
                        divisions: ((_maximumTargetDistanceKm -
                                    _minimumTargetDistanceKm) /
                                _targetDistanceStepKm)
                            .round(),
                        label: '${_targetDistanceKm.toStringAsFixed(1)} km',
                        semanticFormatterCallback: (value) =>
                            '${value.toStringAsFixed(1)} km',
                        onChanged: (value) =>
                            setState(() => _targetDistanceKm = value),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '3 km',
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12),
                        ),
                        Text(
                          '30 km',
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12),
                        ),
                      ],
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
                        onChanged: (v) => setState(() => _preferLoop = v),
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
                        onChanged: (v) => setState(() => _avoidMajorRoads = v),
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
                        onChanged: (v) => setState(() => _preferSidewalks = v),
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
                          onChanged: (v) =>
                              setState(() => _preferCyclingLanes = v),
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
                onPressed: _isGenerating ? null : _handleGenerateRoutes,
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
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: KaripaPalette.midnight, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text('Generating & Ranking Routes...',
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
