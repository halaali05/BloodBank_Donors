import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/donor_medical_report.dart';
import '../../theme/app_theme.dart';

class DonorProfileReportsPage extends StatelessWidget {
  final List<DonorMedicalReport> reports;
  final bool isLoading;

  const DonorProfileReportsPage({
    super.key,
    required this.reports,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final uploadedReports = reports
        .where((r) => r.reportFileUrl != null && r.reportFileUrl!.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.deepRed),
            )
          : uploadedReports.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 34,
                      color: Colors.black38,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No reports uploaded yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: uploadedReports.length,
              itemBuilder: (_, i) {
                final report = uploadedReports[i];
                final status = donorProcessStatusToString(report.status);
                final hasNotes =
                    report.notes != null && report.notes!.trim().isNotEmpty;

                final isRestricted =
                    status.toLowerCase().contains('restricted') ||
                    status.toLowerCase().contains('not eligible');

                final statusColor = isRestricted ? Colors.orange : Colors.green;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${report.bloodType} Report',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  report.bloodBankName,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: isRestricted
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasNotes) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            report.notes!.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final url = Uri.parse(report.reportFileUrl!);
                              await launchUrl(
                                url,
                                mode: LaunchMode.inAppBrowserView,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.deepRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text(
                            'View Report',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
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
