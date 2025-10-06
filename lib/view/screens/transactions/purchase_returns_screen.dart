import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class PurchaseReturnsScreen extends StatelessWidget {
  const PurchaseReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.undo, size: AppSizes.iconXL * 2, color: AppColors.primary),
          const SizedBox(height: AppSizes.paddingL),
          Text(
            'Purchase Return (Debit Notes)',
            style: TextStyle(
              fontSize: AppSizes.fontXXL,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'Purchase returns management coming soon',
            style: TextStyle(
              fontSize: AppSizes.fontL,
              color: AppColors.textSecondary,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}
