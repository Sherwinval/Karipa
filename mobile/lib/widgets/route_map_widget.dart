import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

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
        _mapController.move(
            widget.currentLocation!, _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = PathCraftColors.of(context);
    final markers = <Marker>[];

    // Start/end remain distinct by symbol as well as fill.
    if (widget.routePoints.isNotEmpty) {
      markers.add(
        Marker(
          point: widget.routePoints.first,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: colors.routeHighlight,
              shape: BoxShape.circle,
              border: Border.all(color: colors.routeCasing, width: 2.5),
            ),
            child: Icon(Icons.play_arrow,
                color: colors.routeCasing,
                size: 18,
                semanticLabel: 'Route start'),
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
              color: colors.recordedTrack,
              shape: BoxShape.circle,
              border: Border.all(color: colors.recordedTrackCasing, width: 2.5),
            ),
            child: Icon(Icons.flag,
                color: colors.recordedTrackCasing,
                size: 16,
                semanticLabel: 'Route finish'),
          ),
        ),
      );
    }

    // Current position retains the existing concentric-dot geometry.
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
                  color: colors.routeCasing,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: colors.routeHighlight,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: colors.recordedTrackCasing, width: 2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final polylines = <Polyline>[];

    // Coral route with contrasting casing; tile imagery is unchanged.
    if (widget.routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: widget.routePoints,
          strokeWidth: 4.5,
          color: colors.routeHighlight,
          borderColor: colors.routeCasing,
          borderStrokeWidth: 2,
        ),
      );
    }

    // Recorded track has an independent neutral treatment.
    if (widget.trackedPoints != null && widget.trackedPoints!.isNotEmpty) {
      polylines.add(
        Polyline(
          points: widget.trackedPoints!,
          strokeWidth: 5.5,
          color: colors.recordedTrack,
          borderColor: colors.recordedTrackCasing,
          borderStrokeWidth: 2,
        ),
      );
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
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: FloatingActionButton.small(
                heroTag: 'recenter_map',
                backgroundColor: KaripaPalette.ivory,
                foregroundColor: KaripaPalette.midnight,
                tooltip: 'Recenter map',
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
