import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../view_model/backup_viewmodel.dart';

class BackupSettingsScreen extends ConsumerWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupState = ref.watch(backupViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.backup, size: 32, color: AppColors.primary),
                const SizedBox(width: AppSizes.paddingM),
                Text(
                  'Local Backup',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingXL),

            // Backup Location Section
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
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 24,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSizes.paddingS),
                      Text(
                        'Backup Location',
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSizes.paddingS),
                        Expanded(
                          child: Text(
                            backupState.backupLocation ??
                                'No backup location set',
                            style: TextStyle(
                              fontSize: AppSizes.fontM,
                              color:
                                  backupState.backupLocation != null &&
                                      backupState.backupLocation !=
                                          'No backup location set'
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontFamily: 'Roboto',
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  ElevatedButton.icon(
                    onPressed: backupState.isLoading
                        ? null
                        : () {
                            ref
                                .read(backupViewModelProvider.notifier)
                                .selectBackupFolder();
                          },
                    icon: const Icon(Icons.folder_open, size: 20),
                    label: const Text('Select Backup Folder'),
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
            const SizedBox(height: AppSizes.paddingXL),

            // Create Backup Section
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
                  Row(
                    children: [
                      Icon(
                        Icons.save_outlined,
                        size: 24,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSizes.paddingS),
                      Text(
                        'Create Backup',
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  Text(
                    'Creates a compressed backup of your database folder including all data and images.',
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      color: AppColors.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingL),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: backupState.isLoading
                          ? null
                          : () {
                              ref
                                  .read(backupViewModelProvider.notifier)
                                  .createBackup();
                            },
                      icon: backupState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.backup, size: 20),
                      label: Text(
                        backupState.isLoading
                            ? 'Creating Backup...'
                            : 'Create Backup Now',
                        style: const TextStyle(fontSize: AppSizes.fontL),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingXL,
                          vertical: AppSizes.paddingL,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error Message
            if (backupState.error != null) ...[
              const SizedBox(height: AppSizes.paddingL),
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 24),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: Text(
                        backupState.error!,
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          color: AppColors.error,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.error,
                      onPressed: () {
                        ref.read(backupViewModelProvider.notifier).clearError();
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Success Message
            if (backupState.successMessage != null) ...[
              const SizedBox(height: AppSizes.paddingL),
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 24,
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: Text(
                        backupState.successMessage!,
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          color: AppColors.success,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.success,
                      onPressed: () {
                        ref
                            .read(backupViewModelProvider.notifier)
                            .clearSuccess();
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSizes.paddingXL),

            // Info Section
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSizes.paddingS),
                      Text(
                        'Backup Information',
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  Text(
                    '• Backup file format: HH_MM_SS__DD_MM_YYYY.zip\n'
                    '• Includes: Database, images, and all related files\n'
                    '• Location: C:/motobill/database\n'
                    '• Backup files are compressed to save space\n'
                    '• Keep backups in a safe, external location',
                    style: TextStyle(
                      fontSize: AppSizes.fontS,
                      color: AppColors.textSecondary,
                      height: 1.6,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
