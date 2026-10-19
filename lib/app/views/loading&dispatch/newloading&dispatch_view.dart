// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'loading_dispatch_form.dart';

class NewLoadingDispatchView extends StatelessWidget {
  const NewLoadingDispatchView({super.key});

  @override
  Widget build(BuildContext context) =>
      const LoadingDispatchFormView(isEdit: false);
}
