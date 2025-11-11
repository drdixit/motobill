import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../model/hsn_code.dart';
import '../../view_model/hsn_code_viewmodel.dart';
import '../../view_model/gst_rate_viewmodel.dart';

class HsnCodeFormDialog extends ConsumerStatefulWidget {
  final HsnCode? hsnCode;
  // Pass back HSN code and optional GST rate data
  final Function(HsnCode, dynamic gstRate) onSave;

  const HsnCodeFormDialog({super.key, this.hsnCode, required this.onSave});

  @override
  ConsumerState<HsnCodeFormDialog> createState() => _HsnCodeFormDialogState();
}

class _HsnCodeFormDialogState extends ConsumerState<HsnCodeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _descriptionController;
  // GST controllers
  late TextEditingController _cgstController;
  late TextEditingController _sgstController;
  late TextEditingController _igstController;
  late TextEditingController _utgstController;
  DateTime? _effectiveFrom;
  late bool _isEnabled;
  int? _editingGstId;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.hsnCode?.code ?? '');
    _descriptionController = TextEditingController(
      text: widget.hsnCode?.description ?? '',
    );
    _cgstController = TextEditingController(text: '');
    _sgstController = TextEditingController(text: '');
    _igstController = TextEditingController(text: '');
    _utgstController = TextEditingController(text: '0.0');
    // Default effectiveFrom to yesterday
    _effectiveFrom = DateTime.now().subtract(const Duration(days: 1));
    _isEnabled = widget.hsnCode?.isEnabled ?? true;

    // If editing an existing HSN, load existing GST rate (if any) and pre-fill fields
    if (widget.hsnCode != null && widget.hsnCode!.id != null) {
      // Use repository provider to fetch existing GST rate for this HSN
      ref.read(gstRateRepositoryProvider.future).then((repo) async {
        final existing = await repo.getGstRateByHsnCodeId(widget.hsnCode!.id!);
        if (existing != null) {
          if (!mounted) return;
          setState(() {
            _editingGstId = existing.id;
            _cgstController.text = existing.cgst.toString();
            _sgstController.text = existing.sgst.toString();
            _igstController.text = existing.igst.toString();
            _utgstController.text = existing.utgst.toString();
            _effectiveFrom = existing.effectiveFrom;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _cgstController.dispose();
    _sgstController.dispose();
    _igstController.dispose();
    _utgstController.dispose();
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
      // Prepare optional GST rate object if user filled GST fields
      dynamic gstRate;
      final cgst = double.tryParse(_cgstController.text);
      final sgst = double.tryParse(_sgstController.text);
      final igst = double.tryParse(_igstController.text);
      final utgst = double.tryParse(_utgstController.text) ?? 0.0;

      // CGST, SGST, IGST are required fields now — ensure they are present
      if (cgst == null || sgst == null || igst == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CGST, SGST and IGST are required'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Validate that CGST + SGST = IGST
      final sumCgstSgst = cgst + sgst;
      if ((sumCgstSgst - igst).abs() > 0.01) {
        // Allow small floating point difference
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'CGST + SGST must equal IGST/UTGST. Currently: $cgst + $sgst = $sumCgstSgst, but IGST/UTGST = $igst',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      if (_effectiveFrom == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select Effective From date (must be in the past)',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Build a lightweight map to pass gst values; the caller will convert to model and set hsn id
      gstRate = {
        'id': _editingGstId,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'utgst': utgst,
        'effectiveFrom': _effectiveFrom,
      };

      widget.onSave(hsnCode, gstRate);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom ?? yesterday,
      firstDate: DateTime(2000),
      lastDate: yesterday,
    );
    if (picked != null) {
      setState(() {
        _effectiveFrom = picked;
      });
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'HSN Code is required';
                  }
                  final v = value.trim();
                  final digitsOnly = RegExp(r'^\d+$');
                  if (!digitsOnly.hasMatch(v)) {
                    return 'HSN Code must contain digits only';
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
              // GST fields - optional but validated if provided
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cgstController,
                      decoration: InputDecoration(
                        labelText: 'CGST % *',
                        hintText: '9.0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'CGST is required';
                        final rate = double.tryParse(value);
                        if (rate == null || rate < 0 || rate > 100)
                          return 'Enter valid rate (0-100)';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Expanded(
                    child: TextFormField(
                      controller: _sgstController,
                      decoration: InputDecoration(
                        labelText: 'SGST % *',
                        hintText: '9.0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'SGST is required';
                        final rate = double.tryParse(value);
                        if (rate == null || rate < 0 || rate > 100)
                          return 'Enter valid rate (0-100)';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingM),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _igstController,
                      decoration: InputDecoration(
                        labelText: 'IGST/UTGST % *',
                        hintText: '18.0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'IGST is required';
                        final rate = double.tryParse(value);
                        if (rate == null || rate < 0 || rate > 100)
                          return 'Enter valid rate (0-100)';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Expanded(
                    child: TextFormField(
                      controller: _utgstController,
                      decoration: InputDecoration(
                        labelText: 'CESS %',
                        hintText: '0.0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final rate = double.tryParse(value);
                        if (rate == null || rate < 0 || rate > 100)
                          return 'Enter valid rate (0-100)';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingM),
              // Effective From Date (past dates only)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Effective From (Must be a past date) *',
                    style: TextStyle(fontSize: AppSizes.fontM),
                  ),
                  const SizedBox(height: AppSizes.paddingS),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.paddingM),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _effectiveFrom != null
                                ? '${_effectiveFrom!.day}/${_effectiveFrom!.month}/${_effectiveFrom!.year}'
                                : 'Select date',
                          ),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
