import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';

Widget noDataAvailable({
  String imagePath = "assets/nodata/no_data.png",
  String title = "cons_no_data",
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: AppSpacing.md),
      Image.asset(
        imagePath,
        width: 144,
        height: 144,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.inbox_outlined,
          size: 72,
          color: AppColors.textLightGrayLight,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        title.tr,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textDefaultLight,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        "cons_no_data_body".tr,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textLightGrayLight,
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
    ],
  );
}
