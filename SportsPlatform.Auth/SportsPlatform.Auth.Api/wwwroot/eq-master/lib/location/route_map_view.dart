import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'location_point.dart';
import 'location_service.dart';
import 'route_service.dart';

/// Full-screen road-route map from the viewer's current location to a venue.
/// Falls back to a venue-only pin when GPS or routing is unavailable.
class RouteMapView extends StatefulWidget {
  final LocationPoint destination;

  const RouteMapView({super.key, required this.destination});

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();

  bool _loading = true;
  LatLng? _origin;
  RouteResult? _route;
  String? _notice; // non-fatal message shown over the venue-only fallback

  LatLng get _destination =>
      LatLng(widget.destination.latitude, widget.destination.longitude);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _routeService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    LatLng? origin;
    try {
      final current = await _locationService.getCurrentLocation();
      origin = LatLng(current.latitude, current.longitude);
    } catch (e) {
      _notice = 'Showing the venue only — $e';
    }

    RouteResult? route;
    if (origin != null) {
      try {
        route = await _routeService.getDrivingRoute(origin, _destination);
      } catch (_) {
        _notice = 'Could not load a road route. Showing the venue location.';
      }
    }

    if (!mounted) return;
    setState(() {
      _origin = origin;
      _route = route;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = widget.destination.label?.trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        title: Text(
          label == null || label.isEmpty ? 'Route to venue' : label,
          style: const TextStyle(
            fontFamily: 'SFPro',
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E3A)),
            )
          : Stack(
              children: [
                _buildMap(),
                if (_route != null) _buildRouteBanner(isDark),
                if (_route == null && _notice != null) _buildNoticeBanner(),
              ],
            ),
    );
  }

  Widget _buildMap() {
    final route = _route;
    final markers = <Marker>[
      Marker(
        point: _destination,
        width: 48,
        height: 48,
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 42,
          shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
        ),
      ),
      if (_origin != null)
        Marker(
          point: _origin!,
          width: 26,
          height: 26,
          child: const _CurrentLocationDot(),
        ),
    ];

    final CameraFit fit = route != null
        ? CameraFit.coordinates(
            coordinates: route.points,
            padding: const EdgeInsets.all(60),
          )
        : CameraFit.coordinates(
            coordinates: [_destination],
            padding: const EdgeInsets.all(60),
            maxZoom: 15,
          );

    return FlutterMap(
      options: MapOptions(
        initialCenter: _destination,
        initialZoom: 14,
        initialCameraFit: fit,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.eqq',
        ),
        if (route != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.points,
                strokeWidth: 5,
                color: const Color(0xFF1B5E3A),
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildRouteBanner(bool isDark) {
    final route = _route!;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Material(
        color: isDark ? const Color(0xFF1B3A2D) : Colors.white,
        elevation: 8,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: Color(0xFF1B5E3A)),
              const SizedBox(width: 12),
              Text(
                route.durationLabel,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'SFPro',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${route.distanceLabel})',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontFamily: 'SFPro',
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                'via roads',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontFamily: 'SFPro',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Material(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _notice ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'SFPro',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
      ),
    );
  }
}
