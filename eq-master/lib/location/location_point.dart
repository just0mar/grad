class LocationPoint {
  final double latitude;
  final double longitude;
  final String? label;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  String get osmUrl {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng';
  }

  String get googleMapsUrl {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  String get shareText {
    final title = label?.trim();
    final prefix = title == null || title.isEmpty ? 'Location' : title;
    return '$prefix\n$googleMapsUrl';
  }
}
