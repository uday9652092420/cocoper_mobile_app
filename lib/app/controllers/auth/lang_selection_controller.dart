import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../helpers/shared_preferences.dart';
import '../../localization/localization.dart';

class LangSelectionController extends GetxController {
  var selectedValue = 'en'.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreSelection();
  }

  Future<void> _restoreSelection() async {
    final languageCode = await SharedPrefsHelper.getString(
      SharedPrefsHelper.languageCode,
    );
    if (Localization.languageOptions.any(
      (option) => option['code'] == languageCode,
    )) {
      selectedValue.value = languageCode;
    }
  }

  Future<void> changeLanguage() async {
    final option = Localization.languageOptions.firstWhere(
      (item) => item['code'] == selectedValue.value,
    );
    final languageCode = option['code']!;
    final countryCode = option['country']!;

    await SharedPrefsHelper.setString(
      SharedPrefsHelper.languageCode,
      languageCode,
    );
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.countryCode,
      countryCode,
    );
    await Get.updateLocale(Locale(languageCode, countryCode));
    Get.offNamed<void>('/login');
  }
}
