import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/vendor.dart';
import '../../../view_model/vendor_viewmodel.dart';
import '../../widgets/vendor_form_dialog.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Vendor> _filterVendors(List<Vendor> vendors) {
    // Filter out AUTO-STOCK-ADJUSTMENT vendor (id: 7)
    final filteredBySystem = vendors.where((vendor) => vendor.id != 7).toList();

    if (_searchQuery.isEmpty) return filteredBySystem;

    final query = _searchQuery.toLowerCase();

    // Score each vendor and filter
    final scored = filteredBySystem
        .map((vendor) {
          final name = vendor.name.toLowerCase();
          final legalName = vendor.legalName?.toLowerCase() ?? '';
          final phone = vendor.phone?.toLowerCase() ?? '';
          final email = vendor.email?.toLowerCase() ?? '';
          final gstNumber = vendor.gstNumber?.toLowerCase() ?? '';

          final nameScore = _fuzzyMatch(query, name);
          final legalNameScore = _fuzzyMatch(query, legalName);
          final phoneScore = _fuzzyMatch(query, phone);
          final emailScore = _fuzzyMatch(query, email);
          final gstScore = _fuzzyMatch(query, gstNumber);

          final maxScore = [
            nameScore,
            legalNameScore,
            phoneScore,
            emailScore,
            gstScore,
          ].reduce((a, b) => a > b ? a : b);

          return {'vendor': vendor, 'score': maxScore};
        })
        .where((item) => (item['score'] as double) > 0)
        .toList();

    // Sort by score descending
    scored.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );

    return scored.map((item) => item['vendor'] as Vendor).toList();
  }

  double _fuzzyMatch(String query, String text) {
    if (text.isEmpty) return 0;
    if (query.isEmpty) return 0;

    // Exact match gets highest score
    if (text.contains(query)) return 1.0;

    // Calculate fuzzy score
    int queryIndex = 0;
    int lastMatchIndex = -1;
    double score = 0;
    int consecutiveMatches = 0;

    for (int i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] == query[queryIndex]) {
        // Boost score for consecutive matches
        if (i == lastMatchIndex + 1) {
          consecutiveMatches++;
          score += 1.0 + (consecutiveMatches * 0.5);
        } else {
          consecutiveMatches = 0;
          score += 1.0;
        }
        lastMatchIndex = i;
        queryIndex++;
      }
    }

    // Return 0 if not all query characters found
    if (queryIndex < query.length) return 0;

    // Normalize score: penalize by text length and gap between matches
    final matchRatio = queryIndex / query.length;
    final lengthPenalty = query.length / text.length;
    final gapPenalty = query.length / (lastMatchIndex + 1);

    return score * matchRatio * lengthPenalty * gapPenalty;
  }

  @override
  Widget build(BuildContext context) {
    final vendorState = ref.watch(vendorProvider);
    final filteredVendors = _filterVendors(vendorState.vendors);

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
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppColors.textSecondary,
                              ),
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
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
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
                : filteredVendors.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No vendors found'
                          : 'No vendors match your search',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    itemCount: filteredVendors.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSizes.paddingM),
                    itemBuilder: (context, index) {
                      final vendor = filteredVendors[index];
                      return _buildVendorCard(context, ref, vendor);
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
              // Delete button - Hidden
              // IconButton(
              //   icon: Icon(Icons.delete, size: 20),
              //   color: AppColors.error,
              //   onPressed: () => _deleteVendor(context, ref, vendor),
              //   tooltip: 'Delete',
              // ),
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

  // Delete functionality - Hidden
  // void _deleteVendor(BuildContext context, WidgetRef ref, Vendor vendor) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Delete Vendor'),
  //       content: Text('Are you sure you want to delete ${vendor.name}?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('Cancel'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             ref.read(vendorProvider.notifier).deleteVendor(vendor.id!);
  //             Navigator.of(context).pop();
  //           },
  //           style: TextButton.styleFrom(foregroundColor: AppColors.error),
  //           child: const Text('Delete'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
