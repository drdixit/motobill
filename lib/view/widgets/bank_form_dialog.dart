import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../model/bank.dart';
import '../../view_model/bank_viewmodel.dart';

class BankFormDialog extends ConsumerStatefulWidget {
  final Bank? bank;
  final int companyId;

  const BankFormDialog({super.key, this.bank, required this.companyId});

  @override
  ConsumerState<BankFormDialog> createState() => _BankFormDialogState();
}

class _BankFormDialogState extends ConsumerState<BankFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _holderController;
  late TextEditingController _accountController;
  late TextEditingController _ifscController;
  late TextEditingController _bankNameController;
  late TextEditingController _branchController;

  @override
  void initState() {
    super.initState();
    _holderController = TextEditingController(
      text: widget.bank?.accountHolderName ?? '',
    );
    _accountController = TextEditingController(
      text: widget.bank?.accountNumber ?? '',
    );
    _ifscController = TextEditingController(text: widget.bank?.ifscCode ?? '');
    _bankNameController = TextEditingController(
      text: widget.bank?.bankName ?? '',
    );
    _branchController = TextEditingController(
      text: widget.bank?.branchName ?? '',
    );
  }

  @override
  void dispose() {
    _holderController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = await ref.read(bankRepositoryProvider.future);

    final bank = Bank(
      id: widget.bank?.id,
      accountHolderName: _holderController.text.trim(),
      accountNumber: _accountController.text.trim(),
      ifscCode: _ifscController.text.trim().isEmpty
          ? null
          : _ifscController.text.trim(),
      bankName: _bankNameController.text.trim().isEmpty
          ? null
          : _bankNameController.text.trim(),
      branchName: _branchController.text.trim().isEmpty
          ? null
          : _branchController.text.trim(),
      companyId: widget.companyId,
      isEnabled: true,
      isDeleted: false,
    );

    try {
      if (widget.bank == null) {
        await repository.createBank(bank);
      } else {
        await repository.updateBank(bank);
      }
      // Invalidate provider for this company so UI refreshes
      ref.invalidate(bankByCompanyProvider(widget.companyId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank information saved'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving bank: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.bank == null ? 'Add Bank Account' : 'Edit Bank Account',
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 520,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _holderController,
                  decoration: const InputDecoration(
                    labelText: 'Account Holder Name *',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSizes.paddingS),
                TextFormField(
                  controller: _accountController,
                  decoration: const InputDecoration(
                    labelText: 'Account Number *',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSizes.paddingS),
                TextFormField(
                  controller: _ifscController,
                  decoration: const InputDecoration(labelText: 'IFSC Code'),
                ),
                const SizedBox(height: AppSizes.paddingS),
                TextFormField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                ),
                const SizedBox(height: AppSizes.paddingS),
                TextFormField(
                  controller: _branchController,
                  decoration: const InputDecoration(labelText: 'Branch Name'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
