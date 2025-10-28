import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/company_info.dart';
import '../../../view_model/company_info_viewmodel.dart';
import '../../../view_model/bank_viewmodel.dart';
import '../../widgets/bank_form_dialog.dart';

class CompanySettingsScreen extends ConsumerStatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  ConsumerState<CompanySettingsScreen> createState() =>
      _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends ConsumerState<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _legalNameController;
  late TextEditingController _gstNumberController;
  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  CompanyInfo? _currentCompanyInfo;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _legalNameController = TextEditingController();
    _gstNumberController = TextEditingController();
    _addressLine1Controller = TextEditingController();
    _addressLine2Controller = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _pincodeController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _legalNameController.dispose();
    _gstNumberController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _initializeControllers(CompanyInfo companyInfo) {
    if (_isInitialized) return;
    _currentCompanyInfo = companyInfo;
    _nameController.text = companyInfo.name;
    _legalNameController.text = companyInfo.legalName;
    _gstNumberController.text = companyInfo.gstNumber ?? '';
    _addressLine1Controller.text = companyInfo.addressLine1 ?? '';
    _addressLine2Controller.text = companyInfo.addressLine2 ?? '';
    _cityController.text = companyInfo.city ?? '';
    _stateController.text = companyInfo.state ?? '';
    _pincodeController.text = companyInfo.pincode ?? '';
    _phoneController.text = companyInfo.phone ?? '';
    _emailController.text = companyInfo.email ?? '';
    _isInitialized = true;
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      if (_currentCompanyInfo == null) return;

      final updatedCompanyInfo = CompanyInfo(
        id: _currentCompanyInfo!.id,
        name: _nameController.text.trim(),
        legalName: _legalNameController.text.trim(),
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
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        logo: _currentCompanyInfo!.logo,
        isEnabled: _currentCompanyInfo!.isEnabled,
        isDeleted: _currentCompanyInfo!.isDeleted,
        isPrimary: _currentCompanyInfo!.isPrimary,
      );

      try {
        await ref
            .read(companyInfoViewModelProvider.notifier)
            .updateCompanyInfo(updatedCompanyInfo);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company information updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyInfoState = ref.watch(companyInfoViewModelProvider);

    if (companyInfoState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (companyInfoState.error != null) {
      return Center(
        child: Text(
          'Error: ${companyInfoState.error}',
          style: const TextStyle(color: AppColors.error),
        ),
      );
    }

    if (companyInfoState.companyInfo == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: AppSizes.iconXL * 2,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              'No primary company found',
              style: TextStyle(
                fontSize: AppSizes.fontXXL,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'Please configure a primary company in the database',
              style: TextStyle(
                fontSize: AppSizes.fontL,
                color: AppColors.textSecondary,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      );
    }

    _initializeControllers(companyInfoState.companyInfo!);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.business, size: 32, color: AppColors.primary),
                    const SizedBox(width: AppSizes.paddingM),
                    Text(
                      'Company Information',
                      style: TextStyle(
                        fontSize: AppSizes.fontXXL,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  'Update your primary company details',
                  style: TextStyle(
                    fontSize: AppSizes.fontM,
                    color: AppColors.textSecondary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingL),
                // Bank account section for the primary company
                Builder(
                  builder: (context) {
                    final companyId = companyInfoState.companyInfo!.id!;
                    return Container(
                      padding: const EdgeInsets.all(AppSizes.paddingL),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bank Account',
                                style: TextStyle(
                                  fontSize: AppSizes.fontL,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  // open dialog to add/edit bank
                                  final repoAsync = ref.watch(
                                    bankByCompanyProvider(companyId),
                                  );
                                  final bank = repoAsync.asData?.value;
                                  final result = await showDialog<bool?>(
                                    context: context,
                                    builder: (_) => BankFormDialog(
                                      bank: bank,
                                      companyId: companyId,
                                    ),
                                  );
                                  if (result == true) {
                                    // reload company info in case bank-related display needs update
                                    await ref
                                        .read(
                                          companyInfoViewModelProvider.notifier,
                                        )
                                        .loadPrimaryCompanyInfo();
                                  }
                                },
                                child: const Text('Edit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.paddingM),
                          // Bank details
                          ref
                              .watch(bankByCompanyProvider(companyId))
                              .when(
                                data: (bank) {
                                  if (bank == null) {
                                    return Text(
                                      'No bank account configured for this company.',
                                      style: TextStyle(
                                        fontSize: AppSizes.fontM,
                                        color: AppColors.textSecondary,
                                      ),
                                    );
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${bank.accountHolderName}',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontM,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: AppSizes.paddingXS,
                                      ),
                                      Text(
                                        'Account: ${bank.accountNumber}',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontS,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: AppSizes.paddingXS,
                                      ),
                                      Text(
                                        'IFSC: ${bank.ifscCode ?? '-'}',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontS,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: AppSizes.paddingXS,
                                      ),
                                      Text(
                                        'Bank: ${bank.bankName ?? '-'}',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontS,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: AppSizes.paddingXS,
                                      ),
                                      Text(
                                        'Branch: ${bank.branchName ?? '-'}',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontS,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (e, st) => Text(
                                  'Error loading bank: $e',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSizes.paddingXL),
                // Form fields
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingL),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Company Name *',
                          hintText: 'Enter company name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Company name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Legal Name
                      TextFormField(
                        controller: _legalNameController,
                        decoration: InputDecoration(
                          labelText: 'Legal Name *',
                          hintText: 'Enter legal name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Legal name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // GST Number
                      TextFormField(
                        controller: _gstNumberController,
                        decoration: InputDecoration(
                          labelText: 'GST Number',
                          hintText: 'Enter GST number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Address Line 1
                      TextFormField(
                        controller: _addressLine1Controller,
                        decoration: InputDecoration(
                          labelText: 'Address Line 1',
                          hintText: 'Enter address line 1',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Address Line 2
                      TextFormField(
                        controller: _addressLine2Controller,
                        decoration: InputDecoration(
                          labelText: 'Address Line 2',
                          hintText: 'Enter address line 2',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // City, State, Pincode Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                labelText: 'City',
                                hintText: 'Enter city',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusS,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: InputDecoration(
                                labelText: 'State',
                                hintText: 'Enter state',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusS,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: TextFormField(
                              controller: _pincodeController,
                              decoration: InputDecoration(
                                labelText: 'Pincode',
                                hintText: 'Enter pincode',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusS,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Phone and Email Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone',
                                hintText: 'Enter phone number',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusS,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter email address',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusS,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value != null &&
                                    value.trim().isNotEmpty &&
                                    !RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(value)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingXL),
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSizes.paddingM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusS,
                              ),
                            ),
                          ),
                          child: Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: AppSizes.fontL,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
