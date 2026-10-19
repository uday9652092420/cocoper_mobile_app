import 'package:flutter/material.dart';

import '../../models/statements_report.dart';
import 'statements_report_view.dart';

class SupplierStatementView extends StatelessWidget {
  const SupplierStatementView({super.key});

  @override
  Widget build(BuildContext context) => const StatementsReportView(
        type: StatementsReportType.supplierStatement,
      );
}
