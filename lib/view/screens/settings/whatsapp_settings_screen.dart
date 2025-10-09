import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class WhatsappSettingsScreen extends StatelessWidget {
  const WhatsappSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat, size: AppSizes.iconXL * 2, color: Colors.green),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              'WhatsApp Settings',
              style: TextStyle(
                fontSize: AppSizes.fontXXL,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'Configure WhatsApp integration for sending invoices and notifications',
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
