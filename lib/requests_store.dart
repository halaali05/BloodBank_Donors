import 'package:flutter/foundation.dart';

@immutable
class BloodRequest {
  final String id;
  final String bloodBankName;
  final String bloodType;
  final int units;
  final bool isUrgent;
  final String details;
  final String hospitalLocation;

  const BloodRequest({
    required this.id,
    required this.bloodBankName,
    required this.bloodType,
    required this.units,
    required this.isUrgent,
    this.details = '',
    this.hospitalLocation = '',
  });
}

class RequestsStore extends ChangeNotifier {
  RequestsStore._internal();
  static final RequestsStore instance = RequestsStore._internal();

  final List<BloodRequest> _requests = <BloodRequest>[];

  List<BloodRequest> get requests => List.unmodifiable(_requests);

  void addRequest(BloodRequest request) {
    _requests.add(request);
    notifyListeners();
  }

  void clear() {
    _requests.clear();
    notifyListeners();
  }
}
