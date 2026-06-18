import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteServiceException implements Exception {
  final String message;
  const RouteServiceException(this.message);

  @override
  String toString() => message;
}

/// A road route between two points, returned by OSRM.
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get durationLabel {
    final totalMinutes = (durationSeconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }
}

/// Fetches driving directions from the public OSRM routing service.
class RouteService {
  static const String _host = 'router.project-osrm.org';

  final http.Client _client;

  RouteService({http.Client? client}) : _client = client ?? http.Client();

  Future<RouteResult> getDrivingRoute(LatLng origin, LatLng destination) async {
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.https(_host, '/route/v1/driving/$coords', {
      'overview': 'full',
      'geometries': 'geojson',
    });

    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw RouteServiceException(
        'Routing failed with status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map ||
        decoded['code'] != 'Ok' ||
        decoded['routes'] is! List ||
        (decoded['routes'] as List).isEmpty) {
      throw const RouteServiceException('No route found.');
    }

    final route = Map<String, dynamic>.from((decoded['routes'] as List).first as Map);
    final geometry = route['geometry'] is Map
        ? Map<String, dynamic>.from(route['geometry'] as Map)
        : const <String, dynamic>{};
    final coordsList = geometry['coordinates'];
    if (coordsList is! List || coordsList.isEmpty) {
      throw const RouteServiceException('Route had no geometry.');
    }

    final points = <LatLng>[];
    for (final pair in coordsList) {
      if (pair is! List || pair.length < 2) continue;
      final lon = (pair[0] as num).toDouble();
      final lat = (pair[1] as num).toDouble();
      points.add(LatLng(lat, lon));
    }
    if (points.isEmpty) {
      throw const RouteServiceException('Route had no geometry.');
    }

    return RouteResult(
      points: points,
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
    );
  }

  void dispose() => _client.close();
}
