import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';

import '../theme/app_theme.dart';
import 'custome_star_lable.dart';

class CustomeDropdownForm extends StatelessWidget {
  final String label;
  final List<dynamic> items;
  final String? selectedKey;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final bool isRequired;

  const CustomeDropdownForm({
    super.key,
    required this.label,
    required this.items,
    this.selectedKey,
    required this.onChanged,
    this.hintText,
    this.errorText,
    this.validator,
    this.enabled = true,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = CustomTheme.of(context);
    final validKeys = items.map(_itemKey).toSet();
    final value = validKeys.contains(selectedKey) ? selectedKey : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: customTheme.textDefault,
                  ),
                ),
              ),
              if (isRequired) const CustomeStarLable(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          validator: enabled ? validator : null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          dropdownColor: customTheme.bgColor,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: customTheme.textDefault,
          ),
          decoration: InputDecoration(
            hintText: hintText ?? 'select_options'.tr,
            errorText: errorText,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: _itemKey(item),
                  child: Text(
                    _itemLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  String _itemKey(dynamic item) {
    if (item is! Map || item.isEmpty) {
      throw ArgumentError.value(
        item,
        'items',
        'Each dropdown item must be a non-empty map.',
      );
    }
    return item.keys.first.toString();
  }

  String _itemLabel(dynamic item) {
    if (item is! Map || item.isEmpty) {
      throw ArgumentError.value(
        item,
        'items',
        'Each dropdown item must be a non-empty map.',
      );
    }
    return item.values.first.toString();
  }
}
