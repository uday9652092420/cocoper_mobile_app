// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/loading&dispatch/loading_dispatch_controller.dart';
import '../../models/loading_dispatch.dart';
import '../../routes/app_routes.dart';

const _ink = Color(0xFF14342B);
const _muted = Color(0xFF5C6B66);
const _line = Color(0xFFE4EBE4);
const _green = Color(0xFF2D8135);

class ViewLoadingDispatchView extends StatefulWidget {
  const ViewLoadingDispatchView({
    super.key,
    required this.dispatchId,
  });

  final String dispatchId;

  @override
  State<ViewLoadingDispatchView> createState() =>
      _ViewLoadingDispatchViewState();
}

class _ViewLoadingDispatchViewState extends State<ViewLoadingDispatchView> {
  final LoadingDispatchController _controller =
      Get.find<LoadingDispatchController>();
  bool _wasEdited = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadLookups());
    unawaited(_controller.loadDispatchById(widget.dispatchId));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE9F3E6), Color(0xFFFDFEFC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: Obx(() {
                    if (_controller.isLoadingDetail.value) {
                      return const Center(
                        child: CircularProgressIndicator(color: _green),
                      );
                    }
                    if (_controller.detailError.value.isNotEmpty) {
                      return _errorState(_controller.detailError.value);
                    }
                    final dispatch = _controller.detail.value;
                    if (dispatch == null) {
                      return _errorState('Loading dispatch was not found.');
                    }
                    return _content(dispatch);
                  }),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Get.back<bool>(result: _wasEdited),
              icon: const Icon(Icons.arrow_back_ios_new, color: _ink),
            ),
            const Expanded(
              child: Text(
                'Dispatch Details',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            Obx(() {
              final dispatch = _controller.detail.value;
              if (dispatch == null || dispatch.id.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Edit',
                onPressed: () async {
                  final result = await Get.toNamed<bool>(
                    Routes.editLoadingDispatch,
                    arguments: dispatch.id,
                  );
                  if (result == true) {
                    _wasEdited = true;
                    await _controller.loadDispatchById(dispatch.id);
                  }
                },
                icon: const Icon(Icons.edit_outlined, color: _green),
              );
            }),
          ],
        ),
      );

  Widget _errorState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 38,
                color: Color(0xFFB3261E),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              TextButton(
                onPressed: () =>
                    _controller.loadDispatchById(widget.dispatchId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _content(LoadingDispatch dispatch) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _card(
                  children: [
                    _row('Dispatch Number', dispatch.dispatchNumber),
                    _row(
                      'Customer',
                      _controller.customerName(dispatch.customerId),
                    ),
                    _row('Lorry Number', dispatch.lorryNumber),
                    _row('Driver Name', dispatch.driverName),
                    _row('Driver Mobile', dispatch.driverMobile),
                    _row('Status', dispatch.dispatchStatus),
                    if (dispatch.dispatchDate.isNotEmpty)
                      _row('Dispatch Date', _displayDate(dispatch.dispatchDate)),
                    _row(
                      'Invoice Generated',
                      dispatch.invoiceGenerated ? 'Yes' : 'No',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _card(
                  children: [
                    const Text(
                      'Loading Lines',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (dispatch.lines.isEmpty)
                      const Text(
                        'No loading lines.',
                        style: TextStyle(color: _muted),
                      )
                    else
                      for (var index = 0; index < dispatch.lines.length; index++)
                        _lineCard(index, dispatch.lines[index]),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _lineCard(int index, LoadingDispatchLine line) => Container(
        width: double.infinity,
        margin: EdgeInsets.only(
          bottom: index == _controller.detail.value!.lines.length - 1 ? 0 : 10,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBF9),
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Line ${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 7),
            _row('Branch', _controller.branchName(line.branchId)),
            _row('Date', _displayDate(line.date)),
            _row('Item', _controller.itemName(line.itemId)),
            _row('Gunny Bag (Bharathi)', line.bharthi),
            _row('Quantity', NumberFormat('#,##0.###').format(line.quantity)),
          ],
        ),
      );

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: Text(label, style: const TextStyle(color: _muted)),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('dd/MM/yyyy').format(parsed);
  }
}
