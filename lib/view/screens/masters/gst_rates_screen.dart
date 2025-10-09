import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/gst_rate.dart';
import '../../../view_model/gst_rate_viewmodel.dart';
import '../../widgets/gst_rate_form_dialog.dart';

class GstRatesScreen extends ConsumerWidget {
  const GstRatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gstRateState = ref.watch(gstRateViewModelProvider);

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
                  'GST Rates',
                  style: TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showGstRateDialog(context, ref, null),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New GST Rate'),
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
            child: gstRateState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : gstRateState.error != null
                ? Center(
                    child: Text(
                      'Error: ${gstRateState.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                : gstRateState.gstRates.isEmpty
                ? Center(
                    child: Text(
                      'No GST rates found',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    itemCount: gstRateState.gstRates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSizes.paddingM),
                    itemBuilder: (context, index) {
                      final gstRateData = gstRateState.gstRates[index];
                      return _buildGstRateCard(context, ref, gstRateData);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGstRateCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> gstRateData,
  ) {
    final gstRate = GstRate.fromJson(gstRateData);
    final hsnCode = gstRateData['hsn_code'] as String?;
    final hsnDescription = gstRateData['hsn_description'] as String?;

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingS),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // GST Rate info
          Expanded(
            child: Row(
              children: [
                // HSN Code - Fixed width
                SizedBox(
                  width: 100,
                  child: Text(
                    hsnCode ?? 'N/A',
                    style: TextStyle(
                      fontSize: AppSizes.fontL,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingS),
                // CGST
                _buildRateChip('CGST', gstRate.cgst),
                const SizedBox(width: AppSizes.paddingS),
                // SGST
                _buildRateChip('SGST', gstRate.sgst),
                const SizedBox(width: AppSizes.paddingS),
                // IGST
                _buildRateChip('IGST', gstRate.igst),
                const SizedBox(width: AppSizes.paddingS),
                // UTGST
                _buildRateChip('UTGST', gstRate.utgst),
                const SizedBox(width: AppSizes.paddingL),
                // Description - Flexible
                Expanded(
                  child: Text(
                    hsnDescription ?? '',
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      color: AppColors.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                // Effective date - Fixed width
                SizedBox(
                  width: 200,
                  child: Text(
                    'Effective ${_formatDate(gstRate.effectiveFrom)} onwards',
                    style: TextStyle(
                      fontSize: AppSizes.fontS,
                      color: AppColors.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                  ),
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
                icon: const Icon(Icons.edit, size: 20),
                color: AppColors.primary,
                onPressed: () => _showGstRateDialog(context, ref, gstRate),
                tooltip: 'Edit',
              ),
              // Toggle button
              IconButton(
                icon: Icon(
                  gstRate.isEnabled ? Icons.toggle_on : Icons.toggle_off,
                  size: 36,
                ),
                color: gstRate.isEnabled
                    ? AppColors.success
                    : AppColors.textSecondary,
                onPressed: () => _toggleGstRate(ref, gstRate),
                tooltip: gstRate.isEnabled ? 'Disable' : 'Enable',
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                color: AppColors.error,
                onPressed: () => _deleteGstRate(context, ref, gstRate, hsnCode),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateChip(String label, double rate) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Text(
        '$label: ${rate.toStringAsFixed(2)}%',
        style: TextStyle(
          fontSize: AppSizes.fontS,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showGstRateDialog(
    BuildContext context,
    WidgetRef ref,
    GstRate? gstRate,
  ) {
    showDialog(
      context: context,
      builder: (context) => GstRateFormDialog(
        gstRate: gstRate,
        onSave: (gstRate) async {
          try {
            if (gstRate.id == null) {
              await ref
                  .read(gstRateViewModelProvider.notifier)
                  .addGstRate(gstRate);
            } else {
              await ref
                  .read(gstRateViewModelProvider.notifier)
                  .updateGstRate(gstRate);
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _toggleGstRate(WidgetRef ref, GstRate gstRate) {
    ref
        .read(gstRateViewModelProvider.notifier)
        .toggleGstRateStatus(gstRate.id!, !gstRate.isEnabled);
  }

  void _deleteGstRate(
    BuildContext context,
    WidgetRef ref,
    GstRate gstRate,
    String? hsnCode,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete GST Rate'),
        content: Text(
          'Are you sure you want to delete GST rate for ${hsnCode ?? 'this HSN code'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(gstRateViewModelProvider.notifier)
                  .deleteGstRate(gstRate.id!);
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
