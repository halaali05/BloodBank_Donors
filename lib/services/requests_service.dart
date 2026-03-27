import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blood_request_model.dart';
import 'cloud_functions_service.dart';

class RequestsService {
  static final RequestsService instance = RequestsService._internal();
  final CloudFunctionsService _cloudFunctions;

  RequestsService._internal() : _cloudFunctions = CloudFunctionsService();

  RequestsService.test({CloudFunctionsService? cloudFunctions})
    : _cloudFunctions = cloudFunctions ?? CloudFunctionsService();

  Future<void> addRequest(BloodRequest request) async {
    await _cloudFunctions.addRequest(
      requestId: request.id,
      bloodBankName: request.bloodBankName,
      bloodType: request.bloodType,
      units: request.units,
      isUrgent: request.isUrgent,
      details: request.details,
      hospitalLocation: request.hospitalLocation,
      hospitalLatitude: request.hospitalLatitude,
      hospitalLongitude: request.hospitalLongitude,
    );
  }

  Future<Map<String, dynamic>> getRequests({
    int limit = 50,
    String? lastRequestId,
  }) async {
    final result = await _cloudFunctions.getRequests(
      limit: limit,
      lastRequestId: lastRequestId,
    );

    final requestsList = (result['requests'] as List).map((data) {
      final requestData = Map<String, dynamic>.from(data);
      final id = requestData.remove('id') as String;
      if (requestData['createdAt'] != null) {
        requestData['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(
          requestData['createdAt'] as int,
        );
      }
      return BloodRequest.fromMap(requestData, id);
    }).toList();

    return {'requests': requestsList, 'hasMore': result['hasMore'] as bool};
  }
}
