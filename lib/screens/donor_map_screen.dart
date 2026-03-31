import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/blood_request_model.dart';
import '../theme/app_theme.dart';
import 'request_details_screen.dart';

/// Map screen for donors — shows blood requests as pins on a Jordan map.
class DonorMapScreen extends StatefulWidget {
  final List<BloodRequest> requests;
  final String? donorGovernorate;
  final Future<void> Function(BloodRequest, String) onRespond;
  final String? respondingRequestId;

  const DonorMapScreen({
    super.key,
    required this.requests,
    this.donorGovernorate,
    required this.onRespond,
    this.respondingRequestId,
  });

  @override
  State<DonorMapScreen> createState() => _DonorMapScreenState();
}

class _DonorMapScreenState extends State<DonorMapScreen> {
  final MapController _mapController = MapController();
  bool _showAllRegions = false;
  BloodRequest? _selectedRequest;

  static const LatLng _jordanCenter = LatLng(31.9539, 35.9106);

  LatLng get _initialCenter {
    if (widget.donorGovernorate != null) {
      final c = AppTheme.governorateCoordinates[widget.donorGovernorate!];
      if (c != null) return LatLng(c['lat']!, c['lng']!);
    }
    return _jordanCenter;
  }

  double get _initialZoom => widget.donorGovernorate != null ? 11.0 : 8.0;

  List<BloodRequest> get _visibleRequests {
    if (_showAllRegions || widget.donorGovernorate == null) {
      return widget.requests;
    }
    return widget.requests.where((r) {
      return r.hospitalLocation.contains(widget.donorGovernorate!) ||
          widget.donorGovernorate!.contains(r.hospitalLocation);
    }).toList();
  }

  LatLng _requestLatLng(BloodRequest r) {
    if (r.hospitalLatitude != null && r.hospitalLongitude != null) {
      return LatLng(r.hospitalLatitude!, r.hospitalLongitude!);
    }
    final c = AppTheme.governorateCoordinates[r.hospitalLocation];
    if (c != null) return LatLng(c['lat']!, c['lng']!);
    return _jordanCenter;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleRequests;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            onTap: (_, __) => setState(() => _selectedRequest = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.bloodbank_donors',
            ),
            MarkerLayer(markers: visible.map((r) => _buildMarker(r)).toList()),
          ],
        ),

        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _FilterBar(
            donorGovernorate: widget.donorGovernorate,
            showAllRegions: _showAllRegions,
            visibleCount: visible.length,
            onToggle: (val) => setState(() {
              _showAllRegions = val;
              _selectedRequest = null;
              if (!val && widget.donorGovernorate != null) {
                _mapController.move(_initialCenter, _initialZoom);
              } else {
                _mapController.move(_jordanCenter, 8.0);
              }
            }),
          ),
        ),

        if (_selectedRequest != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _RequestBottomSheet(
              request: _selectedRequest!,
              isResponding: widget.respondingRequestId == _selectedRequest!.id,
              onAccept: () => widget.onRespond(_selectedRequest!, 'accepted'),
              onReject: () => widget.onRespond(_selectedRequest!, 'rejected'),
              onDetails: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RequestDetailsScreen(requestId: _selectedRequest!.id),
                  ),
                );
              },
              onClose: () => setState(() => _selectedRequest = null),
            ),
          ),
      ],
    );
  }

  Marker _buildMarker(BloodRequest r) {
    final latlng = _requestLatLng(r);
    final isSelected = _selectedRequest?.id == r.id;

    return Marker(
      point: latlng,
      width: isSelected ? 56 : 44,
      height: isSelected ? 64 : 52,
      alignment: const Alignment(0, -1),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedRequest = r);
          _mapController.move(latlng, 14);
        },
        child: _BloodPin(isUrgent: r.isUrgent, isSelected: isSelected),
      ),
    );
  }
}

// ── Filter bar ─────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String? donorGovernorate;
  final bool showAllRegions;
  final int visibleCount;
  final ValueChanged<bool> onToggle;

  const _FilterBar({
    required this.donorGovernorate,
    required this.showAllRegions,
    required this.visibleCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Icon(Icons.bloodtype, color: AppTheme.deepRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              showAllRegions || donorGovernorate == null
                  ? '$visibleCount request${visibleCount != 1 ? 's' : ''} across Jordan'
                  : '$visibleCount request${visibleCount != 1 ? 's' : ''} in $donorGovernorate',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          if (donorGovernorate != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onToggle(!showAllRegions),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: showAllRegions
                      ? Colors.grey.shade200
                      : AppTheme.deepRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  showAllRegions ? 'My area' : 'All Jordan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: showAllRegions ? Colors.black54 : AppTheme.deepRed,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Blood pin ──────────────────────────────────────────────────────────────────

class _BloodPin extends StatelessWidget {
  final bool isUrgent;
  final bool isSelected;

  const _BloodPin({required this.isUrgent, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = isUrgent ? AppTheme.urgentRed : AppTheme.deepRed;
    final size = isSelected ? 44.0 : 34.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isSelected ? 0.5 : 0.3),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 3 : 1,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isUrgent ? Icons.priority_high : Icons.water_drop,
              color: Colors.white,
              size: size * 0.48,
            ),
          ),
        ),
        CustomPaint(
          size: Size(isSelected ? 14 : 10, isSelected ? 12 : 8),
          painter: _PinTailPainter(color: color),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
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

// ── Bottom sheet ───────────────────────────────────────────────────────────────

class _RequestBottomSheet extends StatelessWidget {
  final BloodRequest request;
  final bool isResponding;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDetails;
  final VoidCallback onClose;

  const _RequestBottomSheet({
    required this.request,
    required this.isResponding,
    required this.onAccept,
    required this.onReject,
    required this.onDetails,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasResponded = request.myResponse != null;
    final accepted = request.myResponse == 'accepted';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: request.isUrgent
                            ? AppTheme.urgentBg
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          request.bloodType,
                          style: TextStyle(
                            color: request.isUrgent
                                ? AppTheme.urgentRed
                                : AppTheme.deepRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.bloodBankName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                request.hospitalLocation,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.black45,
                      onPressed: onClose,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.water_drop_outlined,
                      label:
                          '${request.units} unit${request.units > 1 ? 's' : ''}',
                    ),
                    if (request.isUrgent)
                      _InfoChip(
                        icon: Icons.warning_amber_rounded,
                        label: 'Urgent',
                        color: AppTheme.urgentRed,
                      ),
                    _InfoChip(
                      icon: Icons.people_outline,
                      label: '${request.acceptedCount} accepted',
                      color: Colors.green.shade700,
                    ),
                  ],
                ),

                if (request.details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    request.details,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),

                if (hasResponded)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: accepted
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          accepted ? Icons.check_circle : Icons.cancel_outlined,
                          size: 16,
                          color: accepted
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          accepted
                              ? 'You accepted this request'
                              : 'You declined this request',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accepted
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isResponding ? null : onReject,
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black54,
                            side: const BorderSide(color: Colors.black26),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isResponding ? null : onAccept,
                          icon: isResponding
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.favorite_outline, size: 16),
                          label: const Text(
                            'I can donate',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: AppTheme.primaryButtonStyle(),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                GestureDetector(
                  onTap: onDetails,
                  child: const Center(
                    child: Text(
                      'View full details',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.deepRed,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.deepRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
