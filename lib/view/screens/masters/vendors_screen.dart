import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/vendor.dart';
import '../../../view_model/vendor_viewmodel.dart';
import '../../widgets/vendor_form_dialog.dart';

class VendorsScreen extends ConsumerWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorState = ref.watch(vendorProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vendors',
                  style: TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showVendorDialog(context, ref, null),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New Vendor'),
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
          ),
          // Content
          Expanded(
            child: vendorState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vendorState.error != null
                ? Center(
                    child: Text(
                      'Error: ${vendorState.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                : vendorState.vendors.isEmpty
                ? Center(
                    child: Text(
                      'No vendors found',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      // Filter out AUTO-STOCK-ADJUSTMENT vendor (id: 7)
                      final filteredVendors = vendorState.vendors
                          .where((vendor) => vendor.id != 7)
                          .toList();

                      if (filteredVendors.isEmpty) {
                        return Center(
                          child: Text(
                            'No vendors found',
                            style: TextStyle(
                              fontSize: AppSizes.fontL,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSizes.paddingL),
                        itemCount: filteredVendors.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSizes.paddingM),
                        itemBuilder: (context, index) {
                          final vendor = filteredVendors[index];
                          return _buildVendorCard(context, ref, vendor);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(BuildContext context, WidgetRef ref, Vendor vendor) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Vendor info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First line: Name (Legal Name)
                Text(
                  vendor.legalName != null && vendor.legalName != vendor.name
                      ? '${vendor.name} (${vendor.legalName})'
                      : vendor.legalName ?? vendor.name,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                // Second line: GST and Mobile
                Row(
                  children: [
                    if (vendor.gstNumber != null) ...[
                      Text(
                        'GST: ${vendor.gstNumber}',
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          color: AppColors.textSecondary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      if (vendor.phone != null) ...[
                        const SizedBox(width: AppSizes.paddingM),
                        Text(
                          '•',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                      ],
                    ],
                    if (vendor.phone != null)
                      Text(
                        vendor.phone!,
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
                onPressed: () => _showVendorDialog(context, ref, vendor),
                tooltip: 'Edit',
              ),
              // Toggle button
              IconButton(
                icon: Icon(
                  vendor.isEnabled ? Icons.toggle_on : Icons.toggle_off,
                  size: 36,
                ),
                color: vendor.isEnabled
                    ? AppColors.success
                    : AppColors.textSecondary,
                onPressed: () => _toggleVendor(ref, vendor),
                tooltip: vendor.isEnabled ? 'Disable' : 'Enable',
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete, size: 20),
                color: AppColors.error,
                onPressed: () => _deleteVendor(context, ref, vendor),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVendorDialog(BuildContext context, WidgetRef ref, Vendor? vendor) {
    showDialog(
      context: context,
      builder: (context) => VendorFormDialog(
        vendor: vendor,
        onSave: (vendor) {
          if (vendor.id == null) {
            ref.read(vendorProvider.notifier).createVendor(vendor);
          } else {
            ref.read(vendorProvider.notifier).updateVendor(vendor);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _toggleVendor(WidgetRef ref, Vendor vendor) {
    ref
        .read(vendorProvider.notifier)
        .toggleVendorEnabled(vendor.id!, !vendor.isEnabled);
  }

  void _deleteVendor(BuildContext context, WidgetRef ref, Vendor vendor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Are you sure you want to delete ${vendor.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(vendorProvider.notifier).deleteVendor(vendor.id!);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
