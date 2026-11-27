import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../helpers/secure_store.dart';
import '../../helpers/shared_preferences.dart';
import '../../localization/localization.dart';
import '../../models/app_language.dart';
import '../../repositories/language_repository.dart';

class LangSelectionController extends GetxController {
  LangSelectionController({
    LanguageRepository? repository,
    Future<String> Function()? readOrganizationId,
    Future<bool> Function()? hasAuthenticatedSession,
    void Function(String message)? onLanguageError,
  })  : _repository = repository ?? LanguageRepository(),
        _readOrganizationId = readOrganizationId ??
            (() => SharedPrefsHelper.getString(
                  SharedPrefsHelper.organizationId,
                )),
        _onLanguageError = onLanguageError,
        _hasAuthenticatedSession = hasAuthenticatedSession ??
            (() async {
              final token = await FlutterSecureStore()
                  .getSingleValue(SharedPrefsHelper.accessToken);
              return token != null && token.trim().isNotEmpty;
            });

  final LanguageRepository _repository;
  final Future<String> Function() _readOrganizationId;
  final Future<bool> Function() _hasAuthenticatedSession;
  final void Function(String message)? _onLanguageError;

  final selectedValue = Localization.defaultLocale.languageCode.obs;
  final languages = _bundledLanguages().obs;
  final isLoadingLanguages = false.obs;
  final isChangingLanguage = false.obs;
  final languageError = ''.obs;
  final missingResourceKeys = <String>[].obs;

  final Map<String, Map<String, String>> _organizationTranslations = {};
  String _organizationScope = '';
  int _scopeVersion = 0;
  int _languageRequestVersion = 0;
  int _selectionRequestVersion = 0;

