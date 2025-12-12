import 'package:flutter/material.dart';
import 'new_request_screen.dart';
import 'requests_store.dart';
import 'chat_screen.dart';

class BloodBankDashboardScreen extends StatelessWidget {
  final String bloodBankName;
  final String location;

  const BloodBankDashboardScreen({
    super.key,
    required this.bloodBankName,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff5f6fb),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: RequestsStore.instance,
            builder: (context, _) {
              final requests = RequestsStore.instance.requests;

              final urgentRequests = requests.where((r) => r.isUrgent).toList();
              final normalRequests = requests
                  .where((r) => !r.isUrgent)
                  .toList();

              final urgentCount = urgentRequests.length;
              final normalCount = normalRequests.length;
              final activeCount = requests.length;

              final urgentUnits = urgentRequests.fold<int>(
                0,
                (p, r) => p + r.units,
              );
              final normalUnits = normalRequests.fold<int>(
                0,
                (p, r) => p + r.units,
              );
              final totalUnits = urgentUnits + normalUnits;

              void goToNewRequest() {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        NewRequestScreen(bloodBankName: bloodBankName),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _TopBar(
                      bloodBankName: bloodBankName,
                      location: location,
                      onLogout: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          [
                            _StatCard(
                              title: 'Total units',
                              value: '$totalUnits',
                              icon: Icons.bloodtype_outlined,
                              iconBg: const Color(0xffe4edff),
                              borderColor: const Color(0xff2962ff),
                            ),
                            _StatCard(
                              title: 'Active requests',
                              value: '$activeCount',
                              icon: Icons.monitor_heart_outlined,
                              iconBg: const Color(0xffffe3e6),
                              borderColor: const Color(0xffe91e63),
                            ),
                            _StatCard(
                              title: 'Urgent requests',
                              value: '$urgentCount',
                              icon: Icons.trending_up,
                              iconBg: const Color(0xfffff1dd),
                              borderColor: const Color(0xffff9800),
                            ),
                            _StatCard(
                              title: 'Normal requests',
                              value: '$normalCount',
                              icon: Icons.check_circle_outline,
                              iconBg: const Color(0xffe7f6ea),
                              borderColor: const Color(0xff2e7d32),
                            ),
                            _StatCard(
                              title: 'Urgent units',
                              value: '$urgentUnits',
                              icon: Icons.warning_amber_rounded,
                              iconBg: const Color(0xfffff1dd),
                              borderColor: const Color(0xffff9800),
                            ),
                            _StatCard(
                              title: 'Normal units',
                              value: '$normalUnits',
                              icon: Icons.inventory_2_outlined,
                              iconBg: const Color(0xffe7f6ea),
                              borderColor: const Color(0xff2e7d32),
                            ),
                          ].map((card) {
                            // نخلي كل كرت نص الشاشة تقريباً (عمودين)
                            final w =
                                (MediaQuery.of(context).size.width -
                                    16 * 2 -
                                    12) /
                                2;
                            return SizedBox(width: w, child: card);
                          }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Blood requests section (الزر موجود دائماً)
                    _BloodRequestsSection(
                      requests: requests,
                      onCreatePressed: goToNewRequest,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String bloodBankName;
  final String location;
  final VoidCallback onLogout;

  const _TopBar({
    required this.bloodBankName,
    required this.location,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  bloodBankName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xffffe3e6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.favorite,
                color: Color(0xffe60012),
                size: 26,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 2, color: const Color(0xfff8ced4)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color borderColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BloodRequestsSection extends StatelessWidget {
  final List<BloodRequest> requests;
  final VoidCallback onCreatePressed;

  const _BloodRequestsSection({
    required this.requests,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Spacer(),
              Text(
                'Blood requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add),
              label: const Text('Create new request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffe60012),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (requests.isEmpty) ...[
            const SizedBox(height: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color(0xffffe3e6),
                  child: const Icon(
                    Icons.favorite_border,
                    color: Color(0xffe60012),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No blood requests yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a new blood request to reach donors',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final r = requests[index];
                return _RequestCard(request: r);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BloodRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final hasLocation = request.hospitalLocation.trim().isNotEmpty;
    final hasDetails = request.details.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfffdfdfd),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe6e9f0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xffffe3e6),
            child: Text(
              request.bloodType,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xffe60012),
              ),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${request.units} units • ${request.bloodBankName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  request.isUrgent ? 'Urgent' : 'Normal',
                  style: TextStyle(
                    fontSize: 13,
                    color: request.isUrgent ? Colors.red : Colors.black54,
                  ),
                ),

                if (hasLocation) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          request.hospitalLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ],

                if (hasDetails) ...[
                  const SizedBox(height: 6),
                  Text(
                    request.details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
            },
          ),
        ],
      ),
    );
  }
}
