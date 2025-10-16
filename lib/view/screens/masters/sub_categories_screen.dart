import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/sub_category.dart';
import '../../../view_model/sub_category_viewmodel.dart';
import '../../widgets/sub_category_form_dialog.dart';

class SubCategoriesScreen extends ConsumerWidget {
  const SubCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subCategoryState = ref.watch(subCategoryProvider);
    final mainCategoriesAsync = ref.watch(mainCategoriesListProvider);

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
                  'Sub Categories',
                  style: TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showSubCategoryDialog(context, ref, null),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New Sub Category'),
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
            child: subCategoryState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : subCategoryState.error != null
                ? Center(
                    child: Text(
                      'Error: ${subCategoryState.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                : subCategoryState.subCategories.isEmpty
                ? Center(
                    child: Text(
                      'No sub categories found',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : mainCategoriesAsync.when(
                    data: (mainCategories) {
                      // Create a map for quick lookup
                      final mainCategoryMap = {
                        for (var cat in mainCategories) cat.id: cat.name,
                      };

                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSizes.paddingL),
                        itemCount: subCategoryState.subCategories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSizes.paddingM),
                        itemBuilder: (context, index) {
                          final subCategory =
                              subCategoryState.subCategories[index];
                          final mainCategoryName =
                              mainCategoryMap[subCategory.mainCategoryId] ??
                              'Unknown';
                          return _buildSubCategoryCard(
                            context,
                            ref,
                            subCategory,
                            mainCategoryName,
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text(
                        'Error loading main categories: $error',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCategoryCard(
    BuildContext context,
    WidgetRef ref,
    SubCategory subCategory,
    String mainCategoryName,
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
          // Image thumbnail
          _buildImageThumbnail(subCategory),
          const SizedBox(width: AppSizes.paddingM),
          // Sub Category info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First line: Sub category name (main category name)
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: AppSizes.fontL,
                      fontFamily: 'Roboto',
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: subCategory.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' ($mainCategoryName)',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                // Second line: Description
                if (subCategory.description != null)
                  Text(
                    subCategory.description!,
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
                icon: Icon(Icons.edit, size: 20),
                color: AppColors.primary,
                onPressed: () =>
                    _showSubCategoryDialog(context, ref, subCategory),
                tooltip: 'Edit',
              ),
              // Toggle button - Commented out: Sub Categories are always enabled
              // IconButton(
              //   icon: Icon(
              //     subCategory.isEnabled ? Icons.toggle_on : Icons.toggle_off,
              //     size: 36,
              //   ),
              //   color: subCategory.isEnabled
              //       ? AppColors.success
              //       : AppColors.textSecondary,
              //   onPressed: () => _toggleSubCategory(ref, subCategory),
              //   tooltip: subCategory.isEnabled ? 'Disable' : 'Enable',
              // ),
              // Delete button - Hidden
              // IconButton(
              //   icon: Icon(Icons.delete, size: 20),
              //   color: AppColors.error,
              //   onPressed: () => _deleteSubCategory(context, ref, subCategory),
              //   tooltip: 'Delete',
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(SubCategory subCategory) {
    final imagePath = subCategory.image != null
        ? 'C:\\motobill\\database\\images\\${subCategory.image}'
        : null;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        child: imagePath != null
            ? Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder('Broken\nLink', Icons.broken_image);
                },
              )
            : _buildPlaceholder('No\nImage', Icons.image_not_supported),
      ),
    );
  }

  Widget _buildPlaceholder(String text, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: AppColors.textSecondary),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(
            fontSize: AppSizes.fontXS,
            color: AppColors.textSecondary,
            fontFamily: 'Roboto',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showSubCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    SubCategory? subCategory,
  ) {
    showDialog(
      context: context,
      builder: (context) => SubCategoryFormDialog(
        subCategory: subCategory,
        onSave: (subCategory) {
          if (subCategory.id == null) {
            ref
                .read(subCategoryProvider.notifier)
                .createSubCategory(subCategory);
          } else {
            ref
                .read(subCategoryProvider.notifier)
                .updateSubCategory(subCategory);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // Toggle functionality - Commented out: Sub Categories are always enabled
  // void _toggleSubCategory(WidgetRef ref, SubCategory subCategory) {
  //   ref
  //       .read(subCategoryProvider.notifier)
  //       .toggleSubCategoryEnabled(subCategory.id!, !subCategory.isEnabled);
  // }

  // Delete functionality - Hidden
  // void _deleteSubCategory(
  //   BuildContext context,
  //   WidgetRef ref,
  //   SubCategory subCategory,
  // ) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Delete Sub Category'),
  //       content: Text('Are you sure you want to delete ${subCategory.name}?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('Cancel'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             ref
  //                 .read(subCategoryProvider.notifier)
  //                 .deleteSubCategory(subCategory.id!);
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
