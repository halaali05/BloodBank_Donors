import 'package:flutter/material.dart';
import '../../models/donor_medical_report.dart';
import '../../theme/app_theme.dart';
import '../../widgets/donation_history_section.dart';

class DonorProfileDonationHistoryPage extends StatelessWidget {
  final List<DonorMedicalReport> reports;
  final bool isLoading;

  const DonorProfileDonationHistoryPage({
    super.key,
    required this.reports,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Donation History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DonationHistorySection(reports: reports, isLoading: isLoading),
        ],
      ),
    );
  }
}
