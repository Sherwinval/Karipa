import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
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
  google_maps.GoogleMapController? _mapController;

  geo.LatLng get _initialCenter {
    if (widget.currentLocation != null) return widget.currentLocation!;
    if (widget.routePoints.isNotEmpty) return widget.routePoints.first;
    return const geo.LatLng(14.5995, 120.9842);
  }

  google_maps.LatLng _toGoogleLocation(geo.LatLng point) =>
      google_maps.LatLng(point.latitude, point.longitude);

  Future<void> _fitRoute() async {
    final controller = _mapController;
    if (controller == null || widget.routePoints.length < 2) return;

    final latitudes = widget.routePoints.map((point) => point.latitude);
    final longitudes = widget.routePoints.map((point) => point.longitude);
    final bounds = google_maps.LatLngBounds(
      southwest: google_maps.LatLng(
        latitudes.reduce((a, b) => a < b ? a : b),
        longitudes.reduce((a, b) => a < b ? a : b),
      ),
      northeast: google_maps.LatLng(
        latitudes.reduce((a, b) => a > b ? a : b),
        longitudes.reduce((a, b) => a > b ? a : b),
      ),
    );
    await controller.animateCamera(
      google_maps.CameraUpdate.newLatLngBounds(bounds, 48),
    );
  }

  @override
  void didUpdateWidget(covariant RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLocation != null &&
        oldWidget.currentLocation != widget.currentLocation) {
      _mapController?.animateCamera(
        google_maps.CameraUpdate.newLatLng(
          _toGoogleLocation(widget.currentLocation!),
        ),
      );
    } else if (oldWidget.routePoints != widget.routePoints) {
      _fitRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = KaripaColors.of(context);
    final markers = <google_maps.Marker>{};
    if (widget.routePoints.isNotEmpty) {
      markers.add(google_maps.Marker(
        markerId: const google_maps.MarkerId('route-start'),
        position: _toGoogleLocation(widget.routePoints.first),
        infoWindow: const google_maps.InfoWindow(title: 'Route start'),
        icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
          google_maps.BitmapDescriptor.hueGreen,
        ),
      ));
    }
    if (widget.routePoints.length > 1) {
      markers.add(google_maps.Marker(
        markerId: const google_maps.MarkerId('route-finish'),
        position: _toGoogleLocation(widget.routePoints.last),
        infoWindow: const google_maps.InfoWindow(title: 'Route finish'),
        icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
          google_maps.BitmapDescriptor.hueRed,
        ),
      ));
    }
    if (widget.currentLocation != null) {
      markers.add(google_maps.Marker(
        markerId: const google_maps.MarkerId('current-location'),
        position: _toGoogleLocation(widget.currentLocation!),
        infoWindow: const google_maps.InfoWindow(title: 'Current location'),
        icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
          google_maps.BitmapDescriptor.hueAzure,
        ),
      ));
    }

    final polylines = <google_maps.Polyline>{};
    if (widget.routePoints.length > 1) {
      polylines.add(google_maps.Polyline(
        polylineId: const google_maps.PolylineId('planned-route'),
        points: widget.routePoints.map(_toGoogleLocation).toList(),
        color: colors.routeHighlight,
        width: 5,
      ));
    }
    if (widget.trackedPoints != null && widget.trackedPoints!.length > 1) {
      polylines.add(google_maps.Polyline(
        polylineId: const google_maps.PolylineId('recorded-gps-track'),
        points: widget.trackedPoints!.map(_toGoogleLocation).toList(),
        color: colors.recordedTrack,
        width: 6,
      ));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: Stack(
        children: [
          google_maps.GoogleMap(
            initialCameraPosition: google_maps.CameraPosition(
              target: _toGoogleLocation(_initialCenter),
              zoom: widget.initialZoom,
            ),
            markers: markers,
            polylines: polylines,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: widget.interactive,
            scrollGesturesEnabled: widget.interactive,
            zoomGesturesEnabled: widget.interactive,
            rotateGesturesEnabled: widget.interactive,
            tiltGesturesEnabled: widget.interactive,
            onMapCreated: (controller) {
              _mapController = controller;
              _fitRoute();
            },
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
                onPressed: () => _mapController?.animateCamera(
                  google_maps.CameraUpdate.newCameraPosition(
                    google_maps.CameraPosition(
                      target: _toGoogleLocation(widget.currentLocation!),
                      zoom: 16,
                    ),
                  ),
                ),
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }
}
