import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class BackupSettingsScreen extends StatelessWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.backup_outlined,
              size: 120,
              color: AppColors.primary.withOpacity(0.3),
            ),
            const SizedBox(height: AppSizes.paddingXL),
            Text(
              'Backup & Restore',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingXL,
                vertical: AppSizes.paddingL,
              ),
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(
                'Backup and restore functionality will allow you to:\n\n'
                '• Create automatic backups of your database\n'
                '• Export data to external storage\n'
                '• Restore from previous backups\n'
                '• Schedule automatic backups\n'
                '• Cloud backup integration',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingXL),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL,
                vertical: AppSizes.paddingM,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSizes.paddingS),
                  Text(
                    'This feature is under development',
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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
