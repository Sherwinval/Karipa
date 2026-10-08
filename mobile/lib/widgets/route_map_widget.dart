import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteMapWidget extends StatefulWidget {
  final List<LatLng> routePoints;
  final List<LatLng>? trackedPoints;
  final LatLng? currentLocation;
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

  LatLng get _initialCenter {
    if (widget.currentLocation != null) return widget.currentLocation!;
    if (widget.routePoints.isNotEmpty) return widget.routePoints.first;
    // Manila default
    return const LatLng(14.5995, 120.9842);
  }

  @override
  void didUpdateWidget(covariant RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLocation != null &&
        (oldWidget.currentLocation == null ||
         oldWidget.currentLocation != widget.currentLocation)) {
      try {
        _mapController.move(widget.currentLocation!, _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // Start marker (green)
    if (widget.routePoints.isNotEmpty) {
      markers.add(
        Marker(
          point: widget.routePoints.first,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    // End marker (flag)
    if (widget.routePoints.length > 1) {
      final lastPoint = widget.routePoints.last;
      markers.add(
        Marker(
          point: lastPoint,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.flag, color: Colors.white, size: 16),
          ),
        ),
      );
    }

    // Current location marker (blue GPS pin)
    if (widget.currentLocation != null) {
      markers.add(
        Marker(
          point: widget.currentLocation!,
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final polylines = <Polyline>[];

    // Planned candidate route line (Teal)
    if (widget.routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: widget.routePoints,
          strokeWidth: 4.5,
          color: Colors.teal.shade700,
        ),
      );
    }

    // Completed user tracked GPS path (Orange vibrant line)
    if (widget.trackedPoints != null && widget.trackedPoints!.isNotEmpty) {
      polylines.add(
        Polyline(
          points: widget.trackedPoints!,
          strokeWidth: 5.5,
          color: Colors.deepOrange.shade600,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: widget.initialZoom,
              interactionOptions: InteractionOptions(
                flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pathcraft.mobile',
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),
          if (widget.interactive && widget.currentLocation != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'recenter_map',
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal,
                onPressed: () {
                  _mapController.move(widget.currentLocation!, 16.0);
                },
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }
}
