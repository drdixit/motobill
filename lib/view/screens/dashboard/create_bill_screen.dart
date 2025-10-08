import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class CreateBillScreen extends StatelessWidget {
  const CreateBillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Bill'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: AppSizes.iconXL * 2,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              'Create Bill Screen',
              style: TextStyle(
                fontSize: AppSizes.fontXXL,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: AppSizes.fontL,
                color: AppColors.textSecondary,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
