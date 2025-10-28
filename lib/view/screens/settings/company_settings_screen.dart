import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/company_info.dart';
import '../../../model/bank.dart';
import '../../../view_model/company_info_viewmodel.dart';
import '../../../view_model/bank_viewmodel.dart';

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
  // Bank form controllers
  late TextEditingController _bankHolderController;
  late TextEditingController _bankAccountController;
  late TextEditingController _bankIfscController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankBranchController;
  bool _bankInitialized = false;

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
    _bankHolderController = TextEditingController();
    _bankAccountController = TextEditingController();
    _bankIfscController = TextEditingController();
    _bankNameController = TextEditingController();
    _bankBranchController = TextEditingController();
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
    _bankHolderController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankNameController.dispose();
    _bankBranchController.dispose();
    super.dispose();
  }

  void _initializeBankControllers(Bank? bank) {
    if (_bankInitialized) return;
    if (bank == null) {
      _bankHolderController.text = '';
      _bankAccountController.text = '';
      _bankIfscController.text = '';
      _bankNameController.text = '';
      _bankBranchController.text = '';
    } else {
      _bankHolderController.text = bank.accountHolderName;
      _bankAccountController.text = bank.accountNumber;
      _bankIfscController.text = bank.ifscCode ?? '';
      _bankNameController.text = bank.bankName ?? '';
      _bankBranchController.text = bank.branchName ?? '';
    }
    _bankInitialized = true;
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
        // Also save/update bank details (inline fields)
        try {
          final companyId = _currentCompanyInfo!.id!;
          final repo = await ref.read(bankRepositoryProvider.future);
          final existingBank = await repo.getBankByCompanyId(companyId);

          final holder = _bankHolderController.text.trim();
          final account = _bankAccountController.text.trim();
          final ifsc = _bankIfscController.text.trim().isEmpty
              ? null
              : _bankIfscController.text.trim();
          final bankName = _bankNameController.text.trim().isEmpty
              ? null
              : _bankNameController.text.trim();
          final branchName = _bankBranchController.text.trim().isEmpty
              ? null
              : _bankBranchController.text.trim();

          // Always create or update bank using the entered values (form validators ensure required fields)
          final bank = Bank(
            id: existingBank?.id,
            accountHolderName: holder,
            accountNumber: account,
            ifscCode: ifsc,
            bankName: bankName,
            branchName: branchName,
            companyId: companyId,
            isEnabled: true,
            isDeleted: false,
          );

          if (existingBank == null) {
            await repo.createBank(bank);
          } else {
            await repo.updateBank(bank);
          }

          // Invalidate provider so UI shows updated bank
          ref.invalidate(bankByCompanyProvider(companyId));
        } catch (e) {
          // Non-fatal; show a snackbar but don't block company save
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bank save error: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
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
                // Header (removed static title and subtitle as requested)

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

                      // Inline Bank fields (editable as part of company form)
                      Builder(
                        builder: (context) {
                          final companyId = companyInfoState.companyInfo!.id!;
                          return Container(
                            margin: const EdgeInsets.only(
                              top: AppSizes.paddingM,
                            ),
                            padding: EdgeInsets.zero,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusM,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bank Account',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontL,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.paddingM),
                                // load bank and initialize controllers once
                                ref
                                    .watch(bankByCompanyProvider(companyId))
                                    .when(
                                      data: (bank) {
                                        _initializeBankControllers(bank);
                                        return Column(
                                          children: [
                                            TextFormField(
                                              controller: _bankHolderController,
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Account Holder Name',
                                                hintText:
                                                    'Enter account holder name',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSizes.radiusS,
                                                      ),
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Account holder name is required';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(
                                              height: AppSizes.paddingM,
                                            ),
                                            TextFormField(
                                              controller:
                                                  _bankAccountController,
                                              decoration: InputDecoration(
                                                labelText: 'Account Number',
                                                hintText:
                                                    'Enter account number',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSizes.radiusS,
                                                      ),
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Account number is required';
                                                }
                                                final acct = value.trim();
                                                if (acct.length < 6) {
                                                  return 'Account number is too short';
                                                }
                                                if (!RegExp(
                                                  r'^[A-Za-z0-9]+$',
                                                ).hasMatch(acct)) {
                                                  return 'Account number must be alphanumeric';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(
                                              height: AppSizes.paddingM,
                                            ),
                                            TextFormField(
                                              controller: _bankIfscController,
                                              decoration: InputDecoration(
                                                labelText: 'IFSC Code',
                                                hintText: 'Enter IFSC code',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSizes.radiusS,
                                                      ),
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'IFSC code is required';
                                                }
                                                final code = value
                                                    .trim()
                                                    .toUpperCase();
                                                // Basic IFSC format: 4 letters, 0, 6 alphanumeric
                                                if (!RegExp(
                                                  r'^[A-Z]{4}0[A-Z0-9]{6}$',
                                                ).hasMatch(code)) {
                                                  return 'Enter a valid IFSC code';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(
                                              height: AppSizes.paddingM,
                                            ),
                                            TextFormField(
                                              controller: _bankNameController,
                                              decoration: InputDecoration(
                                                labelText: 'Bank Name',
                                                hintText: 'Enter bank name',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSizes.radiusS,
                                                      ),
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Bank name is required';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(
                                              height: AppSizes.paddingM,
                                            ),
                                            TextFormField(
                                              controller: _bankBranchController,
                                              decoration: InputDecoration(
                                                labelText: 'Branch Name',
                                                hintText: 'Enter branch name',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSizes.radiusS,
                                                      ),
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Branch name is required';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (e, st) => Text(
                                        'Error loading bank: $e',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                const SizedBox(height: AppSizes.paddingM),
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
                          );
                        },
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
