import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

/// Result returned from the map location picker
class LocationPickerResult {
  final LatLng coordinates;
  final String displayAddress;

  LocationPickerResult({
    required this.coordinates,
    required this.displayAddress,
  });
}

/// Full-screen map picker — lets the hospital pin their exact location
/// Returns [LocationPickerResult] with coordinates + a short address label
class MapLocationPickerScreen extends StatefulWidget {
  /// Pre-selected governorate name to centre the map on initially
  final String? initialGovernorate;

  const MapLocationPickerScreen({super.key, this.initialGovernorate});

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  // Default center: Jordan centre
  static const LatLng _jordanCenter = LatLng(31.9539, 35.9106);

  final MapController _mapController = MapController();

  LatLng? _pickedLocation;
  bool _locating = false;

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Returns the map centre for a given governorate name, or Jordan centre.
  LatLng _governorateCenter(String name) {
    final coords = AppTheme.governorateCoordinates[name];
    if (coords == null) return _jordanCenter;
    return LatLng(coords['lat']!, coords['lng']!);
  }

  /// Returns the initial map centre based on [widget.initialGovernorate].
  LatLng get _initialCenter => widget.initialGovernorate != null
      ? _governorateCenter(widget.initialGovernorate!)
      : _jordanCenter;

  /// Builds a human-readable address label from [latlng] by finding the
  /// nearest governorate centre (simple Euclidean distance).
  String _buildAddressLabel(LatLng latlng) {
    String nearest = 'Jordan';
    double minDist = double.infinity;

    for (final entry in AppTheme.governorateCoordinates.entries) {
      final center = LatLng(entry.value['lat']!, entry.value['lng']!);
      final dist = _euclidean(latlng, center);
      if (dist < minDist) {
        minDist = dist;
        nearest = entry.key;
      }
    }

    return '${latlng.latitude.toStringAsFixed(5)}, '
        '${latlng.longitude.toStringAsFixed(5)} ($nearest)';
  }

  double _euclidean(LatLng a, LatLng b) {
    final dlat = a.latitude - b.latitude;
    final dlng = a.longitude - b.longitude;
    return dlat * dlat + dlng * dlng;
  }

  // ── GPS ────────────────────────────────────────────────────────────────────

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Enable it in device settings.',
              ),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      _mapController.move(latlng, 16);
      setState(() => _pickedLocation = latlng);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location.')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── confirm ────────────────────────────────────────────────────────────────

  void _confirm() {
    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap the map to select the hospital location.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      LocationPickerResult(
        coordinates: _pickedLocation!,
        displayAddress: _buildAddressLabel(_pickedLocation!),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Pin hospital location',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 12,
              onTap: (_, latlng) {
                setState(() => _pickedLocation = latlng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bloodbank_donors',
              ),
              // Governorate markers (light grey pins)
              MarkerLayer(
                markers: AppTheme.governorateCoordinates.entries.map((e) {
                  final pos = LatLng(e.value['lat']!, e.value['lng']!);
                  return Marker(
                    point: pos,
                    width: 90,
                    height: 36,
                    child: _GovernorateLabel(name: e.key),
                  );
                }).toList(),
              ),
              // Picked location marker (red pin)
              if (_pickedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedLocation!,
                      width: 48,
                      height: 56,
                      alignment: const Alignment(0, -1),
                      child: const _RedPin(),
                    ),
                  ],
                ),
            ],
          ),

          // ── Instruction banner ───────────────────────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _InfoBanner(hasPick: _pickedLocation != null),
          ),

          // ── GPS button ───────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 110,
            child: FloatingActionButton.small(
              heroTag: 'gps',
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.deepRed,
              tooltip: 'Use my location',
              onPressed: _locating ? null : _goToMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),

          // ── Confirm button ───────────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _pickedLocation != null ? _confirm : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Confirm location',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: AppTheme.primaryButtonStyle(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small widgets ──────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final bool hasPick;
  const _InfoBanner({required this.hasPick});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasPick ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            hasPick ? Icons.location_on : Icons.touch_app_outlined,
            color: AppTheme.deepRed,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasPick
                  ? 'Location selected! Tap again to move the pin.'
                  : 'Tap anywhere on the map to pin the hospital location.',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernorateLabel extends StatelessWidget {
  final String name;
  const _GovernorateLabel({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _RedPin extends StatelessWidget {
  const _RedPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.deepRed,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepRed.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.local_hospital,
            color: Colors.white,
            size: 20,
          ),
        ),
        // Pin tail
        CustomPaint(size: const Size(12, 10), painter: _PinTailPainter()),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.deepRed;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
