import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'requests_store.dart';
import 'chat_screen.dart';

class DonorDashboardScreen extends StatelessWidget {
  const DonorDashboardScreen({super.key, this.donorName = 'Donor'});

  final String donorName;

  @override
  Widget build(BuildContext context) {
    final bool hasNotifications = true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hayat'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none),
                if (hasNotifications)
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: RequestsStore.instance,
        builder: (context, _) {
          final requests = RequestsStore.instance.requests;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $donorName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Blood requests',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: requests.isEmpty
                      ? const Center(
                          child: Text(
                            'No blood requests yet.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.separated(
                          itemCount: requests.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final r = requests[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xffe6e9f0),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xffffe3e6),
                                    child: Text(
                                      r.bloodType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xffe60012),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${r.units} units needed',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Blood bank: ${r.bloodBankName}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          r.isUrgent
                                              ? 'Urgent request'
                                              : 'Normal request',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: r.isUrgent
                                                ? Colors.red
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const ChatScreen(),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.chat_bubble_outline,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Messages',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
