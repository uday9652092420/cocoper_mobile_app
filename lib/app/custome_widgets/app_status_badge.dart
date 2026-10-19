import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.status,
    this.emptyLabel = 'Unknown',
  });

  final String status;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final label = status.trim().isEmpty ? emptyLabel : status.trim();
    final colors = _colorsFor(label);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  _StatusColors _colorsFor(String value) {
    final status = value.toLowerCase();
    if (const {
      'approved',
      'completed',
      'complete',
      'dispatched',
      'received',
      'paid',
      'success',
      'true',
    }.contains(status)) {
      return const _StatusColors(
        foreground: AppColors.successLight,
        background: Color(0xFFE7F3EC),
      );
    }
    if (const {'invoiced', 'processing', 'in progress'}.contains(status)) {
      return const _StatusColors(
        foreground: AppColors.blue,
        background: Color(0xFFEAF4FF),
      );
    }
    if (const {'rejected', 'cancelled', 'canceled', 'failed', 'void'}.contains(
      status,
    )) {
      return const _StatusColors(
        foreground: AppColors.errorLight,
        background: Color(0xFFFFEEEC),
      );
    }
    if (const {'draft', 'pending', 'unknown', 'false'}.contains(status)) {
      return const _StatusColors(
        foreground: AppColors.warningLight,
        background: Color(0xFFFFF4E5),
      );
    }
    return const _StatusColors(
      foreground: AppColors.textLightGrayLight,
      background: AppColors.scaffoldBackground,
    );
  }
}

class _StatusColors {
  const _StatusColors({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}
