import 'package:flutter/material.dart';
import '../../constants/donor_cooldown_messages.dart';
import '../../../views/donor_profile/donor_eligibility_screen.dart';
import '../../theme/app_theme.dart';

/// "Now, you're not eligible…" with a tappable [DonorCooldownMessages.linkLabel] → [DonorEligibilityScreen].
class DonorCooldownBlockedMessage extends StatelessWidget {
  final TextStyle baseStyle;
  final TextStyle linkStyle;

  const DonorCooldownBlockedMessage({
    super.key,
    this.baseStyle = const TextStyle(
      fontSize: 14,
      height: 1.35,
      color: Colors.black87,
    ),
    this.linkStyle = const TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w800,
      color: AppTheme.deepRed,
      decoration: TextDecoration.underline,
    ),
  });

  void _openEligibility(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DonorEligibilityScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: "Now, you're not eligible to donate. Open "),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _openEligibility(context),
              child: Text(DonorCooldownMessages.linkLabel, style: linkStyle),
            ),
          ),
          const TextSpan(text: ' for more details.'),
        ],
      ),
    );
  }
}
