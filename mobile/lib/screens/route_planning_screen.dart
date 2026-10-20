import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/design_tokens.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/unit_preferences.dart';

class RoutePlanningScreen extends StatefulWidget {
  final String activity;

  const RoutePlanningScreen({super.key, required this.activity});

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  final _distanceFormKey = GlobalKey<FormState>();
  double _targetDistanceKm = 5.0;
  final TextEditingController _customDistanceController =
      TextEditingController();
  bool _isCustomDistance = false;

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

  @override
  void dispose() {
    _customDistanceController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateRoutes() async {
    if (_isCustomDistance && !_distanceFormKey.currentState!.validate()) {
      return;
    }
    final displayedDistance = _isCustomDistance
        ? double.tryParse(_customDistanceController.text.trim())
        : _targetDistanceKm;
    if (displayedDistance == null ||
        !displayedDistance.isFinite ||
        displayedDistance <= 0) {
      setState(() => _errorMessage =
          'Enter a positive target distance in ${context.read<UnitPreferences>().distanceUnit}.');
      return;
    }
    final distance = _isCustomDistance
        ? context.read<UnitPreferences>().distanceToKm(displayedDistance)
        : displayedDistance;

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
    final units = context.watch<UnitPreferences>();
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
                        Text(
                          'Target Distance (${units.distanceUnit})',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildPresetChip(3.0,
                            '${units.distanceFromKm(3).toStringAsFixed(1)} ${units.distanceUnit}'),
                        const SizedBox(width: 10),
                        _buildPresetChip(5.0,
                            '${units.distanceFromKm(5).toStringAsFixed(1)} ${units.distanceUnit}'),
                        const SizedBox(width: 10),
                        _buildPresetChip(10.0,
                            '${units.distanceFromKm(10).toStringAsFixed(1)} ${units.distanceUnit}'),
                        const SizedBox(width: 10),
                        _buildCustomChip(),
                      ],
                    ),
                    if (_isCustomDistance) ...[
                      const SizedBox(height: 16),
                      Form(
                        key: _distanceFormKey,
                        child: TextFormField(
                          controller: _customDistanceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Custom target distance',
                            suffixText: units.distanceUnit,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            final number = double.tryParse(value?.trim() ?? '');
                            if (number == null || !number.isFinite) {
                              return 'Enter a valid distance in ${units.distanceUnit}.';
                            }
                            if (number <= 0) {
                              return 'Distance must be greater than zero ${units.distanceUnit}.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Routes are ranked by actual network distance. A maximum distance deviation is not assumed unless the project configures one.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                          Text(
                            'Route Preferences',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface),
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
              const SizedBox(height: 24),

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
                          Text('Generating & Ranking Routes...',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Generate Routes',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
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

  Widget _buildPresetChip(double distance, String label) {
    final isSelected = !_isCustomDistance && _targetDistanceKm == distance;
    return Expanded(
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: KaripaPalette.coral,
        labelStyle: const TextStyle(
          color: KaripaPalette.midnight,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (val) {
          if (val) {
            setState(() {
              _isCustomDistance = false;
              _targetDistanceKm = distance;
            });
          }
        },
      ),
    );
  }

  Widget _buildCustomChip() {
    return Expanded(
      child: ChoiceChip(
        label: const Text('Custom'),
        selected: _isCustomDistance,
        selectedColor: KaripaPalette.coral,
        labelStyle: const TextStyle(
          color: KaripaPalette.midnight,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (val) {
          setState(() {
            _isCustomDistance = true;
          });
        },
      ),
    );
  }
}
