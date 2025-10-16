import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../model/gst_rate.dart';
import '../../view_model/gst_rate_viewmodel.dart';

class GstRateFormDialog extends ConsumerStatefulWidget {
  final GstRate? gstRate;
  final int? initialHsnCodeId;
  final Function(GstRate) onSave;

  const GstRateFormDialog({
    super.key,
    this.gstRate,
    this.initialHsnCodeId,
    required this.onSave,
  });

  @override
  ConsumerState<GstRateFormDialog> createState() => _GstRateFormDialogState();
}

class _GstRateFormDialogState extends ConsumerState<GstRateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _cgstController;
  late TextEditingController _sgstController;
  late TextEditingController _igstController;
  late TextEditingController _utgstController;
  int? _selectedHsnCodeId;
  DateTime? _effectiveFrom;
  // _effectiveTo removed - GST rates are always effective (no end date)
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _cgstController = TextEditingController(
      text: widget.gstRate?.cgst.toString() ?? '',
    );
    _sgstController = TextEditingController(
      text: widget.gstRate?.sgst.toString() ?? '',
    );
    _igstController = TextEditingController(
      text: widget.gstRate?.igst.toString() ?? '',
    );
    _utgstController = TextEditingController(
      text: widget.gstRate?.utgst.toString() ?? '0.0',
    );
    _selectedHsnCodeId = widget.gstRate?.hsnCodeId ?? widget.initialHsnCodeId;
    // Effective from must be in the past, default to yesterday
    _effectiveFrom =
        widget.gstRate?.effectiveFrom ??
        DateTime.now().subtract(const Duration(days: 1));
    // Effective to is always null - GST rates are always effective (no need to store it)
    _isEnabled = widget.gstRate?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _cgstController.dispose();
    _sgstController.dispose();
    _igstController.dispose();
    _utgstController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedHsnCodeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an HSN Code'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Check for duplicate HSN code (only when creating new GST rate)
      if (widget.gstRate == null) {
        final existingGstRate = await ref
            .read(gstRateRepositoryProvider.future)
            .then((repo) => repo.getGstRateByHsnCodeId(_selectedHsnCodeId!));

        if (existingGstRate != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'GST rate already exists for this HSN Code. Please edit the existing rate instead.',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }

      final gstRate = GstRate(
        id: widget.gstRate?.id,
        hsnCodeId: _selectedHsnCodeId!,
        cgst: double.parse(_cgstController.text),
        sgst: double.parse(_sgstController.text),
        igst: double.parse(_igstController.text),
        utgst: double.parse(_utgstController.text),
        effectiveFrom: _effectiveFrom!,
        effectiveTo: null, // Always null - GST rates are always effective
        isEnabled: _isEnabled,
      );
      widget.onSave(gstRate);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom ?? yesterday,
      firstDate: DateTime(2000),
      lastDate: yesterday, // Cannot select today or future dates
    );
    if (picked != null) {
      setState(() {
        _effectiveFrom = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hsnCodesAsync = ref.watch(hsnCodesForGstProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.gstRate == null ? 'New GST Rate' : 'Edit GST Rate',
                  style: const TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingL),
                // HSN Code Dropdown
                const Text(
                  'HSN Code *',
                  style: TextStyle(fontSize: AppSizes.fontL),
                ),
                const SizedBox(height: AppSizes.paddingS),
                hsnCodesAsync.when(
                  data: (hsnCodes) {
                    if (hsnCodes.isEmpty) {
                      return const Text(
                        'No HSN codes available',
                        style: TextStyle(color: AppColors.error),
                      );
                    }

                    // Use FutureBuilder to filter HSN codes asynchronously when creating new
                    if (widget.gstRate == null) {
                      return FutureBuilder<List<int>>(
                        future: ref
                            .read(gstRateRepositoryProvider.future)
                            .then((repo) => repo.getHsnCodeIdsWithGstRates()),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }

                          if (snapshot.hasError) {
                            return Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: AppColors.error),
                            );
                          }

                          final hsnCodesWithGstRates = snapshot.data ?? [];
                          final availableHsnCodes = hsnCodes
                              .where(
                                (hsn) => !hsnCodesWithGstRates.contains(hsn.id),
                              )
                              .toList();

                          if (availableHsnCodes.isEmpty) {
                            return const Text(
                              'All HSN codes already have GST rates',
                              style: TextStyle(color: AppColors.error),
                            );
                          }

                          // Validate that selected value exists in list
                          final validHsnCodeId =
                              _selectedHsnCodeId != null &&
                                  availableHsnCodes.any(
                                    (hsn) => hsn.id == _selectedHsnCodeId,
                                  )
                              ? _selectedHsnCodeId
                              : null;

                          return DropdownButtonFormField<int>(
                            value: validHsnCodeId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusS,
                                ),
                              ),
                            ),
                            hint: const Text('Select HSN Code'),
                            items: availableHsnCodes.map((hsn) {
                              return DropdownMenuItem<int>(
                                value: hsn.id,
                                child: Text(
                                  '${hsn.code} - ${hsn.description ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedHsnCodeId = value;
                              });
                            },
                          );
                        },
                      );
                    }

                    // When editing, show selected HSN code but disable dropdown
                    final selectedHsnCode = hsnCodes.firstWhere(
                      (hsn) => hsn.id == _selectedHsnCodeId,
                      orElse: () => hsnCodes.first,
                    );

                    return Container(
                      padding: const EdgeInsets.all(AppSizes.paddingM),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        color: Colors.grey[100],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${selectedHsnCode.code} - ${selectedHsnCode.description ?? ''}',
                              style: const TextStyle(
                                fontSize: AppSizes.fontM,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const Icon(Icons.lock, size: 20, color: Colors.grey),
                        ],
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text(
                    'Error: $error',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),
                // GST Rates
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cgstController,
                        decoration: InputDecoration(
                          labelText: 'CGST % *',
                          hintText: '9.0',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
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
                          if (value == null || value.trim().isEmpty) {
                            return 'CGST is required';
                          }
                          final rate = double.tryParse(value);
                          if (rate == null || rate < 0 || rate > 100) {
                            return 'Enter valid rate (0-100)';
                          }
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
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
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
                          if (value == null || value.trim().isEmpty) {
                            return 'SGST is required';
                          }
                          final rate = double.tryParse(value);
                          if (rate == null || rate < 0 || rate > 100) {
                            return 'Enter valid rate (0-100)';
                          }
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
                          labelText: 'IGST % *',
                          hintText: '18.0',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
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
                          if (value == null || value.trim().isEmpty) {
                            return 'IGST is required';
                          }
                          final rate = double.tryParse(value);
                          if (rate == null || rate < 0 || rate > 100) {
                            return 'Enter valid rate (0-100)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: TextFormField(
                        controller: _utgstController,
                        decoration: InputDecoration(
                          labelText: 'UTGST %',
                          hintText: '0.0',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
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
                          if (value == null || value.trim().isEmpty) {
                            return null; // UTGST is optional
                          }
                          final rate = double.tryParse(value);
                          if (rate == null || rate < 0 || rate > 100) {
                            return 'Enter valid rate (0-100)';
                          }
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
                      'Effective From * (Must be a past date)',
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
                const SizedBox(height: AppSizes.paddingM),
                // Enabled switch - Commented out: GST Rates are always enabled
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
      ),
    );
  }
}
