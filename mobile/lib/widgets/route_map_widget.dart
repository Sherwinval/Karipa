import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as geo;
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class RouteMapWidget extends StatefulWidget {
  final List<geo.LatLng> routePoints;
  final List<geo.LatLng>? trackedPoints;
  final geo.LatLng? currentLocation;
  final bool interactive;
  final double initialZoom;

  const RouteMapWidget({
    super.key,
    required this.routePoints,
    this.trackedPoints,
    this.currentLocation,
    this.interactive = true,
    this.initialZoom = 14.5,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  geo.LatLng get _initialCenter {
    if (widget.routePoints.isNotEmpty) return widget.routePoints.first;
    if (widget.currentLocation != null) return widget.currentLocation!;
    return const geo.LatLng(14.5995, 120.9842);
  }

  void _fitRoute() {
    if (!_mapReady || widget.routePoints.length < 2) return;

    double minLat = widget.routePoints.first.latitude;
    double maxLat = widget.routePoints.first.latitude;
    double minLon = widget.routePoints.first.longitude;
    double maxLon = widget.routePoints.first.longitude;

    for (final point in widget.routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          geo.LatLng(minLat, minLon),
          geo.LatLng(maxLat, maxLon),
        ),
        padding: EdgeInsets.all(widget.interactive ? 48 : 16),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLocation != null &&
        oldWidget.currentLocation != widget.currentLocation) {
      _mapController.move(widget.currentLocation!, _mapController.camera.zoom);
    } else if (oldWidget.routePoints != widget.routePoints) {
      _fitRoute();
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (widget.routePoints.isNotEmpty) {
      markers.add(Marker(
        point: widget.routePoints.first,
        width: 28,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.trip_origin, color: Colors.white, size: 14),
        ),
      ));
    }
    if (widget.routePoints.length > 1) {
      markers.add(Marker(
        point: widget.routePoints.last,
        width: 28,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.flag, color: Colors.white, size: 14),
        ),
      ));
    }
    if (widget.currentLocation != null) {
      markers.add(Marker(
        point: widget.currentLocation!,
        width: 28,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 14),
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final colors = KaripaColors.of(context);

    final polylines = <Polyline>[];
    if (widget.routePoints.length > 1) {
      polylines.add(Polyline(
        points: widget.routePoints,
        color: colors.routeHighlight,
        strokeWidth: 6,
        borderColor: colors.routeCasing,
        borderStrokeWidth: 3,
      ));
    }
    if (widget.trackedPoints != null && widget.trackedPoints!.length > 1) {
      polylines.add(Polyline(
        points: widget.trackedPoints!,
        color: colors.recordedTrack,
        strokeWidth: 6,
        borderColor: colors.recordedTrackCasing,
        borderStrokeWidth: 2,
      ));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: widget.initialZoom,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
              onMapReady: () {
                _mapReady = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _fitRoute();
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.karipa.app',
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          if (widget.interactive && widget.currentLocation != null)
            Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: FloatingActionButton.small(
                heroTag: 'recenter_map',
                backgroundColor: KaripaPalette.ivory,
                foregroundColor: KaripaPalette.midnight,
                tooltip: 'Recenter map',
                onPressed: () => _mapController.move(
                  widget.currentLocation!,
                  16,
                ),
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }
}
