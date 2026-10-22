import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ProfitLossStatementView extends StatelessWidget {
  const ProfitLossStatementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDefaultLight,
        elevation: 0,
        title: const Text(
          'Profit & Loss Statement',
          style: TextStyle(fontSize: 18),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_chart_outlined_rounded,
                size: 56,
                color: AppColors.primaryLight,
              ),
              SizedBox(height: 16),
              Text(
                'Profit & Loss report is not available yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDefaultLight,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'A verified Profit & Loss report API is needed to show '
                'accurate income, expenses and net profit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textLightGrayLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
