import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Eight full-screen “pages” of donation restriction guidelines as images.
///
/// Replace the placeholder files under [assets/docs/] with your real photos
/// (same names: `restriction_page_01.png` … `restriction_page_08.png`).
class DonorProfileDonationRestrictionsPage extends StatefulWidget {
  const DonorProfileDonationRestrictionsPage({super.key});

  /// Image paths in order (page 1 → page 8).
  static const List<String> pageAssetPaths = [
    'assets/docs/restriction_page_01.png',
    'assets/docs/restriction_page_02.png',
    'assets/docs/restriction_page_03.png',
    'assets/docs/restriction_page_04.png',
    'assets/docs/restriction_page_05.png',
    'assets/docs/restriction_page_06.png',
    'assets/docs/restriction_page_07.png',
    'assets/docs/restriction_page_08.png',
  ];

  @override
  State<DonorProfileDonationRestrictionsPage> createState() =>
      _DonorProfileDonationRestrictionsPageState();
}

class _DonorProfileDonationRestrictionsPageState
    extends State<DonorProfileDonationRestrictionsPage> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = DonorProfileDonationRestrictionsPage.pageAssetPaths.length;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Donation restrictions',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: _pageIndex > 0
                ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    )
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${_pageIndex + 1} / $total',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: _pageIndex < total - 1
                ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    )
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_pageIndex + 1) / total,
            minHeight: 3,
            backgroundColor: Colors.grey.shade300,
            color: AppTheme.deepRed,
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (context, index) {
                final path =
                    DonorProfileDonationRestrictionsPage.pageAssetPaths[index];
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      minScale: 0.6,
                      maxScale: 5,
                      boundaryMargin: const EdgeInsets.all(80),
                      child: Center(
                        child: Image.asset(
                          path,
                          fit: BoxFit.contain,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Missing image:\n$path\n\nAdd your PNG (or change '
                              'code to .jpg) under assets/docs/.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Text(
              'Swipe left/right between pages · pinch to zoom',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