  List<Locale> get supportedLocales {
    final locales = <String, Locale>{};
    for (final locale in Localization.supportedLocales) {
      locales[Localization.localeKey(locale)] = locale;
    }
    for (final language in languages) {
      final locale = Localization.localeForLanguageCode(language.code);
      locales[Localization.localeKey(locale)] = locale;
    }
    return locales.values.toList(growable: false);
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_restoreAndLoad());
  }

  Future<void> _restoreAndLoad() async {
    final savedCode = await SharedPrefsHelper.getString(
      SharedPrefsHelper.languageCode,
      defaultValue: Localization.defaultLocale.languageCode,
    );
    if (savedCode.isNotEmpty) {
      selectedValue.value = savedCode;
    }

    await refreshForAuthenticatedSession(showErrors: false);
  }

  Future<void> refreshForAuthenticatedSession({
    bool showErrors = true,
  }) async {
    final requestVersion = ++_languageRequestVersion;
    final organizationId = (await _readOrganizationId()).trim();
    final isAuthenticated = await _hasAuthenticatedSession();

    if (organizationId.isEmpty || !isAuthenticated) {
      if (_organizationScope.isNotEmpty) {
        await _changeOrganizationScope('');
      }
      if (requestVersion == _languageRequestVersion) {
        languages.assignAll(_bundledLanguages());
        isLoadingLanguages.value = false;
      }
      return;
    }

    if (_organizationScope != organizationId) {
      await _changeOrganizationScope(organizationId);
    }
    final currentScopeVersion = _scopeVersion;
    isLoadingLanguages.value = true;
    languageError.value = '';

    try {
      final available = await _repository.fetchLanguages(
        organizationId: organizationId,
      );
      if (!await _isCurrentSession(
        requestVersion,
        requestVersion: _languageRequestVersion,
        sessionVersion: currentScopeVersion,
        organizationId: organizationId,
      )) {
        return;
      }
      if (available.isEmpty) {
        throw const FormatException('The server returned no languages.');
      }
      languages.assignAll(available);
      await _activateSavedLanguage(
        organizationId: organizationId,
        sessionVersion: currentScopeVersion,
      );
    } catch (error) {
      if (await _isCurrentSession(
        requestVersion,
        requestVersion: _languageRequestVersion,
        sessionVersion: currentScopeVersion,
        organizationId: organizationId,
      )) {
        languages.assignAll(_bundledLanguages());
        languageError.value =
            'Unable to load online languages. Built-in languages are shown.';
        if (showErrors) {
          _showError(languageError.value);
        }
      }
    } finally {
      if (requestVersion == _languageRequestVersion) {
        isLoadingLanguages.value = false;
      }
    }
  }

  Future<void> onAuthenticatedSessionChanged() async {
    ++_languageRequestVersion;
    ++_selectionRequestVersion;
    final organizationId = (await _readOrganizationId()).trim();
    await _changeOrganizationScope(organizationId);
    await refreshForAuthenticatedSession();
  }

  Future<bool> selectLanguage(String code) async {
    final language = _findLanguage(code);
    if (language == null) {
      _showError('That language is not available.');
      return false;
    }

    final requestVersion = ++_selectionRequestVersion;
    final organizationId = (await _readOrganizationId()).trim();
    final isAuthenticated = await _hasAuthenticatedSession();

    if (organizationId.isNotEmpty && isAuthenticated) {
      if (_organizationScope != organizationId) {
        await _changeOrganizationScope(organizationId);
      }

      final sessionVersion = _scopeVersion;
      isChangingLanguage.value = true;
      languageError.value = '';
      try {
        final translations = await _repository.fetchTranslations(
          organizationId: organizationId,
          languageCode: language.code,
        );
        if (!await _isCurrentSession(
          requestVersion,
          requestVersion: _selectionRequestVersion,
          sessionVersion: sessionVersion,
          organizationId: organizationId,
        )) {
          return false;
        }

        final locale = Localization.localeForLanguageCode(language.code);
        if (!await _persistSelection(language.code, locale)) {
          throw Exception('Unable to save the selected language.');
        }
        _organizationTranslations[Localization.localeKey(locale)] =
            translations;
        _installTranslations();
        _updateMissingResourceKeys(language.code, translations);
        selectedValue.value = language.code;
        await Get.updateLocale(locale);
        return true;
      } catch (error) {
        if (requestVersion == _selectionRequestVersion) {
          languageError.value =
              'Unable to load this language. Your current language is unchanged.';
          _showError(languageError.value);
        }
        return false;
      } finally {
        if (requestVersion == _selectionRequestVersion) {
          isChangingLanguage.value = false;
        }
      }
    }

    if (_organizationScope.isNotEmpty) {
      await _changeOrganizationScope('');
    }
    final locale = Localization.localeForLanguageCode(language.code);
    if (!Localization.supportedLocales.contains(locale)) {
      _showError('Sign in to load this organization language.');
      return false;
    }
    if (!await _persistSelection(language.code, locale)) {
      _showError('Unable to save the selected language.');
      return false;
    }
    _updateMissingResourceKeys(language.code, const {});
    selectedValue.value = language.code;
    await Get.updateLocale(locale);
    return true;
  }

  Future<void> changeLanguage() async {
    final changed = await selectLanguage(selectedValue.value);
    if (changed) {
      Get.offNamed<void>('/login');
    }
  }

  Future<void> clearOrganizationScope() async {
    ++_languageRequestVersion;
    ++_selectionRequestVersion;
    _organizationScope = '';
    _organizationTranslations.clear();
    languages.assignAll(_bundledLanguages());
    missingResourceKeys.clear();
    languageError.value = '';
    isLoadingLanguages.value = false;
    isChangingLanguage.value = false;
    _installTranslations();

    final currentLocale = Localization.localeForLanguageCode(
      Get.locale?.languageCode ?? selectedValue.value,
    );
    await Get.updateLocale(currentLocale);
  }

  Future<void> _activateSavedLanguage({
    required String organizationId,
    required int sessionVersion,
  }) async {
    final languageCode = await SharedPrefsHelper.getString(
      SharedPrefsHelper.languageCode,
      defaultValue: Localization.defaultLocale.languageCode,
    );
    if (!languages.any((language) => language.code == languageCode)) {
      return;
    }

    try {
      final translations = await _repository.fetchTranslations(
        organizationId: organizationId,
        languageCode: languageCode,
      );
      if (sessionVersion != _scopeVersion ||
          organizationId != (await _readOrganizationId()).trim()) {
        return;
      }
      final locale = Localization.localeForLanguageCode(languageCode);
      _organizationTranslations[Localization.localeKey(locale)] = translations;
      _installTranslations();
      _updateMissingResourceKeys(languageCode, translations);
      selectedValue.value = languageCode;
      await Get.updateLocale(locale);
    } catch (error) {
      languageError.value =
          'Unable to refresh translations. Built-in translations are active.';
      _showError(languageError.value);
    }
  }

  Future<void> _changeOrganizationScope(String organizationId) async {
    if (_organizationScope == organizationId) {
      return;
    }
    ++_scopeVersion;
    _organizationScope = organizationId;
    _organizationTranslations.clear();
    languages.assignAll(_bundledLanguages());
    missingResourceKeys.clear();
    _installTranslations();
    final currentLocale = Localization.localeForLanguageCode(
      Get.locale?.languageCode ?? selectedValue.value,
    );
    if (Get.locale != null) {
      await Get.updateLocale(currentLocale);
    }
  }

  Future<bool> _isCurrentSession(
    int requestId, {
    required int requestVersion,
    required int sessionVersion,
    required String organizationId,
  }) async {
    return requestId == requestVersion &&
        sessionVersion == _scopeVersion &&
        organizationId == _organizationScope &&
        organizationId == (await _readOrganizationId()).trim();
  }

  AppLanguage? _findLanguage(String code) {
    for (final language in languages) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }

  Future<bool> _persistSelection(String code, Locale locale) async {
    final languageSaved = await SharedPrefsHelper.setString(
      SharedPrefsHelper.languageCode,
      code,
    );
    if (!languageSaved) {
      return false;
    }
    return SharedPrefsHelper.setString(
      SharedPrefsHelper.countryCode,
      locale.countryCode ?? '',
    );
  }

  void _installTranslations() {
    Get.clearTranslations();
    Get.addTranslations(Localization().keys);
    for (final entry in _organizationTranslations.entries) {
      final base = Localization().keys[entry.key] ?? const <String, String>{};
      Get.addTranslations({
        entry.key: <String, String>{...base, ...entry.value},
      });
    }
  }

  void _updateMissingResourceKeys(
    String languageCode,
    Map<String, String> translations,
  ) {
    final missing = Localization.requiredResourceKeys
        .where((key) => !translations.containsKey(key))
        .toList()
      ..sort();
    missingResourceKeys.assignAll(missing);
    if (missing.isNotEmpty) {
      debugPrint(
        'Missing language resource keys for $languageCode: '
        '${missing.join(', ')}',
      );
    }
  }

  void _showError(String message) {
    if (_onLanguageError != null) {
      _onLanguageError(message);
      return;
    }
    if (Get.context == null) {
      return;
    }
    Get.snackbar(
      'Language',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  static List<AppLanguage> _bundledLanguages() => [
        for (final option in Localization.languageOptions)
          AppLanguage(code: option['code']!, name: option['name']!),
      ];
}
