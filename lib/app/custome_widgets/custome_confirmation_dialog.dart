import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';

class CustomConfirmationDialog extends StatelessWidget {
  final String header;
  final String body;
  final String yesText;
  final String noText;
  final bool? isCancel;

  final VoidCallback onYes;
  final VoidCallback? onNo;

  const CustomConfirmationDialog({
    super.key,
    this.header = "Confirmation",
    required this.body,
    required this.onYes,
    this.onNo,
    this.noText = "Cancel",
    this.yesText = "Continue",
    this.isCancel = true,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      backgroundColor: AppColors.bgLight,
      title: Text(
        header,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: Text(body, style: Theme.of(context).textTheme.bodyLarge),
      actions: <Widget>[
        Visibility(
          visible: isCancel ?? true,
          child: TextButton(
            onPressed: onNo ?? Get.back<void>,
            child: Text(
              noText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        TextButton(
          onPressed: onYes,
          child: Text(
            yesText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
