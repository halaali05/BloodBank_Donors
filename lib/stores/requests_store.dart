import 'package:flutter/foundation.dart';
import '../models/blood_request_model.dart';

/// State management store for blood requests
/// Manages local state of requests and notifies listeners of changes
/// Uses the Provider pattern for state management
class RequestsStore extends ChangeNotifier {
  RequestsStore._internal();
  static final RequestsStore instance = RequestsStore._internal();

  /// Internal list of blood requests
  final List<BloodRequest> _requests = <BloodRequest>[];

  /// Public getter for requests list (read-only)
  /// Returns an unmodifiable copy of the requests list
  List<BloodRequest> get requests => List.unmodifiable(_requests);

  /// Adds a new request to the store
  ///
  /// Adds a [BloodRequest] to the internal list and notifies all listeners
  /// that the state has changed.
  ///
  /// Parameters:
  /// - [request]: The [BloodRequest] to add to the store
  void addRequest(BloodRequest request) {
    _requests.add(request);
    notifyListeners();
  }

  /// Clears all requests from the store
  ///
  /// Removes all requests from the internal list and notifies all listeners
  /// that the state has changed. Useful for resetting state or logging out.
  void clear() {
    _requests.clear();
    notifyListeners();
  }
}
