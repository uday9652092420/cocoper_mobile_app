import 'package:dio/dio.dart';

import '../models/app_language.dart';
import '../services/language_service.dart';

class LanguageRepository {
  LanguageRepository({
    LanguageService? service,
  }) : _service = service ?? LanguageService();

  final LanguageService _service;

  Future<List<AppLanguage>> fetchLanguages({
    required String organizationId,
  }) async {
    final response = await _service.fetchLanguages(
      organizationId: organizationId,
    );
    final body = _requireBody(response, 'available languages');
    final values = body is Map ? body['data'] ?? body['languages'] : body;
    if (values is! List) {
      throw const FormatException('Languages response must be a list.');
    }
    return values.map(AppLanguage.fromJson).toList(growable: false);
  }

  Future<Map<String, String>> fetchTranslations({
    required String organizationId,
    required String languageCode,
  }) async {
    final response = await _service.fetchTranslations(
      organizationId: organizationId,
      languageCode: languageCode,
    );
    final body = _requireBody(response, 'translations');
    final values = body is Map && body['data'] is Map ? body['data'] : body;
    if (values is! Map) {
      throw const FormatException('Translations response must be an object.');
    }

    final translations = <String, String>{};
    for (final entry in values.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException(
          'Translation keys and values must be strings.',
        );
      }
      final key = (entry.key as String).trim();
      if (key.isNotEmpty) {
        translations[key] = entry.value as String;
      }
    }
    return translations;
  }

  dynamic _requireBody(Response<dynamic>? response, String resourceName) {
    if (response == null) {
      throw Exception('Unable to load $resourceName: no response received.');
    }
    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw Exception('Unable to load $resourceName (HTTP $statusCode).');
    }
    final body = response.data;
    if (body is Map && body['success'] == false) {
      final message = body['message']?.toString().trim();
      throw Exception(
        message == null || message.isEmpty
            ? 'Unable to load $resourceName.'
            : message,
      );
    }
    return body;
  }
}
