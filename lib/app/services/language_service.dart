import 'package:dio/dio.dart';

import 'api_service.dart';
import 'endpoints.dart';

class LanguageService {
  Future<Response<dynamic>?> fetchLanguages({
    required String organizationId,
  }) {
    return ApiService.get(
      EndPoints.resourceLanguages,
      headers: {'x-organization-id': organizationId},
      showServerErrors: false,
      showNoInternetDialog: false,
      diagnosticLabel: 'language_resources',
    );
  }

  Future<Response<dynamic>?> fetchTranslations({
    required String organizationId,
    required String languageCode,
  }) {
    return ApiService.get(
      EndPoints.resourceTranslations,
      queryParameters: {'languageCode': languageCode},
      headers: {'x-organization-id': organizationId},
      showServerErrors: false,
      showNoInternetDialog: false,
      diagnosticLabel: 'language_resources',
    );
  }
}
