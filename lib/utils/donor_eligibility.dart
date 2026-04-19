/// Donor post-donation rules — keep aligned with [functions/src/requests.js]
/// (`donorDonationCooldownEndMs` and gender-based days).
class DonorEligibility {
  DonorEligibility._();

  static int cooldownDaysForGender(String? gender) {
    final g = (gender ?? '').toLowerCase().trim();
    return g == 'female' ? 120 : 90;
  }

  static DateTime? coerceProfileDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  /// Same as server: `max(nextDonationEligibleAt, lastDonatedAt + 90/120d)`.
  static DateTime? cooldownEndsAt(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final explicit = coerceProfileDate(profile['nextDonationEligibleAt']);
    final last = coerceProfileDate(profile['lastDonatedAt']);
    final days = cooldownDaysForGender(profile['gender'] as String?);
    DateTime? fromLast;
    if (last != null) {
      fromLast = last.add(Duration(days: days));
    }
    if (explicit == null && fromLast == null) return null;
    if (explicit == null) return fromLast;
    if (fromLast == null) return explicit;
    return explicit.isAfter(fromLast) ? explicit : fromLast;
  }

  /// Start calendar day of the wait (for timeline). If only [nextDonationEligibleAt] exists, derived.
  static DateTime? cooldownWindowStartDate(Map<String, dynamic>? profile) {
    final last = coerceProfileDate(profile?['lastDonatedAt']);
    if (last != null) {
      return DateTime(last.year, last.month, last.day);
    }
    final end = cooldownEndsAt(profile);
    if (end == null) return null;
    final days = cooldownDaysForGender(profile?['gender'] as String?);
    final approx = end.subtract(Duration(days: days));
    return DateTime(approx.year, approx.month, approx.day);
  }

  static bool isCooldownActive(Map<String, dynamic>? profile) {
    final end = cooldownEndsAt(profile);
    return end != null && DateTime.now().isBefore(end);
  }

  /// Full calendar days from today (local midnight) to eligibility end date (local end date).
  static int calendarDaysRemaining(DateTime eligibilityEnd) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(
      eligibilityEnd.year,
      eligibilityEnd.month,
      eligibilityEnd.day,
    );
    final d = endDay.difference(today).inDays;
    return d < 0 ? 0 : d;
  }

  /// Inclusive count of calendar days in the wait window (for building day rows).
  static int cooldownTotalCalendarDays({
    required DateTime startDate,
    required DateTime endInstant,
  }) {
    final endDay = DateTime(
      endInstant.year,
      endInstant.month,
      endInstant.day,
    );
    final n = endDay.difference(startDate).inDays + 1;
    return n < 1 ? 1 : n;
  }
}
