import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/vendor.dart';

class VendorFormDialog extends StatefulWidget {
  final Vendor? vendor; // Null for create, non-null for edit
  final Function(Vendor) onSave;

  const VendorFormDialog({super.key, this.vendor, required this.onSave});

  @override
  State<VendorFormDialog> createState() => _VendorFormDialogState();
}

class _VendorFormDialogState extends State<VendorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _legalNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _gstNumberController;
  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.vendor?.name ?? '');
    _legalNameController = TextEditingController(
      text: widget.vendor?.legalName ?? '',
    );
    _phoneController = TextEditingController(text: widget.vendor?.phone ?? '');
    _emailController = TextEditingController(text: widget.vendor?.email ?? '');
    _gstNumberController = TextEditingController(
      text: widget.vendor?.gstNumber ?? '',
    );
    _addressLine1Controller = TextEditingController(
      text: widget.vendor?.addressLine1 ?? '',
    );
    _addressLine2Controller = TextEditingController(
      text: widget.vendor?.addressLine2 ?? '',
    );
    _cityController = TextEditingController(text: widget.vendor?.city ?? '');
    _stateController = TextEditingController(text: widget.vendor?.state ?? '');
    _pincodeController = TextEditingController(
      text: widget.vendor?.pincode ?? '',
    );
    _isEnabled = widget.vendor?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _legalNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstNumberController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final vendor = Vendor(
        id: widget.vendor?.id,
        name: _nameController.text.trim(),
        legalName: _legalNameController.text.trim().isEmpty
            ? null
            : _legalNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        gstNumber: _gstNumberController.text.trim().isEmpty
            ? null
            : _gstNumberController.text.trim().toUpperCase(),
        addressLine1: _addressLine1Controller.text.trim().isEmpty
            ? null
            : _addressLine1Controller.text.trim(),
        addressLine2: _addressLine2Controller.text.trim().isEmpty
            ? null
            : _addressLine2Controller.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
        pincode: _pincodeController.text.trim().isEmpty
            ? null
            : _pincodeController.text.trim(),
        isEnabled: _isEnabled,
      );
      widget.onSave(vendor);
    }
  }

  String? _validateGstNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      // GST is optional, so empty is valid
      return null;
    }

    final gst = value.trim().toUpperCase();

    // GST must be exactly 15 characters
    if (gst.length != 15) {
      return 'GST number must be 15 characters';
    }

    // Validate GST format: ##AAAAA####A#A#
    // First 2 characters: digits (state code)
    if (!RegExp(r'^\d{2}').hasMatch(gst)) {
      return 'Invalid GST: First 2 characters must be digits (state code)';
    }

    // Next 10 characters: PAN format (5 letters + 4 digits + 1 letter)
    final pan = gst.substring(2, 12);
    if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(pan)) {
      return 'Invalid GST: Characters 3-12 must be valid PAN format';
    }

    // 13th character: entity number (1-9, A-Z)
    if (!RegExp(r'^[1-9A-Z]$').hasMatch(gst[12])) {
      return 'Invalid GST: 13th character must be 1-9 or A-Z';
    }

    // 14th character: must be 'Z'
    if (gst[13] != 'Z') {
      return 'Invalid GST: 14th character must be Z';
    }

    // 15th character: check digit (alphanumeric)
    if (!RegExp(r'^[0-9A-Z]$').hasMatch(gst[14])) {
      return 'Invalid GST: 15th character must be alphanumeric';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.vendor == null ? 'New Vendor' : 'Edit Vendor',
                  style: TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            // Form
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Name *',
                        hint: 'Name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _legalNameController,
                        label: 'Legal Name',
                        hint: 'Legal Name',
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Mobile Number',
                        hint: 'Mobile Number',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _gstNumberController,
                        label: 'GST Number',
                        hint: 'GST Number',
                        validator: _validateGstNumber,
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _addressLine1Controller,
                        label: 'Address Line 1',
                        hint: 'Address Line 1',
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _addressLine2Controller,
                        label: 'Address Line 2',
                        hint: 'Address Line 2',
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        hint: 'City',
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _stateController,
                        label: 'State',
                        hint: 'State',
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _pincodeController,
                        label: 'Pincode',
                        hint: 'Pincode',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Enabled checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _isEnabled,
                            onChanged: (value) {
                              setState(() {
                                _isEnabled = value ?? true;
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                          Text(
                            'Enabled',
                            style: TextStyle(
                              fontSize: AppSizes.fontM,
                              color: AppColors.textPrimary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingL,
                      vertical: AppSizes.paddingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        const SizedBox(width: AppSizes.paddingM),
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.5),
                fontFamily: 'Roboto',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(
                  color: AppColors.textSecondary,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(
                  color: AppColors.textSecondary,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(color: AppColors.error),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
                vertical: AppSizes.paddingM,
              ),
            ),
            style: TextStyle(
              fontFamily: 'Roboto',
              color: AppColors.textPrimary,
            ),
            validator: validator,
            keyboardType: keyboardType,
          ),
        ),
      ],
    );
  }
}
