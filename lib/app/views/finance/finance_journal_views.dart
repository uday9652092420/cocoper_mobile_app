import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../custome_widgets/custome_confirmation_dialog.dart';
import '../../helpers/flutter_toast.dart';
import '../../models/finance_journal.dart';
import '../../routes/app_routes.dart';
import '../../services/finance_journal_service.dart';
import '../../services/mobile_app_permissions.dart';
import '../../theme/app_theme.dart';

const _ink = AppColors.textDefaultLight;
const _muted = AppColors.textLightGrayLight;
const _green = AppColors.primaryLight;

String _displayDate(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : DateFormat('dd/MM/yyyy').format(date);
}

String _formatAmount(double value) => NumberFormat('#,##0.00').format(value);

class FinanceJournalListView extends StatefulWidget {
  const FinanceJournalListView({
    super.key,
    required this.sourceType,
  });

  final String sourceType;

  @override
  State<FinanceJournalListView> createState() => _FinanceJournalListViewState();
}

class _FinanceJournalListViewState extends State<FinanceJournalListView> {
  final FinanceJournalService _service = FinanceJournalService();
  List<FinanceJournal> _journals = const [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final journals = await _service.fetchJournals(
        sourceType: widget.sourceType,
      );
      if (!mounted) return;
      setState(() => _journals = journals);
    } on FinanceJournalApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Unable to load finance entries. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canCreate =>
      MobileAppPermissions.current?.isFinanceElevated == true ||
      MobileAppPermissions.current?.hasFinancePermission('create') == true;

