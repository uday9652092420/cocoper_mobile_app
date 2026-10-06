import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_ar.dart';
import 'app_en.dart';
import 'app_hi.dart';
import 'app_te.dart';

class Localization extends Translations {
  // Supported languages
  static const localeEnglishUS = Locale('en', 'US');
  static const localeTeluguIN = Locale('te', 'IN');
  static const localeHindiIN = Locale('hi', 'IN');
  static const localeArabic = Locale('ar', 'SA'); // Arabic (Saudi Arabia)

  // Default locale
  static const defaultLocale = localeEnglishUS;

  // Fallback locale
  static const fallbackLocale = localeEnglishUS;

  // List of supported locales
  static const supportedLocales = [
    localeEnglishUS,
    localeTeluguIN,
    localeHindiIN,
    localeArabic,
  ];

  /// Languages offered by the dashboard language picker.
  static const languageOptions = <Map<String, String>>[
    {'code': 'en', 'country': 'US', 'name': 'English'},
    {'code': 'te', 'country': 'IN', 'name': 'తెలుగు'},
    {'code': 'hi', 'country': 'IN', 'name': 'हिन्दी'},
  ];

  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': enUS,
        'te_IN': teIN,
        'hi_IN': hiIN,
        'ar_SA': arSA,
      };

  // Function to update language
  void changeLanguage(String langCode, String countryCode) {
    final locale = Locale(langCode, countryCode);
    Get.updateLocale(locale);
  }
}
