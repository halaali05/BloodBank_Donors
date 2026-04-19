import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/common/donor_cooldown_blocked_message.dart';
import '../models/blood_request_model.dart';
import '../theme/app_theme.dart';
import 'request_details_screen.dart';

/// Map screen for donors — shows blood requests as pins on a Jordan map.
class DonorMapScreen extends StatefulWidget {
  final List<BloodRequest> requests;
  final String? donorGovernorate;
  final Future<void> Function(BloodRequest, String) onRespond;
  final String? respondingRequestId;

  /// Until this instant (exclusive of equality handled in helper), new
  /// "I can donate" responses are blocked after a completed donation.
  final DateTime? nextDonationEligibleAt;

  const DonorMapScreen({
    super.key,
    required this.requests,
    this.donorGovernorate,
    required this.onRespond,
    this.respondingRequestId,
    this.nextDonationEligibleAt,
  });

  @override
  State<DonorMapScreen> createState() => _DonorMapScreenState();
}

class _DonorMapScreenState extends State<DonorMapScreen> {
  final MapController _mapController = MapController();
  bool _showAllRegions = false;
  BloodRequest? _selectedRequest;
  double _currentZoom = 8.0;

  static const LatLng _jordanCenter = LatLng(31.9539, 35.9106);

  LatLng get _initialCenter {
    if (widget.donorGovernorate != null) {
      final c = AppTheme.governorateCoordinates[widget.donorGovernorate!];
      if (c != null) return LatLng(c['lat']!, c['lng']!);
    }
    return _jordanCenter;
  }

  double get _initialZoom => widget.donorGovernorate != null ? 11.0 : 8.0;

  @override
  void initState() {
    super.initState();
    _currentZoom = _initialZoom;
  }

  /// Blocks starting a new "I can donate" while post-donation cooldown active.
  bool _cooldownBlocksNewAccept(BloodRequest request) {
    final end = widget.nextDonationEligibleAt;
    if (end == null || !end.isAfter(DateTime.now())) return false;
    return request.myResponse != 'accepted';
  }

  @override
  void dispose() {
    super.dispose();
  }

  // الـ cluster المفتوح حالياً (list من requests بنفس المكان)
  List<BloodRequest>? _clusterRequests;

