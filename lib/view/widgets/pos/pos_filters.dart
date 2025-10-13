import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../view_model/pos_viewmodel.dart';

class PosFilters extends ConsumerWidget {
  const PosFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posViewModelProvider);
    final viewModel = ref.read(posViewModelProvider.notifier);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_list, size: AppSizes.iconM),
                const SizedBox(width: AppSizes.paddingS),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (state.selectedMainCategoryId != null ||
                    state.selectedSubCategoryId != null ||
                    state.selectedManufacturerId != null)
                  TextButton(
                    onPressed: () {
                      viewModel.clearFilters();
                    },
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Filters Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              children: [
                // Main Category Filter
                _buildFilterSection(
                  title: 'Main Category',
                  child: Column(
                    children: [
                      _buildFilterChip(
                        label: 'All Categories',
                        isSelected: state.selectedMainCategoryId == null,
                        onTap: () => viewModel.selectMainCategory(null),
                      ),
                      ...state.mainCategories.map((category) {
                        return _buildFilterChip(
                          label: category.name,
                          isSelected:
                              state.selectedMainCategoryId == category.id,
                          onTap: () =>
                              viewModel.selectMainCategory(category.id),
                        );
                      }).toList(),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.paddingL),

                // Sub Category Filter (only show if main category selected)
                if (state.selectedMainCategoryId != null &&
                    state.subCategories.isNotEmpty)
                  _buildFilterSection(
                    title: 'Sub Category',
                    child: Column(
                      children: [
                        _buildFilterChip(
                          label: 'All Sub Categories',
                          isSelected: state.selectedSubCategoryId == null,
                          onTap: () => viewModel.selectSubCategory(null),
                        ),
                        ...state.subCategories.map((subCategory) {
                          return _buildFilterChip(
                            label: subCategory.name,
                            isSelected:
                                state.selectedSubCategoryId == subCategory.id,
                            onTap: () =>
                                viewModel.selectSubCategory(subCategory.id),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                if (state.selectedMainCategoryId != null &&
                    state.subCategories.isNotEmpty)
                  const SizedBox(height: AppSizes.paddingL),

                // Manufacturer Filter
                _buildFilterSection(
                  title: 'Manufacturer',
                  child: Column(
                    children: [
                      _buildFilterChip(
                        label: 'All Manufacturers',
                        isSelected: state.selectedManufacturerId == null,
                        onTap: () => viewModel.selectManufacturer(null),
                      ),
                      ...state.manufacturers.map((manufacturer) {
                        return _buildFilterChip(
                          label: manufacturer.name,
                          isSelected:
                              state.selectedManufacturerId == manufacturer.id,
                          onTap: () =>
                              viewModel.selectManufacturer(manufacturer.id),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppSizes.fontM,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.paddingS),
        child,
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingS,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppSizes.fontM,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: AppSizes.iconS,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
