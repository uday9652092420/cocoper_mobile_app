import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CommonPageSearch extends StatelessWidget {
  final String txtHintValue;
  final VoidCallback? searchEvent;
  final ValueChanged<String>? onChanged;
  final bool? showShadow;
  final TextEditingController? controller;

  const CommonPageSearch({
    super.key,
    required this.txtHintValue,
    this.searchEvent,
    this.onChanged,
    this.showShadow = true,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: customTheme.bgColor,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: customTheme.borderLightGray),
        boxShadow: showShadow == true
            ? const [
                BoxShadow(
                  color: Color.fromRGBO(24, 40, 33, 0.05),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: TextFormField(
        autofocus: false,
        onChanged: onChanged,
        controller: controller,
        textAlign: TextAlign.start,
        decoration: InputDecoration(
          hintText: txtHintValue,
          hintStyle: TextStyle(
            fontSize: textTheme.bodyMedium?.fontSize,
            color: customTheme.textLightGray,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: IconButton(
            onPressed: searchEvent,
            icon: Icon(
              Icons.search_outlined,
              size: 24,
              color: customTheme.textLightGray,
            ),
          ),
        ),
      ),
    );
  }
}
