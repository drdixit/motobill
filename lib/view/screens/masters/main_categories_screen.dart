import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class MainCategoriesScreen extends StatelessWidget {
  const MainCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category,
            size: AppSizes.iconXL * 2,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSizes.paddingL),
          Text(
            'Main Categories',
            style: TextStyle(
              fontSize: AppSizes.fontXXL,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'Main category management coming soon',
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
