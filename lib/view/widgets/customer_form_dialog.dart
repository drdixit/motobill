import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/customer.dart';

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer; // Null for create, non-null for edit
  final Function(Customer) onSave;

  const CustomerFormDialog({super.key, this.customer, required this.onSave});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
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
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _legalNameController = TextEditingController(
      text: widget.customer?.legalName ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.customer?.phone ?? '',
    );
    _emailController = TextEditingController(
      text: widget.customer?.email ?? '',
    );
    _gstNumberController = TextEditingController(
      text: widget.customer?.gstNumber ?? '',
    );
    _addressLine1Controller = TextEditingController(
      text: widget.customer?.addressLine1 ?? '',
    );
    _addressLine2Controller = TextEditingController(
      text: widget.customer?.addressLine2 ?? '',
    );
    _cityController = TextEditingController(text: widget.customer?.city ?? '');
    _stateController = TextEditingController(
      text: widget.customer?.state ?? '',
    );
    _pincodeController = TextEditingController(
      text: widget.customer?.pincode ?? '',
    );
    _isEnabled = widget.customer?.isEnabled ?? true;
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
      final customer = Customer(
        id: widget.customer?.id,
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
            : _gstNumberController.text.trim(),
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
      widget.onSave(customer);
    }
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
                  widget.customer == null ? 'New Customer' : 'Edit Customer',
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
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Mobile Number',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _gstNumberController,
                        label: 'GST Number',
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _addressLine1Controller,
                        label: 'Address Line 1',
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _addressLine2Controller,
                        label: 'Address Line 2',
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'City',
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: _buildTextField(
                              controller: _stateController,
                              label: 'State',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _pincodeController,
                        label: 'Pincode',
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
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontFamily: 'Roboto',
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          borderSide: BorderSide(color: AppColors.border),
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
      style: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary),
      validator: validator,
      keyboardType: keyboardType,
    );
  }
}