  String get _title =>
      widget.sourceType == 'petty-cash' ? 'Petty Cash' : 'Journal Entries';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.pageBackground,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Get.back<void>(),
                      icon: const Icon(Icons.arrow_back_ios_new, color: _ink),
                    ),
                    Expanded(
                      child: Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    if (_canCreate)
                      IconButton(
                        tooltip: 'New entry',
                        onPressed: () async {
                          final changed = await Get.toNamed<dynamic>(
                            Routes.financeJournalForm,
                            arguments: {'sourceType': widget.sourceType},
                          );
                          if (changed == true) await _load();
                        },
                        icon:
                            const Icon(Icons.add_circle_outline, color: _green),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _green,
                  onRefresh: _load,
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _green),
                        )
                      : _error.isNotEmpty
                          ? _errorState()
                          : _journals.isEmpty
                              ? _emptyState()
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: _journals.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, index) =>
                                      _journalCard(_journals[index]),
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: const <Widget>[
          SizedBox(height: 100),
          Icon(Icons.receipt_long_outlined, size: 44, color: _muted),
          SizedBox(height: 12),
          Text(
            'No finance entries found.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      );

  Widget _errorState() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 44, color: _muted),
          const SizedBox(height: 12),
          Text(_error, textAlign: TextAlign.center),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );

  Widget _journalCard(FinanceJournal journal) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () => Get.toNamed<dynamic>(
            Routes.financeJournalDetail,
            arguments: {
              'sourceType': widget.sourceType,
              'journalId': journal.id,
            },
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        journal.voucherNumber.isEmpty
                            ? 'Finance entry'
                            : journal.voucherNumber,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _status(journal.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _displayDate(journal.date),
                  style: const TextStyle(color: _muted),
                ),
                if (journal.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(journal.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Text(
                  '₹${_formatAmount(journal.amount)}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _status(String status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: status == 'Posted'
              ? const Color(0xFFE7F3E4)
              : const Color(0xFFFBEBDD),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          status.isEmpty ? 'Draft' : status,
          style: TextStyle(
            color: status == 'Posted'
                ? AppColors.successLight
                : AppColors.warningLight,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class FinanceJournalFormView extends StatefulWidget {
  const FinanceJournalFormView({
    super.key,
    required this.sourceType,
    this.journalId,
  });

  final String sourceType;
  final String? journalId;

  @override
  State<FinanceJournalFormView> createState() => _FinanceJournalFormViewState();
}

class _FinanceJournalFormViewState extends State<FinanceJournalFormView> {
  final _service = FinanceJournalService();
  final _formKey = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _reference = TextEditingController();
  final _description = TextEditingController();
  final _voucher = TextEditingController();
  final List<_JournalLineEditor> _lines = [];
  List<FinanceAccount> _accounts = const [];
  List<FinanceBranch> _branches = const [];
  String _branchId = '';
  bool _loading = true;
  String _error = '';
  bool _saving = false;

  bool get _isEdit => widget.journalId != null && widget.journalId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _date.dispose();
    _reference.dispose();
    _description.dispose();
    _voucher.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final results = await Future.wait<dynamic>([
        _service.fetchAccounts(),
        _service.fetchBranches(),
        if (_isEdit) _service.fetchJournal(widget.journalId!)
      ]);
      _accounts = results[0] as List<FinanceAccount>;
      final branchResult = results[1] as ({
        List<FinanceBranch> branches,
        String defaultBranchId
      });
      _branches = branchResult.branches;
      _branchId = branchResult.defaultBranchId;
      _date.text = DateFormat('dd/MM/yyyy').format(DateTime.now());

      if (_isEdit) {
        final journal = results[2] as FinanceJournal;
        _voucher.text = journal.voucherNumber;
        _reference.text = journal.reference;
        _description.text = journal.description;
        final date = DateTime.tryParse(journal.date);
        _date.text =
            date == null ? journal.date : DateFormat('dd/MM/yyyy').format(date);
        if (journal.branchId.isNotEmpty) _branchId = journal.branchId;
        for (final line in journal.lines) {
          _lines.add(_JournalLineEditor(
            accounts: _accounts,
            initialAccountId: line.accountId,
            debit: line.debit,
            credit: line.credit,
            narration: line.narration,
          ));
        }
      }
      if (_lines.isEmpty) _lines.add(_JournalLineEditor(accounts: _accounts));
      if (_branchId.isEmpty && _branches.isNotEmpty) {
        _branchId = _branches.first.id;
      }
    } on FinanceJournalApiException catch (error) {
      _error = error.message;
    } on FormatException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Unable to load journal form.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_branchId.isEmpty) {
      await errorToast('Select a branch.');
      return;
    }
    BigInt totalDebit = BigInt.zero;
    BigInt totalCredit = BigInt.zero;
    final lines = <Map<String, dynamic>>[];
    for (final line in _lines) {
      final accountId = line.accountId;
      final debit = line.debit.text.trim();
      final credit = line.credit.text.trim();
      if (accountId == null || accountId.isEmpty) {
        await errorToast('Select an account for every line.');
        return;
      }
      final debitUnits = parseFinanceAmountUnits(debit);
      final creditUnits = parseFinanceAmountUnits(credit);
      if (debitUnits == null || creditUnits == null) {
        await errorToast('Enter valid amounts with up to 4 decimal places.');
        return;
      }
      if (debitUnits == BigInt.zero && creditUnits == BigInt.zero) {
        await errorToast('Every line needs a debit or credit amount.');
        return;
      }
      if (debitUnits > BigInt.zero && creditUnits > BigInt.zero) {
        await errorToast('A line cannot contain both debit and credit.');
        return;
      }
      totalDebit += debitUnits;
      totalCredit += creditUnits;
      lines.add({
        'accountId': accountId,
        'branchId': _branchId,
        'debit': debit.isEmpty ? '0' : debit,
        'credit': credit.isEmpty ? '0' : credit,
        'narration': line.narration.text.trim(),
      });
    }
    if (lines.length < 2) {
      await errorToast('A journal entry needs at least two lines.');
      return;
    }
    if (totalDebit == BigInt.zero || totalDebit != totalCredit) {
      await errorToast('Total debit must equal total credit.');
      return;
    }
    final date = DateFormat('yyyy-MM-dd').format(
      DateFormat('dd/MM/yyyy').parse(_date.text),
    );
    final payload = <String, dynamic>{
      'date': date,
      'sourceType': widget.sourceType,
      'branchId': _branchId,
      'reference': _reference.text.trim(),
      'description': _description.text.trim(),
      'voucherNumber': _voucher.text.trim(),
      'lines': lines,
    };
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _service.updateJournal(widget.journalId!, payload);
      } else {
        await _service.createJournal(payload);
      }
      await successToast(
        _isEdit ? 'Journal entry updated.' : 'Journal entry saved.',
      );
      if (mounted) Get.back(result: true);
    } on FinanceJournalApiException catch (error) {
      await errorToast(error.message);
    } catch (_) {
      await errorToast('Unable to save journal entry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Finance Entry' : 'New Finance Entry'),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Close'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _error.isNotEmpty
              ? _loadError()
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 820),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _fieldCard(),
                                  const SizedBox(height: 12),
                                  ..._lineCards(),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() {
                                      _lines.add(
                                        _JournalLineEditor(accounts: _accounts),
                                      );
                                    }),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add line'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _bottomSave(),
                    ],
                  ),
                ),
    );
  }

  Widget _loadError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: _muted),
              const SizedBox(height: 12),
              Text(_error, textAlign: TextAlign.center),
              TextButton(
                onPressed: _initialize,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _fieldCard() => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _branchId.isEmpty ? null : _branchId,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      items: _branches
                          .map(
                            (branch) => DropdownMenuItem(
                              value: branch.id,
                              child: Text(branch.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _branchId = value ?? ''),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _date,
                      readOnly: true,
                      decoration:
                          const InputDecoration(labelText: 'Entry date'),
                      onTap: _pickDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _voucher,
                decoration: const InputDecoration(labelText: 'Voucher number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reference,
                decoration: const InputDecoration(labelText: 'Reference'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickDate() async {
    final initial =
        DateFormat('dd/MM/yyyy').tryParse(_date.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(
        () => _date.text = DateFormat('dd/MM/yyyy').format(picked),
      );
    }
  }

  List<Widget> _lineCards() => [
        for (var i = 0; i < _lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _JournalLineCard(
            index: i,
            editor: _lines[i],
            onRemove: _lines.length > 2
                ? () => setState(() {
                      _lines[i].dispose();
                      _lines.removeAt(i);
                    })
                : null,
          ),
        ],
      ];

  Widget _bottomSave() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save Changes' : 'Save Entry'),
            ),
          ),
        ),
      );
}

