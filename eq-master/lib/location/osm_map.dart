import 'package:eqq/core/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/design_tokens.dart';
import 'geocoding_service.dart';
import 'location_point.dart';
import 'location_service.dart';
import 'location_share.dart';

class OsmMapPreview extends StatelessWidget {
  final LocationPoint point;
  final double height;
  final VoidCallback? onTap;

  const OsmMapPreview({
    super.key,
    required this.point,
    this.height = 150,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final center = LatLng(point.latitude, point.longitude);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: AbsorbPointer(
            child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              _buildTileLayer(),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 42,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black45),
                      ],
                    ),
                  ),
                ],
              ),
              if (point.label?.trim().isNotEmpty == true)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(
                        point.label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'SFPro',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class OsmLocationPicker extends StatefulWidget {
  final LocationPoint? initialPoint;
  final String? initialLabel;

  const OsmLocationPicker({
    super.key,
    this.initialPoint,
    this.initialLabel,
  });

  @override
  State<OsmLocationPicker> createState() => _OsmLocationPickerState();
}

class _OsmLocationPickerState extends State<OsmLocationPicker> {
  static const LatLng _defaultCenter = LatLng(30.0444, 31.2357);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LocationService _locationService = LocationService();
  late final GeocodingService _geocodingService;

  LocationPoint? _pinnedPoint;
  List<PlaceSearchResult> _searchResults = const [];
  bool _isSearching = false;
  bool _isLocating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _geocodingService = GeocodingService();
    _pinnedPoint = widget.initialPoint;
    _searchController.text =
        widget.initialPoint?.label ?? widget.initialLabel ?? '';
  }

  @override
  void dispose() {
    _geocodingService.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  LatLng get _currentCenter {
    final point = _pinnedPoint;
    if (point == null) return _defaultCenter;
    return LatLng(point.latitude, point.longitude);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.trim().length >= 2;
      _error = null;
      if (query.trim().length < 2) _searchResults = const [];
    });

    _geocodingService.search(query).then((results) {
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }).catchError((error) {
      if (!mounted || error is DebouncedSearchCancelledException) return;
      setState(() {
        _isSearching = false;
        _error = error.toString();
      });
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _error = null;
    });

    try {
      final point = await _locationService.getCurrentLocation();
      if (!mounted) return;
      _setPinnedPoint(point, zoom: 16);
      _searchController.text = point.label ?? '';
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _selectSearchResult(PlaceSearchResult result) {
    _searchFocusNode.unfocus();
    _searchController.text = result.displayName;
    setState(() => _searchResults = const []);
    _setPinnedPoint(result.point, zoom: 16);
  }

  void _setPinnedPoint(LocationPoint point, {double zoom = 15}) {
    setState(() {
      _pinnedPoint = point;
      _error = null;
    });
    _mapController.move(LatLng(point.latitude, point.longitude), zoom);
  }

  void _pinFromMapTap(LatLng point) {
    final label = _searchController.text.trim();
    _setPinnedPoint(
      LocationPoint(
        latitude: point.latitude,
        longitude: point.longitude,
        label: label.isEmpty ? null : label,
      ),
    );
  }

  Future<void> _sharePinnedLocation() async {
    final point = _pinnedPoint;
    if (point == null) {
      setState(() => _error = 'Choose a location before sharing.');
      return;
    }
    await LocationShare.share(point);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: _pinnedPoint == null ? 12 : 15,
              onTap: (_, latLng) => _pinFromMapTap(latLng),
            ),
            children: [
              _buildTileLayer(),
              if (_pinnedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _pinnedPoint!.latitude,
                        _pinnedPoint!.longitude,
                      ),
                      width: 54,
                      height: 54,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 48,
                        shadows: [
                          Shadow(blurRadius: 5, color: Colors.black45),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                _SearchPanel(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  results: _searchResults,
                  isSearching: _isSearching,
                  panelColor: panelColor,
                  textColor: textColor,
                  onChanged: _onSearchChanged,
                  onResultTap: _selectSearchResult,
                  onClear: () {
                    _searchController.clear();
                    setState(() => _searchResults = const []);
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Material(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'SFPro',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                _BottomLocationActions(
                  point: _pinnedPoint,
                  panelColor: panelColor,
                  textColor: textColor,
                  onShare: _sharePinnedLocation,
                  onUse: _pinnedPoint == null
                      ? null
                      : () => Navigator.pop(context, _pinnedPoint),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: SafeArea(
        child: FloatingActionButton(
          heroTag: 'current-location-fab',
          backgroundColor: Colors.green.shade700,
          onPressed: _isLocating ? null : _useCurrentLocation,
          child: _isLocating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.my_location, color: Colors.white),
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<PlaceSearchResult> results;
  final bool isSearching;
  final Color panelColor;
  final Color textColor;
  final ValueChanged<String> onChanged;
  final ValueChanged<PlaceSearchResult> onResultTap;
  final VoidCallback onClear;

  const _SearchPanel({
    required this.controller,
    required this.focusNode,
    required this.results,
    required this.isSearching,
    required this.panelColor,
    required this.textColor,
    required this.onChanged,
    required this.onResultTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final isFocused = focusNode.hasFocus;
          return Material(
            color: panelColor,
            elevation: 8,
            shadowColor: Colors.black26,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isFocused
                    ? Colors.green
                    : (isDark ? Colors.white24 : Colors.green),
                width: isFocused ? 2.0 : 1.0,
              ),
            ),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: TextStyle(color: textColor, fontFamily: 'SFPro'),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search for a place',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: onClear,
                      ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            if (results.isNotEmpty) const Divider(height: 1),
            if (results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        result.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'SFPro',
                          fontSize: 14,
                        ),
                      ),
                      onTap: () => onResultTap(result),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomLocationActions extends StatelessWidget {
  final LocationPoint? point;
  final Color panelColor;
  final Color textColor;
  final VoidCallback onShare;
  final VoidCallback? onUse;

  const _BottomLocationActions({
    required this.point,
    required this.panelColor,
    required this.textColor,
    required this.onShare,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final label = point?.label?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Material(
        color: panelColor,
        elevation: 8,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point == null
                          ? 'No location pinned'
                          : label == null || label.isEmpty
                              ? '${point!.latitude.toStringAsFixed(6)}, ${point!.longitude.toStringAsFixed(6)}'
                              : label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: point == null ? null : onShare,
                      icon: const Icon(Icons.share),
                      label: Text(AppLocalizations.of(context).share),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onUse,
                      icon: const Icon(Icons.check),
                      label: Text(AppLocalizations.of(context).usePin),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TileLayer _buildTileLayer() {
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.eqq',
  );
}
