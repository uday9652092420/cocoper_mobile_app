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

  static const requiredResourceKeys = <String>{
    'cons_enter_crt_emial',
    'cons_enter_mobile_no',
    'cons_enter_mobile_no_digits',
    'cons_enter_mobile_no_exceed_digits',
    'cons_enter_mobile_no_valid',
    'cons_no_data_body',
    'internet_not_available',
    'reload',
    'go_settings',
    'select_options',
    'select_language',
    'language',
    'dashboard',
    'operations',
    'statements',
    'profile',
    'active_branch',
    'role',
    'select_branch',
    'no_branches',
    'home_tagline',
    'home_banner_title',
    'home_banner_description',
    'home_search_hint',
    'home_purchased',
    'home_sold',
    'home_received',
    'home_workers',
    'home_short_steps',
    'home_fast_transactions',
    'home_see_all',
    'home_purchase_entry',
    'home_purchase_entry_description',
    'home_sales_order',
    'home_sales_order_description',
    'home_payment_receipt',
    'home_payment_receipt_description',
    'finance_journal_entries',
    'finance_journal_entries_description',
    'finance_petty_cash',
    'finance_petty_cash_description',
    'finance_new_journal',
    'finance_new_petty_cash',
    'finance_total',
    'finance_drafts',
    'finance_posted',
    'finance_all_assigned_branches',
    'finance_branch',
    'finance_all_dates',
    'finance_clear_date_range',
    'finance_clear_search',
    'finance_search_voucher',
    'finance_status',
    'finance_all_statuses',
    'finance_no_matches',
    'finance_no_petty_entries',
    'finance_no_journal_entries',
    'finance_retry',
    'finance_refresh',
    'finance_voucher_details',
    'finance_date',
    'finance_reference_optional',
    'finance_description_narration',
    'finance_journal_lines',
    'finance_petty_cash_payment',
    'finance_account',
    'finance_expense_account',
    'finance_cash_account_credit',
    'finance_debit',
    'finance_credit',
    'finance_expense_amount',
    'finance_line_memo_optional',
    'finance_expense_memo_optional',
    'finance_add_line',
    'finance_remove_line',
    'finance_add_expense_line',
    'finance_remove_expense',
    'finance_total_debit',
    'finance_total_credit',
    'finance_balanced',
    'finance_difference',
    'finance_save_as_draft',
    'finance_posting_separate',
    'finance_journal_details',
    'finance_petty_cash_details',
    'finance_journal_voucher',
    'finance_reference',
    'finance_description',
    'finance_debit_total',
    'finance_credit_total',
    'finance_edit_draft',
    'finance_post_journal',
    'finance_reverse_posted',
    'finance_delete_draft',
    'finance_post_question',
    'finance_post_message',
    'finance_reverse_question',
    'finance_reverse_message',
    'finance_delete_question',
    'finance_delete_message',
    'finance_cancel',
    'finance_post',
    'finance_reverse',
    'finance_delete',
  };

  /// Languages offered by the dashboard language picker.
  static const languageOptions = <Map<String, String>>[
    {'code': 'en', 'country': 'US', 'name': 'English'},
    {'code': 'te', 'country': 'IN', 'name': 'తెలుగు'},
    {'code': 'hi', 'country': 'IN', 'name': 'हिन्दी'},
    {'code': 'ar', 'country': 'SA', 'name': 'العربية'},
  ];

  static Locale localeForLanguageCode(String code) {
    for (final locale in supportedLocales) {
      if (locale.languageCode == code) {
        return locale;
      }
    }
    return Locale(code);
  }

  static String localeKey(Locale locale) {
    final countryCode = locale.countryCode;
    return countryCode == null || countryCode.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_$countryCode';
  }

  static bool isRightToLeft(Locale locale) =>
      const {'ar', 'fa', 'he', 'ur'}.contains(locale.languageCode);

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
