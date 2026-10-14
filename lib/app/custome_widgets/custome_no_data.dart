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
    children: [
      // const SizedBox(height: 10),
      Image.asset(
        imagePath,
        width: 200,
        height: 200,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.inbox_outlined,
          size: 100,
          color: AppColors.textLightGrayLight,
        ),
      ),
      // const SizedBox(height: 10),
      Text(
        title.tr,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textLightGrayLight,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        "cons_no_data_body".tr,
        style: const TextStyle(
          color: AppColors.textLightGrayLight,
        ),
      ),
      const SizedBox(height: 85),
    ],
  );
}
