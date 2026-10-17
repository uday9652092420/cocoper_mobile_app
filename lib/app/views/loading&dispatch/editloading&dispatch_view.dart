// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'loading_dispatch_form.dart';

class EditLoadingDispatchView extends StatelessWidget {
  const EditLoadingDispatchView({
    super.key,
    required this.dispatchId,
  });

  final String dispatchId;

  @override
  Widget build(BuildContext context) => LoadingDispatchFormView(
        isEdit: true,
        dispatchId: dispatchId,
      );
}
