import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class CustomeArrowBack extends StatelessWidget {
  final VoidCallback? onPressed;
  final EdgeInsets? padding;
  const CustomeArrowBack({super.key, this.onPressed, this.padding});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Get.back<void>(),
      padding: padding,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(Icons.arrow_back),
    );
  }
}
