import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'location_point.dart';

class DebouncedSearchCancelledException implements Exception {
  const DebouncedSearchCancelledException();
}

class GeocodingServiceException implements Exception {
  final String message;

  const GeocodingServiceException(this.message);

  @override
  String toString() => message;
}

class PlaceSearchResult {
  final String displayName;
  final LocationPoint point;
  final Map<String, dynamic> address;

  const PlaceSearchResult({
    required this.displayName,
    required this.point,
    this.address = const {},
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['lat']}');
    final lon = double.tryParse('${json['lon']}');
    if (lat == null || lon == null) {
      throw const FormatException('Search result is missing coordinates.');
    }

    final displayName = (json['display_name'] ?? '').toString();
    return PlaceSearchResult(
      displayName: displayName,
      point: LocationPoint(
        latitude: lat,
        longitude: lon,
        label: displayName,
      ),
      address: json['address'] is Map
          ? Map<String, dynamic>.from(json['address'] as Map)
          : const {},
    );
  }
}

class GeocodingService {
  static const Duration debounceDuration = Duration(seconds: 1);
  static const String userAgent =
      'EquipexSportsPlatform/1.0 (OpenStreetMap Nominatim; no-api-key map search)';

  final http.Client _client;
  Timer? _debounceTimer;
  Completer<List<PlaceSearchResult>>? _pendingCompleter;

  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PlaceSearchResult>> search(String query) {
    final trimmed = query.trim();
    _debounceTimer?.cancel();
    final pending = _pendingCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const DebouncedSearchCancelledException());
    }

    if (trimmed.length < 2) {
      return Future.value(const []);
    }

    final completer = Completer<List<PlaceSearchResult>>();
    _pendingCompleter = completer;

    _debounceTimer = Timer(debounceDuration, () async {
      try {
        final results = await _searchNow(trimmed);
        if (!completer.isCompleted) completer.complete(results);
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        if (identical(_pendingCompleter, completer)) {
          _pendingCompleter = null;
        }
      }
    });

    return completer.future;
  }

  Future<List<PlaceSearchResult>> _searchNow(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': '8',
    });

    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': userAgent,
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw GeocodingServiceException(
        'Place search failed with status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const GeocodingServiceException('Place search returned bad data.');
    }

    final results = <PlaceSearchResult>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      try {
        results.add(PlaceSearchResult.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  void dispose() {
    _debounceTimer?.cancel();
    final pending = _pendingCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const DebouncedSearchCancelledException());
    }
    _client.close();
  }
}