  List<BloodRequest> get _visibleRequests {
    final activeRequests = widget.requests
        .where((r) => !r.isCompleted)
        .toList();
    if (_showAllRegions || widget.donorGovernorate == null) {
      return activeRequests;
    }
    return activeRequests.where((r) {
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

  // تجميع الـ requests اللي على نفس الإحداثيات
  Map<String, List<BloodRequest>> _groupByLocation(
    List<BloodRequest> requests,
  ) {
    final Map<String, List<BloodRequest>> groups = {};
    for (final r in requests) {
      final ll = _requestLatLng(r);
      final key =
          '${ll.latitude.toStringAsFixed(4)},${ll.longitude.toStringAsFixed(4)}';
      groups.putIfAbsent(key, () => []).add(r);
    }
    return groups;
  }

  void _zoomIn() {
    final next = (_currentZoom + 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, next);
  }

  void _zoomOut() {
    final next = (_currentZoom - 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, next);
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
            onPositionChanged: (position, _) {
              final z = position.zoom;
              if (mounted) {
                setState(() => _currentZoom = z);
              }
            },
            onTap: (_, __) => setState(() {
              _selectedRequest = null;
              _clusterRequests = null;
            }),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.bloodbank_donors',
            ),
            MarkerLayer(markers: _buildAllMarkers(visible)),
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
              cooldownBlocksAccept: _cooldownBlocksNewAccept(_selectedRequest!),
              onDonate: () => widget.onRespond(_selectedRequest!, 'accepted'),
              onUndoDonate: () => widget.onRespond(_selectedRequest!, 'none'),
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

        if (_clusterRequests != null && _selectedRequest == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ClusterBottomSheet(
              requests: _clusterRequests!,
              respondingRequestId: widget.respondingRequestId,
              nextDonationEligibleAt: widget.nextDonationEligibleAt,
              onRespond: widget.onRespond,
              onSelectRequest: (r) {
                setState(() {
                  _selectedRequest = r;
                  _clusterRequests = null;
                });
              },
              onClose: () => setState(() => _clusterRequests = null),
            ),
          ),

        Positioned(
          right: 12,
          bottom: (_selectedRequest != null || _clusterRequests != null)
              ? 236
              : 24,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'donorMapZoomIn',
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.deepRed,
                onPressed: _zoomIn,
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'donorMapZoomOut',
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.deepRed,
                onPressed: _zoomOut,
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Marker> _buildAllMarkers(List<BloodRequest> requests) {
    final groups = _groupByLocation(requests);
    final List<Marker> markers = [];

    for (final entry in groups.entries) {
      final group = entry.value;
      final center = _requestLatLng(group.first);

      if (group.length == 1) {
        markers.add(_buildMarker(group.first));
      } else {
        // cluster — دائرة فيها العدد، لما تضغط يطلع bottom sheet
        final hasUrgent = group.any((r) => r.isUrgent);
        markers.add(
          Marker(
            point: center,
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => setState(() {
                _clusterRequests = group;
                _selectedRequest = null;
              }),
              child: _ClusterPin(count: group.length, hasUrgent: hasUrgent),
            ),
          ),
        );
      }
    }
    return markers;
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

// ── Cluster pin ────────────────────────────────────────────────────────────────

class _ClusterPin extends StatelessWidget {
  final int count;
  final bool hasUrgent;

  const _ClusterPin({required this.count, required this.hasUrgent});

  @override
  Widget build(BuildContext context) {
    final color = hasUrgent ? AppTheme.urgentRed : AppTheme.deepRed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // حلقة خارجية شفافة
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(12, 9),
          painter: _PinTailPainter(color: color),
        ),
      ],
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

// ── Cluster bottom sheet ───────────────────────────────────────────────────────

class _ClusterBottomSheet extends StatelessWidget {
  final List<BloodRequest> requests;
  final String? respondingRequestId;
  final DateTime? nextDonationEligibleAt;
  final Future<void> Function(BloodRequest, String) onRespond;
  final ValueChanged<BloodRequest> onSelectRequest;
  final VoidCallback onClose;

  const _ClusterBottomSheet({
    required this.requests,
    required this.respondingRequestId,
    this.nextDonationEligibleAt,
    required this.onRespond,
    required this.onSelectRequest,
    required this.onClose,
  });

  static bool _blocks(BloodRequest request, DateTime? end) {
    if (end == null || !end.isAfter(DateTime.now())) return false;
    return request.myResponse != 'accepted';
  }

  @override
  Widget build(BuildContext context) {
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
          // Handle
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${requests.length} requests here',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepRed,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.black45,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          // List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = requests[i];
                return _ClusterRequestCard(
                  request: r,
                  isResponding: respondingRequestId == r.id,
                  cooldownBlocksAccept: _blocks(r, nextDonationEligibleAt),
                  onRespond: onRespond,
                  onTap: () => onSelectRequest(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClusterRequestCard extends StatelessWidget {
  final BloodRequest request;
  final bool isResponding;
  final bool cooldownBlocksAccept;
  final Future<void> Function(BloodRequest, String) onRespond;
  final VoidCallback onTap;

  const _ClusterRequestCard({
    required this.request,
    required this.isResponding,
    required this.cooldownBlocksAccept,
    required this.onRespond,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDonating = request.myResponse == 'accepted';
    final process = request.donorProcessStatus?.toLowerCase();
    final isDonationFinal = process == 'donated' || process == 'restricted';
    final isActionDisabled =
        isResponding || isDonationFinal || cooldownBlocksAccept;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: request.isUrgent
              ? AppTheme.urgentRed.withValues(alpha: 0.04)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: request.isUrgent
                ? AppTheme.urgentRed.withValues(alpha: 0.25)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            // Blood type badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: request.isUrgent
                    ? AppTheme.urgentRed.withValues(alpha: 0.12)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  request.bloodType,
                  style: TextStyle(
                    color: request.isUrgent
                        ? AppTheme.urgentRed
                        : AppTheme.deepRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.bloodBankName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (request.isUrgent)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.urgentRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Urgent',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${request.units} unit${request.units > 1 ? 's' : ''} · ${request.acceptedCount} can donate',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action
            ElevatedButton(
              onPressed: isActionDisabled
                  ? null
                  : () => onRespond(request, isDonating ? 'none' : 'accepted'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDonating ? Colors.green.shade700 : AppTheme.deepRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isResponding
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isDonationFinal
                          ? 'Donation completed'
                          : (cooldownBlocksAccept
                                ? 'Not eligible'
                                : (isDonating ? 'Selected' : 'I can donate')),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet ───────────────────────────────────────────────────────────────

class _RequestBottomSheet extends StatelessWidget {
  final BloodRequest request;
  final bool isResponding;
  final bool cooldownBlocksAccept;
  final VoidCallback onDonate;
  final VoidCallback onUndoDonate;
  final VoidCallback onDetails;
  final VoidCallback onClose;

  const _RequestBottomSheet({
    required this.request,
    required this.isResponding,
    required this.cooldownBlocksAccept,
    required this.onDonate,
    required this.onUndoDonate,
    required this.onDetails,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDonating = request.myResponse == 'accepted';
    final process = request.donorProcessStatus?.toLowerCase();
    final isDonationFinal = process == 'donated' || process == 'restricted';
    final isActionDisabled =
        isResponding || isDonationFinal || cooldownBlocksAccept;

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
                      label: '${request.acceptedCount} can donate',
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

                if (cooldownBlocksAccept) ...[
                  const SizedBox(height: 10),
                  DonorCooldownBlockedMessage(
                    baseStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade800,
                      height: 1.35,
                    ),
                    linkStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: AppTheme.deepRed,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isActionDisabled
                        ? null
                        : (isDonating ? onUndoDonate : onDonate),
                    icon: isResponding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isDonating
                                ? Icons.check_circle_outline
                                : Icons.favorite_outline,
                            size: 16,
                          ),
                    label: Text(
                      isDonationFinal
                          ? 'Donation completed'
                          : (cooldownBlocksAccept
                                ? 'Not eligible yet'
                                : (isDonating
                                      ? 'Selected: I can donate'
                                      : 'I can donate')),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: AppTheme.primaryButtonStyle().copyWith(
                      backgroundColor: WidgetStateProperty.all(
                        isDonating ? Colors.green.shade700 : AppTheme.deepRed,
                      ),
                    ),
                  ),
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
