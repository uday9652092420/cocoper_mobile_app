import 'package:dio/dio.dart';

import '../services/api_service.dart';
import '../services/endpoints.dart';

class LoadingDispatchRepository {
  Future<Response<dynamic>?> fetchDispatches() =>
      ApiService.get(EndPoints.loadingDispatches);

  Future<Response<dynamic>?> fetchCustomers() =>
      ApiService.get(EndPoints.customers);

  Future<Response<dynamic>?> fetchBranches() =>
      ApiService.get(EndPoints.branches);

  Future<Response<dynamic>?> fetchItems() =>
      ApiService.get(EndPoints.items);

  Future<Response<dynamic>?> saveDispatch(Map<String, dynamic> payload) =>
      ApiService.post(EndPoints.loadingDispatches, payload);

  Future<Response<dynamic>?> deleteDispatch(String id) =>
      ApiService.delete(EndPoints.loadingDispatch(id));
}
