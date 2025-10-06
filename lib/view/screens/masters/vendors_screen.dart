import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class VendorsScreen extends StatelessWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business,
            size: AppSizes.iconXL * 2,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSizes.paddingL),
          Text(
            'Vendors',
            style: TextStyle(
              fontSize: AppSizes.fontXXL,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'Vendor management coming soon',
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
