import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/donor_medical_report.dart';
import '../../theme/app_theme.dart';

class DonorProfileReportsPage extends StatefulWidget {
  final List<DonorMedicalReport> initialReports;
  final bool initialLoading;
  final Future<List<DonorMedicalReport>> Function()? reloadReports;

  const DonorProfileReportsPage({
    super.key,
    required this.initialReports,
    required this.initialLoading,
    this.reloadReports,
  });

  @override
  State<DonorProfileReportsPage> createState() =>
      _DonorProfileReportsPageState();
}

class _DonorProfileReportsPageState extends State<DonorProfileReportsPage> {
  late List<DonorMedicalReport> _reports;
  late bool _isLoading;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _reports = List<DonorMedicalReport>.from(widget.initialReports);
    _isLoading =
        widget.initialLoading && !_hasUploadedReports(widget.initialReports);
    if (widget.reloadReports != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reloadReports();
      });
    }
  }

  static bool _hasUploadedReports(List<DonorMedicalReport> reports) {
    return reports.any(_isSavedReport);
  }

  static bool _isSavedReport(DonorMedicalReport report) {
    if (report.id.startsWith('active_')) return false;
    return report.reportFileUrl != null &&
        report.reportFileUrl!.trim().isNotEmpty;
  }

  Future<void> _reloadReports() async {
    final reload = widget.reloadReports;
    if (reload == null) return;
    setState(() => _isLoading = !_hasUploadedReports(_reports));
    try {
      final next = await reload();
      if (!mounted) return;
      setState(() {
        _reports = List<DonorMedicalReport>.from(next);
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedReports = _reports.where(_isSavedReport).toList();

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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.deepRed),
            )
          : savedReports.isEmpty
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
                    Text(
                      _loadError == null
                          ? 'No reports uploaded yet'
                          : 'Reports could not load',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (_loadError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: savedReports.length,
              itemBuilder: (_, i) {
                final report = savedReports[i];
                final status = donorProcessStatusToString(report.status);
                final reportUrl = report.reportFileUrl?.trim() ?? '';
                final hasReportFile = reportUrl.isNotEmpty;
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
                        child: hasReportFile
                            ? ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    final url = Uri.parse(reportUrl);
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text(
                                  'View Report',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.info_outline_rounded),
                                label: const Text(
                                  'Report saved, file link unavailable',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
