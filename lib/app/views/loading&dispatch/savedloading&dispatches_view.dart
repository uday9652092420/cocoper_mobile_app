// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/loading&dispatch/loading_dispatch_controller.dart';
import '../../models/loading_dispatch.dart';
import '../../routes/app_routes.dart';

const _ink = Color(0xFF14342B);
const _muted = Color(0xFF5C6B66);
const _line = Color(0xFFE4EBE4);
const _green = Color(0xFF2D8135);

class SavedLoadingDispatchesView extends StatefulWidget {
  const SavedLoadingDispatchesView({super.key});

  @override
  State<SavedLoadingDispatchesView> createState() =>
      _SavedLoadingDispatchesViewState();
}

class _SavedLoadingDispatchesViewState
    extends State<SavedLoadingDispatchesView> {
  final LoadingDispatchController _controller =
      Get.find<LoadingDispatchController>();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadLookups());
    unawaited(_controller.loadDispatches());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      _controller.refreshDispatches(),
      _controller.loadLookups(),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE9F3E6), Color(0xFFFDFEFC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 20),
                      _newDispatchButton(),
                      const SizedBox(height: 16),
                      _searchBar(),
                      const SizedBox(height: 22),
                      _dispatchList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _header() => Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Get.back<void>(),
            icon: const Icon(Icons.arrow_back_ios_new, color: _ink),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loading & Dispatch',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Saved loading dispatches',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: _muted),
          ),
        ],
      );

  Widget _newDispatchButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final result = await Get.toNamed<bool>(Routes.newLoadingDispatch);
            if (result == true) await _controller.refreshDispatches();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text(
            'Add New Dispatch',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      );

  Widget _searchBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 19, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (value) => _controller.searchQuery.value = value,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search dispatch, customer, lorry, or driver',
                  hintStyle: TextStyle(fontSize: 13.5, color: _muted),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            Obx(
              () => _controller.searchQuery.value.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        _controller.searchQuery.value = '';
                      },
                      icon: const Icon(Icons.close, size: 18, color: _muted),
                    ),
            ),
          ],
        ),
      );

  Widget _dispatchList() => Obx(() {
        if (_controller.isLoadingList.value &&
            _controller.dispatches.isEmpty) {
          return _stateCard(
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator(color: _green)),
            ),
          );
        }
        if (_controller.hasListError.value) {
          return _stateCard(
            Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 38,
                  color: Color(0xFFB3261E),
                ),
                const SizedBox(height: 8),
                Text(_controller.listError.value, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _controller.refreshDispatches,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final records = _controller.filteredDispatches;
        if (records.isEmpty) {
          final searched = _controller.searchQuery.value.isNotEmpty;
          return _stateCard(
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(
                    searched ? Icons.search_off : Icons.local_shipping_outlined,
                    size: 36,
                    color: _muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    searched
                        ? 'No dispatches match your search.'
                        : 'No saved dispatches.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final dispatch in records) ...[
              _dispatchCard(dispatch),
              const SizedBox(height: 10),
            ],
          ],
        );
      });

  Widget _dispatchCard(LoadingDispatch dispatch) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openView(dispatch.id),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        dispatch.dispatchNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    _status(dispatch.dispatchStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _controller.customerName(dispatch.customerId),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 5),
                _info('Lorry', dispatch.lorryNumber),
                _info('Driver', dispatch.driverName),
                _info('Mobile', dispatch.driverMobile),
                const Divider(height: 20, color: _line),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openView(dispatch.id),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View'),
                    ),
                    TextButton.icon(
                      onPressed: () => _openEdit(dispatch.id),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: _controller.actionInProgressId.value.isEmpty
                          ? () => _confirmDelete(dispatch)
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB3261E),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _openView(String id) async {
    final result = await Get.toNamed<bool>(
      Routes.viewLoadingDispatch,
      arguments: id,
    );
    if (result == true) await _controller.refreshDispatches();
  }

  Future<void> _openEdit(String id) async {
    final result = await Get.toNamed<bool>(
      Routes.editLoadingDispatch,
      arguments: id,
    );
    if (result == true) await _controller.refreshDispatches();
  }

  Future<void> _confirmDelete(LoadingDispatch dispatch) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete dispatch?'),
        content: Text(
          'Delete ${dispatch.dispatchNumber} and its loading lines? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.deleteDispatch(dispatch);
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(label, style: const TextStyle(color: _muted)),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(color: _ink),
              ),
            ),
          ],
        ),
      );

  Widget _status(String status) {
    final dispatched = status.toLowerCase() == 'dispatched';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: dispatched ? const Color(0xFFE7F3E4) : const Color(0xFFFDF2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty ? 'Draft' : status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: dispatched ? _green : const Color(0xFF8A5B00),
        ),
      ),
    );
  }

  Widget _stateCard(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}
