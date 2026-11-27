import 'package:cocoper_mobile/app/repositories/language_repository.dart';
import 'package:cocoper_mobile/app/services/language_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('language list uses organization scope and parses API languages',
      () async {
    final service = _FakeLanguageService(
      languagesResponse: [
        {'code': 'te', 'name': 'తెలుగు'},
        {'code': 'fr', 'name': 'Français'},
      ],
    );
    final repository = LanguageRepository(service: service);

    final languages = await repository.fetchLanguages(
      organizationId: 'org-a',
    );

    expect(service.languagesOrganizationId, 'org-a');
    expect(
      languages.map((language) => (language.code, language.name)).toList(),
      [('te', 'తెలుగు'), ('fr', 'Français')],
    );
  });

  test('translations use organization and selected-language scope', () async {
    final service = _FakeLanguageService(
      translationsResponse: {'dashboard': 'Tablero'},
    );
    final repository = LanguageRepository(service: service);

    final translations = await repository.fetchTranslations(
      organizationId: 'org-b',
      languageCode: 'es',
    );

    expect(service.translationsOrganizationId, 'org-b');
    expect(service.translationsLanguageCode, 'es');
    expect(translations, {'dashboard': 'Tablero'});
  });

  test('malformed translation values are rejected', () async {
    final repository = LanguageRepository(
      service: _FakeLanguageService(
        translationsResponse: {'dashboard': 42},
      ),
    );

    await expectLater(
      repository.fetchTranslations(
        organizationId: 'org-a',
        languageCode: 'te',
      ),
      throwsFormatException,
    );
  });
}

class _FakeLanguageService extends LanguageService {
  _FakeLanguageService({
    this.languagesResponse,
    this.translationsResponse,
  });

  final dynamic languagesResponse;
  final dynamic translationsResponse;
  String? languagesOrganizationId;
  String? translationsOrganizationId;
  String? translationsLanguageCode;

  @override
  Future<Response<dynamic>?> fetchLanguages({
    required String organizationId,
  }) async {
    languagesOrganizationId = organizationId;
    return _response(languagesResponse);
  }

  @override
  Future<Response<dynamic>?> fetchTranslations({
    required String organizationId,
    required String languageCode,
  }) async {
    translationsOrganizationId = organizationId;
    translationsLanguageCode = languageCode;
    return _response(translationsResponse);
  }

  Response<dynamic> _response(dynamic data) => Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: data,
      );
}
