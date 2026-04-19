/// Copy for post-donation "I can donate" cooldown.
/// Keep [serverEligibilityBlocked] in sync with [functions/src/requests.js].
class DonorCooldownMessages {
  DonorCooldownMessages._();

  /// Tappable segment label (see [DonorCooldownBlockedMessage]).
  static const linkLabel = 'When can I donate?';

  /// Plain string for Cloud Functions / snackbars that cannot use a link widget.
  static const serverEligibilityBlocked =
      "Now, you're not eligible to donate. Open When can I donate? for more details.";
}
