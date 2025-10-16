import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../model/hsn_code.dart';
import '../../view_model/hsn_code_viewmodel.dart';

class HsnCodeFormDialog extends ConsumerStatefulWidget {
  final HsnCode? hsnCode;
  final Function(HsnCode) onSave;

  const HsnCodeFormDialog({super.key, this.hsnCode, required this.onSave});

  @override
  ConsumerState<HsnCodeFormDialog> createState() => _HsnCodeFormDialogState();
}

class _HsnCodeFormDialogState extends ConsumerState<HsnCodeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _descriptionController;
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.hsnCode?.code ?? '');
    _descriptionController = TextEditingController(
      text: widget.hsnCode?.description ?? '',
    );
    _isEnabled = widget.hsnCode?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final code = _codeController.text.trim();

      // Check for duplicate HSN code (both when creating and updating)
      final existingHsnCode = await ref
          .read(hsnCodeRepositoryProvider.future)
          .then((repo) => repo.getHsnCodeByCode(code));

      if (existingHsnCode != null) {
        // If updating, check if the existing code belongs to a different record
        if (widget.hsnCode != null &&
            existingHsnCode.id != widget.hsnCode!.id) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'HSN Code "$code" already exists. Please use a different code.',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        // If creating new, any existing code is a duplicate
        else if (widget.hsnCode == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'HSN Code "$code" already exists. Please use a different code.',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      final hsnCode = HsnCode(
        id: widget.hsnCode?.id,
        code: code,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isEnabled: _isEnabled,
      );
      widget.onSave(hsnCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.hsnCode == null ? 'New HSN Code' : 'Edit HSN Code',
                style: const TextStyle(
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'HSN Code *',
                  hintText: 'e.g., 8708',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'HSN Code is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Parts and accessories of motor vehicles',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppSizes.paddingM),
              // Enabled switch - Commented out: HSN Codes are always enabled
              // Row(
              //   children: [
              //     Switch(
              //       value: _isEnabled,
              //       onChanged: (value) {
              //         setState(() {
              //           _isEnabled = value;
              //         });
              //       },
              //       activeColor: AppColors.primary,
              //     ),
              //     const SizedBox(width: AppSizes.paddingS),
              //     const Text('Enabled'),
              //   ],
              // ),
              const SizedBox(height: AppSizes.paddingL),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingL,
                        vertical: AppSizes.paddingM,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
