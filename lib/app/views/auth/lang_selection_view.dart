// my_new_app/lib/app/views/lang_selection_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth/lang_selection_controller.dart';
import '../../localization/localization.dart';

class LangSelectionView extends GetView<LangSelectionController> {
  const LangSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('select_language'.tr)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final option in Localization.languageOptions)
              ElevatedButton(
                onPressed: () async {
                  controller.selectedValue.value = option['code']!;
                  await controller.changeLanguage();
                },
                child: Text(option['name']!),
              ),
          ],
        ),
      ),
    );
  }
}
