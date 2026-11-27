// my_new_app/lib/app/views/lang_selection_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth/lang_selection_controller.dart';

class LangSelectionView extends GetView<LangSelectionController> {
  const LangSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('select_language'.tr)),
      body: Obx(
        () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (controller.isLoadingLanguages.value)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              if (controller.languageError.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    controller.languageError.value,
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final language in controller.languages)
                ElevatedButton(
                  onPressed: controller.isChangingLanguage.value
                      ? null
                      : () async {
                          controller.selectedValue.value = language.code;
                          await controller.changeLanguage();
                        },
                  child: Text(language.name),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
