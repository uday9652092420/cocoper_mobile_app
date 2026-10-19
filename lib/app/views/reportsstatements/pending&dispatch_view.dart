import 'package:flutter/material.dart';

import '../../models/statements_report.dart';
import 'statements_report_view.dart';

class PendingDispatchView extends StatelessWidget {
  const PendingDispatchView({super.key});

  @override
  Widget build(BuildContext context) => const StatementsReportView(
        type: StatementsReportType.pendingDispatch,
      );
}
// ignore_for_file: file_names
