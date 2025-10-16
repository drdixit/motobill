import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/hsn_code.dart';
import '../../../view_model/hsn_code_viewmodel.dart';
import '../../widgets/hsn_code_form_dialog.dart';

class HsnCodesScreen extends ConsumerWidget {
  const HsnCodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hsnCodeState = ref.watch(hsnCodeViewModelProvider);

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
                  'HSN Codes',
                  style: TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showHsnCodeDialog(context, ref, null),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New HSN Code'),
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
            child: hsnCodeState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : hsnCodeState.error != null
                ? Center(
                    child: Text(
                      'Error: ${hsnCodeState.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                : hsnCodeState.hsnCodes.isEmpty
                ? Center(
                    child: Text(
                      'No HSN codes found',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    itemCount: hsnCodeState.hsnCodes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSizes.paddingM),
                    itemBuilder: (context, index) {
                      final hsnCode = hsnCodeState.hsnCodes[index];
                      return _buildHsnCodeCard(context, ref, hsnCode);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHsnCodeCard(
    BuildContext context,
    WidgetRef ref,
    HsnCode hsnCode,
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
          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusS),
            ),
            child: Icon(Icons.qr_code_2, size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: AppSizes.paddingM),
          // HSN Code info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First line: Code
                Text(
                  hsnCode.code,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                // Second line: Description
                if (hsnCode.description != null)
                  Text(
                    hsnCode.description!,
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      color: AppColors.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                onPressed: () => _showHsnCodeDialog(context, ref, hsnCode),
                tooltip: 'Edit',
              ),
              // Toggle button - Commented out: HSN Codes are always enabled
              // IconButton(
              //   icon: Icon(
              //     hsnCode.isEnabled ? Icons.toggle_on : Icons.toggle_off,
              //     size: 36,
              //   ),
              //   color: hsnCode.isEnabled
              //       ? AppColors.success
              //       : AppColors.textSecondary,
              //   onPressed: () => _toggleHsnCode(ref, hsnCode),
              //   tooltip: hsnCode.isEnabled ? 'Disable' : 'Enable',
              // ),
              // Delete button - Hidden
              // IconButton(
              //   icon: const Icon(Icons.delete, size: 20),
              //   color: AppColors.error,
              //   onPressed: () => _deleteHsnCode(context, ref, hsnCode),
              //   tooltip: 'Delete',
              // ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHsnCodeDialog(
    BuildContext context,
    WidgetRef ref,
    HsnCode? hsnCode,
  ) {
    showDialog(
      context: context,
      builder: (context) => HsnCodeFormDialog(
        hsnCode: hsnCode,
        onSave: (hsnCode) async {
          try {
            if (hsnCode.id == null) {
              await ref
                  .read(hsnCodeViewModelProvider.notifier)
                  .addHsnCode(hsnCode);
            } else {
              await ref
                  .read(hsnCodeViewModelProvider.notifier)
                  .updateHsnCode(hsnCode);
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

  // Toggle functionality - Commented out: HSN Codes are always enabled
  // void _toggleHsnCode(WidgetRef ref, HsnCode hsnCode) {
  //   ref
  //       .read(hsnCodeViewModelProvider.notifier)
  //       .toggleHsnCodeStatus(hsnCode.id!, !hsnCode.isEnabled);
  // }

  // Delete functionality - Hidden
  // void _deleteHsnCode(BuildContext context, WidgetRef ref, HsnCode hsnCode) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Delete HSN Code'),
  //       content: Text('Are you sure you want to delete ${hsnCode.code}?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('Cancel'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             ref
  //                 .read(hsnCodeViewModelProvider.notifier)
  //                 .deleteHsnCode(hsnCode.id!);
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
