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
  DateTime? _effectiveTo;
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
    _effectiveFrom = widget.gstRate?.effectiveFrom ?? DateTime.now();
    _effectiveTo = widget.gstRate?.effectiveTo;
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

  void _handleSave() {
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

      final gstRate = GstRate(
        id: widget.gstRate?.id,
        hsnCodeId: _selectedHsnCodeId!,
        cgst: double.parse(_cgstController.text),
        sgst: double.parse(_sgstController.text),
        igst: double.parse(_igstController.text),
        utgst: double.parse(_utgstController.text),
        effectiveFrom: _effectiveFrom!,
        effectiveTo: _effectiveTo,
        isEnabled: _isEnabled,
      );
      widget.onSave(gstRate);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? _effectiveFrom ?? DateTime.now()
          : _effectiveTo ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _effectiveFrom = picked;
        } else {
          _effectiveTo = picked;
        }
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
                    return DropdownButtonFormField<int>(
                      value: _selectedHsnCodeId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                      ),
                      hint: const Text('Select HSN Code'),
                      items: hsnCodes.map((hsn) {
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingM),
                // Dates
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Effective From *',
                            style: TextStyle(fontSize: AppSizes.fontM),
                          ),
                          const SizedBox(height: AppSizes.paddingS),
                          InkWell(
                            onTap: () => _selectDate(context, true),
                            child: Container(
                              padding: const EdgeInsets.all(AppSizes.paddingM),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.divider),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusS,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Effective To',
                            style: TextStyle(fontSize: AppSizes.fontM),
                          ),
                          const SizedBox(height: AppSizes.paddingS),
                          InkWell(
                            onTap: () => _selectDate(context, false),
                            child: Container(
                              padding: const EdgeInsets.all(AppSizes.paddingM),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.divider),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusS,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _effectiveTo != null
                                        ? '${_effectiveTo!.day}/${_effectiveTo!.month}/${_effectiveTo!.year}'
                                        : 'Select date',
                                  ),
                                  const Icon(Icons.calendar_today, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingM),
                Row(
                  children: [
                    Switch(
                      value: _isEnabled,
                      onChanged: (value) {
                        setState(() {
                          _isEnabled = value;
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: AppSizes.paddingS),
                    const Text('Enabled'),
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
      ),
    );
  }
}
