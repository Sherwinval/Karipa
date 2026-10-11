import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';

class RoutePlanningScreen extends StatefulWidget {
  final String activity;

  const RoutePlanningScreen({super.key, required this.activity});

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  double _targetDistanceKm = 5.0;
  final TextEditingController _customDistanceController = TextEditingController();
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
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      // 1. Acquire real GPS Location
      final permissionStatus = await LocationService.checkAndRequestPermission();

      if (permissionStatus == LocationStatus.serviceDisabled) {
        throw Exception('Location services are turned off on your device. Please enable GPS in your device settings.');
      } else if (permissionStatus == LocationStatus.permissionDenied) {
        throw Exception('Location permission was denied. Karipa requires location to generate routes starting from your position.');
      } else if (permissionStatus == LocationStatus.permissionDeniedForever) {
        throw Exception('Location permissions are permanently denied. Please open App Settings to grant location access.');
      }

      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        throw Exception('Could not determine current GPS position. Please check your signal and try again.');
      }

      final distance = _isCustomDistance
          ? (double.tryParse(_customDistanceController.text) ?? 5.0)
          : _targetDistanceKm;

      if (distance <= 0.2 || distance > 100) {
        throw Exception('Please specify a valid distance between 0.5 km and 100 km.');
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
        throw Exception('No routes could be generated around this area. Try selecting a different distance.');
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten, color: Color(0xFF0D9488), size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Target Distance',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildPresetChip(3.0, '3 km'),
                        const SizedBox(width: 10),
                        _buildPresetChip(5.0, '5 km'),
                        const SizedBox(width: 10),
                        _buildPresetChip(10.0, '10 km'),
                        const SizedBox(width: 10),
                        _buildCustomChip(),
                      ],
                    ),
                    if (_isCustomDistance) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _customDistanceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Custom Distance in Kilometers',
                          suffixText: 'km',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune, color: Color(0xFF0D9488), size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Route Preferences',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF0D9488),
                      title: const Text('Prefer Circular Loop', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: const Text('Route starts and finishes at your current location', style: TextStyle(fontSize: 12)),
                      value: _preferLoop,
                      onChanged: (v) => setState(() => _preferLoop = v),
                    ),
                    const Divider(),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF0D9488),
                      title: const Text('Avoid Major Roads', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: const Text('Prioritizes quieter residential streets and paths', style: TextStyle(fontSize: 12)),
                      value: _avoidMajorRoads,
                      onChanged: (v) => setState(() => _avoidMajorRoads = v),
                    ),
                    const Divider(),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF0D9488),
                      title: const Text('Prioritize Sidewalks & Trails', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: const Text('Prefers pedestrian-designated paths and footways', style: TextStyle(fontSize: 12)),
                      value: _preferSidewalks,
                      onChanged: (v) => setState(() => _preferSidewalks = v),
                    ),

                    if (widget.activity.toLowerCase() == 'cycling') ...[
                      const Divider(),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF0D9488),
                        title: const Text('Cycling Infrastructure', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: const Text('Prioritize designated bicycle paths and wide lanes', style: TextStyle(fontSize: 12)),
                        value: _preferCyclingLanes,
                        onChanged: (v) => setState(() => _preferCyclingLanes = v),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              ElevatedButton(
                onPressed: _isGenerating ? null : _handleGenerateRoutes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                ),
                child: _isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Generating & Ranking Routes...', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Generate Routes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildPresetChip(double distance, String label) {
    final isSelected = !_isCustomDistance && _targetDistanceKm == distance;
    return Expanded(
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF0D9488),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF0F172A),
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
        selectedColor: const Color(0xFF0D9488),
        labelStyle: TextStyle(
          color: _isCustomDistance ? Colors.white : const Color(0xFF0F172A),
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
