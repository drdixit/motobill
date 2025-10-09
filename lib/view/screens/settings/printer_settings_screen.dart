import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class PrinterSettingsScreen extends StatelessWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.print,
              size: AppSizes.iconXL * 2,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              'Printer Settings',
              style: TextStyle(
                fontSize: AppSizes.fontXXL,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'Configure printer preferences, page size, and print templates',
              style: TextStyle(
                fontSize: AppSizes.fontL,
                color: AppColors.textSecondary,
                fontFamily: 'Roboto',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
