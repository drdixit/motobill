import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/customer.dart';
import '../../../view_model/customer_viewmodel.dart';
import '../../widgets/customer_form_dialog.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    if (_searchQuery.isEmpty) return customers;

    final query = _searchQuery.toLowerCase();
    return customers.where((customer) {
      final name = customer.name.toLowerCase();
      final legalName = customer.legalName?.toLowerCase() ?? '';
      final phone = customer.phone?.toLowerCase() ?? '';
      final email = customer.email?.toLowerCase() ?? '';
      final gstNumber = customer.gstNumber?.toLowerCase() ?? '';
      return name.contains(query) ||
          legalName.contains(query) ||
          phone.contains(query) ||
          email.contains(query) ||
          gstNumber.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);
    final filteredCustomers = _filterCustomers(state.customers);

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
                : filteredCustomers.isEmpty
                ? _buildEmptyState()
                : _buildCustomerList(context, ref, filteredCustomers),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, mobile, email or GST...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppSizes.fontM,
                ),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.white,
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingM,
                  vertical: AppSizes.paddingM,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingL),
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
            _searchQuery.isEmpty
                ? 'No customers found'
                : 'No customers match your search',
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              color: AppColors.textSecondary,
              fontFamily: 'Roboto',
            ),
          ),
          if (_searchQuery.isEmpty) const SizedBox(height: AppSizes.paddingM),
          if (_searchQuery.isEmpty)
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
              // Delete button - Hidden
              // IconButton(
              //   icon: Icon(Icons.delete, size: 20),
              //   color: AppColors.error,
              //   onPressed: () => _deleteCustomer(context, ref, customer),
              //   tooltip: 'Delete',
              // ),
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

  // Delete functionality - Hidden
  // void _deleteCustomer(BuildContext context, WidgetRef ref, Customer customer) {
  //   final viewModel = ref.read(customerProvider.notifier);
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text(
  //         'Delete Customer',
  //         style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Roboto'),
  //       ),
  //       content: Text(
  //         'Are you sure you want to delete "${customer.legalName ?? customer.name}"? This action cannot be undone.',
  //         style: TextStyle(fontFamily: 'Roboto'),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: Text(
  //             'Cancel',
  //             style: TextStyle(
  //               color: AppColors.textSecondary,
  //               fontFamily: 'Roboto',
  //             ),
  //           ),
  //         ),
  //         ElevatedButton(
  //           onPressed: () async {
  //             Navigator.of(context).pop();
  //             await viewModel.deleteCustomer(customer.id!);
  //           },
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: AppColors.error,
  //             foregroundColor: AppColors.white,
  //           ),
  //           child: Text('Delete', style: TextStyle(fontFamily: 'Roboto')),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
