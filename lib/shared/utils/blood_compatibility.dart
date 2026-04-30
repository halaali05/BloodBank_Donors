/// Utility class for blood type compatibility checks.
///
/// Used to filter blood requests shown to a donor based on their blood type.
/// Only requests where the donor's blood type is compatible with the
/// requested blood type will be shown.
class BloodCompatibility {
  /// Maps each blood type to the list of donor types it can receive from.
  static const Map<String, List<String>> _canReceiveFrom = {
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    'AB-': ['A-', 'B-', 'AB-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'],
  };

  static const List<String> allTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  /// Returns true if a donor with [donorType] can donate to a patient
  /// who needs [requestType].
  static bool canDonate(String donorType, String requestType) {
    final receivers = _canReceiveFrom[requestType] ?? [];
    return receivers.contains(donorType);
  }

  /// Returns all blood types that [donorType] can donate to.
  static List<String> compatibleRequestTypes(String donorType) {
    return allTypes.where((t) => canDonate(donorType, t)).toList();
  }
}
