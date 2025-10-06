import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/customer.dart';
import '../../../view_model/customer_viewmodel.dart';
import '../../widgets/customer_form_dialog.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, ref),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Text(
                state.error!,
                style: TextStyle(color: AppColors.error, fontFamily: 'Roboto'),
              ),
            ),
          Expanded(
            child: state.isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : state.customers.isEmpty
                ? _buildEmptyState()
                : _buildCustomerList(context, ref, state.customers),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Customers',
            style: TextStyle(
              fontSize: AppSizes.fontXXL,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Roboto',
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showCustomerDialog(context, ref, null),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('New Customer'),
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: AppSizes.iconXL * 2,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSizes.paddingL),
          Text(
            'No customers found',
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              color: AppColors.textSecondary,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'Click "New Customer" to add your first customer',
            style: TextStyle(
              fontSize: AppSizes.fontM,
              color: AppColors.textTertiary,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList(
    BuildContext context,
    WidgetRef ref,
    List<Customer> customers,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      itemCount: customers.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSizes.paddingM),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _buildCustomerItem(context, ref, customer);
      },
    );
  }

  Widget _buildCustomerItem(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Customer info (two-line layout)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First line: Name and Legal Name
                Text(
                  customer.legalName != null &&
                          customer.legalName != customer.name
                      ? '${customer.name} (${customer.legalName})'
                      : customer.legalName ?? customer.name,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                // Second line: GST number and mobile
                Row(
                  children: [
                    if (customer.gstNumber != null) ...[
                      Text(
                        'GST: ${customer.gstNumber}',
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          color: AppColors.textSecondary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      if (customer.phone != null) ...[
                        const SizedBox(width: AppSizes.paddingM),
                        Text(
                          '•',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                      ],
                    ],
                    if (customer.phone != null)
                      Text(
                        customer.phone!,
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          color: AppColors.textSecondary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit button
              IconButton(
                icon: Icon(Icons.edit, size: 20),
                color: AppColors.primary,
                onPressed: () => _showCustomerDialog(context, ref, customer),
                tooltip: 'Edit',
              ),
              // Toggle button
              IconButton(
                icon: Icon(
                  customer.isEnabled ? Icons.toggle_on : Icons.toggle_off,
                  size: 36,
                ),
                color: customer.isEnabled
                    ? AppColors.success
                    : AppColors.textSecondary,
                onPressed: () => _toggleCustomer(ref, customer),
                tooltip: customer.isEnabled ? 'Disable' : 'Enable',
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete, size: 20),
                color: AppColors.error,
                onPressed: () => _deleteCustomer(context, ref, customer),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCustomerDialog(
    BuildContext context,
    WidgetRef ref,
    Customer? customer,
  ) {
    final viewModel = ref.read(customerProvider.notifier);

    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(
        customer: customer,
        onSave: (newCustomer) async {
          Navigator.of(context).pop();
          if (customer == null) {
            await viewModel.createCustomer(newCustomer);
          } else {
            await viewModel.updateCustomer(newCustomer);
          }
        },
      ),
    );
  }

  void _toggleCustomer(WidgetRef ref, Customer customer) {
    final viewModel = ref.read(customerProvider.notifier);
    viewModel.toggleCustomerEnabled(customer.id!, !customer.isEnabled);
  }

  void _deleteCustomer(BuildContext context, WidgetRef ref, Customer customer) {
    final viewModel = ref.read(customerProvider.notifier);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Customer',
          style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Roboto'),
        ),
        content: Text(
          'Are you sure you want to delete "${customer.legalName ?? customer.name}"? This action cannot be undone.',
          style: TextStyle(fontFamily: 'Roboto'),
        ),
        actions: [
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
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await viewModel.deleteCustomer(customer.id!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: Text('Delete', style: TextStyle(fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }
}