class _JournalLineEditor {
  _JournalLineEditor({
    required this.accounts,
    this.initialAccountId,
    String debit = '',
    String credit = '',
    String narration = '',
  })  : debit = TextEditingController(text: debit),
        credit = TextEditingController(text: credit),
        narration = TextEditingController(text: narration),
        accountId = initialAccountId;

  final List<FinanceAccount> accounts;
  final String? initialAccountId;
  String? accountId;
  final TextEditingController debit;
  final TextEditingController credit;
  final TextEditingController narration;

  void dispose() {
    debit.dispose();
    credit.dispose();
    narration.dispose();
  }
}

class _JournalLineCard extends StatelessWidget {
  const _JournalLineCard({
    required this.index,
    required this.editor,
    this.onRemove,
  });

  final int index;
  final _JournalLineEditor editor;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Line ${index + 1}',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove line',
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.errorLight),
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: editor.accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: editor.accounts
                  .where((account) => account.isActive)
                  .map(
                    (account) => DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(account.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => editor.accountId = value,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Select an account' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: editor.debit,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.]'),
                      ),
                    ],
                    decoration:
                        const InputDecoration(labelText: 'Debit amount'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: editor.credit,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.]'),
                      ),
                    ],
                    decoration:
                        const InputDecoration(labelText: 'Credit amount'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: editor.narration,
              decoration: const InputDecoration(labelText: 'Line narration'),
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceJournalDetailView extends StatefulWidget {
  const FinanceJournalDetailView({
    super.key,
    required this.sourceType,
    required this.journalId,
  });

  final String sourceType;
  final String journalId;

  @override
  State<FinanceJournalDetailView> createState() =>
      _FinanceJournalDetailViewState();
}

class _FinanceJournalDetailViewState extends State<FinanceJournalDetailView> {
  final _service = FinanceJournalService();
  FinanceJournal? _journal;
  bool _loading = true;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final journal = await _service.fetchJournal(widget.journalId);
      if (mounted) setState(() => _journal = journal);
    } on FinanceJournalApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load journal entry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(
      Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await successToast(success);
      await _load();
    } on FinanceJournalApiException catch (error) {
      await errorToast(error.message);
    } catch (_) {
      await errorToast('The action could not be completed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canEdit =>
      MobileAppPermissions.current
          ?.canEditFinanceJournal(_journal?.status ?? '') ==
      true;
  bool get _canDelete =>
      MobileAppPermissions.current
          ?.canDeleteFinanceJournal(_journal?.status ?? '') ==
      true;
  bool get _canPost =>
      MobileAppPermissions.current
          ?.canPostFinanceJournal(_journal?.status ?? '') ==
      true;
  bool get _canReverse =>
      MobileAppPermissions.current
          ?.canReverseFinanceJournal(_journal?.status ?? '') ==
      true;

  @override
  Widget build(BuildContext context) {
    final title = widget.sourceType == 'petty-cash'
        ? 'Petty Cash Details'
        : 'Journal Entry Details';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBackground),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Get.back<void>(),
                      icon: const Icon(Icons.arrow_back_ios_new, color: _ink),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _green),
                      )
                    : _error.isNotEmpty
                        ? _detailError()
                        : _journal == null
                            ? _detailError('Journal entry was not found.')
                            : RefreshIndicator(
                                color: _green,
                                onRefresh: _load,
                                child: _detailContent(),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailError([String? message]) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 44, color: _muted),
          const SizedBox(height: 12),
          Text(message ?? _error, textAlign: TextAlign.center),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );

  Widget _detailContent() {
    final journal = _journal!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journal.voucherNumber.isEmpty
                      ? 'Finance entry'
                      : journal.voucherNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                _detailRow('Date', _displayDate(journal.date)),
                _detailRow('Status', journal.status),
                _detailRow('Reference', journal.reference),
                _detailRow('Description', journal.description),
                _detailRow('Branch', journal.branchName),
                _detailRow('Amount', '₹${_formatAmount(journal.amount)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Journal lines',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in journal.lines) ...[
                  const Divider(height: 16),
                  Text(
                    line.accountName.isNotEmpty
                        ? '${line.accountCode} · ${line.accountName}'
                        : line.accountId,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Debit: ₹${line.debit}',
                            style: const TextStyle(color: _muted)),
                      ),
                      Expanded(
                        child: Text('Credit: ₹${line.credit}',
                            style: const TextStyle(color: _muted)),
                      ),
                    ],
                  ),
                  if (line.narration.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(line.narration,
                          style: const TextStyle(color: _muted)),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_canEdit)
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final changed = await Get.toNamed<dynamic>(
                      Routes.financeJournalForm,
                      arguments: {
                        'sourceType': widget.sourceType,
                        'journalId': journal.id,
                      },
                    );
                    if (changed == true) await _load();
                  },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        if (_canPost)
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _confirmAction(
                      'Post entry',
                      'Post this journal entry?',
                      'Post',
                      () => _runAction(
                        () => _service.postJournal(journal.id),
                        'Journal entry posted.',
                      ),
                    ),
            icon: const Icon(Icons.task_alt),
            label: const Text('Post entry'),
          ),
        if (_canReverse)
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _confirmAction(
                      'Reverse entry',
                      'Reverse this posted journal entry?',
                      'Reverse',
                      () => _runAction(
                        () => _service.reverseJournal(journal.id),
                        'Journal entry reversed.',
                      ),
                    ),
            icon: const Icon(Icons.replay),
            label: const Text('Reverse'),
          ),
        if (_canDelete)
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => _confirmAction(
                      'Delete entry',
                      'Delete this draft journal entry?',
                      'Delete',
                      () => _runAction(
                        () => _service.deleteJournal(journal.id),
                        'Journal entry deleted.',
                      ),
                    ),
            icon: const Icon(Icons.delete_outline, color: AppColors.errorLight),
            label: const Text(
              'Delete',
              style: TextStyle(color: AppColors.errorLight),
            ),
          ),
      ],
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: _muted)),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '-' : value,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _confirmAction(
    String title,
    String body,
    String action,
    Future<void> Function() callback,
  ) =>
      showDialog<void>(
        context: context,
        builder: (_) => CustomConfirmationDialog(
          header: title,
          body: body,
          yesText: action,
          onYes: () {
            Get.back<void>();
            unawaited(callback());
          },
        ),
      );
}
