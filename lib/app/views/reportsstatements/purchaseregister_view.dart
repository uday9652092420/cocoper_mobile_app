import 'package:flutter/material.dart';

import '../../models/statements_report.dart';
import 'statements_report_view.dart';

class PurchaseRegisterView extends StatelessWidget {
  const PurchaseRegisterView({super.key});

  @override
  Widget build(BuildContext context) => const StatementsReportView(
        type: StatementsReportType.purchaseRegister,
      );
}
