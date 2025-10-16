import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/main_category.dart';
import '../../../view_model/main_category_viewmodel.dart';
import '../../widgets/main_category_form_dialog.dart';

class MainCategoriesScreen extends ConsumerWidget {
  const MainCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryState = ref.watch(mainCategoryProvider);

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
                  'Main Categories',
                  style: TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCategoryDialog(context, ref, null),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New Category'),
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
            child: categoryState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : categoryState.error != null
                ? Center(
                    child: Text(
                      'Error: ${categoryState.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                : categoryState.categories.isEmpty
                ? Center(
                    child: Text(
                      'No categories found',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    itemCount: categoryState.categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSizes.paddingM),
                    itemBuilder: (context, index) {
                      final category = categoryState.categories[index];
                      return _buildCategoryCard(context, ref, category);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    WidgetRef ref,
    MainCategory category,
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
          _buildImageThumbnail(category),
          const SizedBox(width: AppSizes.paddingM),
          // Category info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First line: Name
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                // Second line: Description
                if (category.description != null)
                  Text(
                    category.description!,
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
                onPressed: () => _showCategoryDialog(context, ref, category),
                tooltip: 'Edit',
              ),
              // Toggle button - Commented out: Main Categories are always enabled
              // IconButton(
              //   icon: Icon(
              //     category.isEnabled ? Icons.toggle_on : Icons.toggle_off,
              //     size: 36,
              //   ),
              //   color: category.isEnabled
              //       ? AppColors.success
              //       : AppColors.textSecondary,
              //   onPressed: () => _toggleCategory(ref, category),
              //   tooltip: category.isEnabled ? 'Disable' : 'Enable',
              // ),
              // Delete button - Hidden
              // IconButton(
              //   icon: Icon(Icons.delete, size: 20),
              //   color: AppColors.error,
              //   onPressed: () => _deleteCategory(context, ref, category),
              //   tooltip: 'Delete',
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(MainCategory category) {
    final imagePath = category.image != null
        ? 'C:\\motobill\\database\\images\\${category.image}'
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

  void _showCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    MainCategory? category,
  ) {
    showDialog(
      context: context,
      builder: (context) => MainCategoryFormDialog(
        category: category,
        onSave: (category) {
          if (category.id == null) {
            ref.read(mainCategoryProvider.notifier).createCategory(category);
          } else {
            ref.read(mainCategoryProvider.notifier).updateCategory(category);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // Toggle functionality - Commented out: Main Categories are always enabled
  // void _toggleCategory(WidgetRef ref, MainCategory category) {
  //   ref
  //       .read(mainCategoryProvider.notifier)
  //       .toggleCategoryEnabled(category.id!, !category.isEnabled);
  // }

  // Delete functionality - Hidden
  // void _deleteCategory(
  //   BuildContext context,
  //   WidgetRef ref,
  //   MainCategory category,
  // ) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Delete Category'),
  //       content: Text('Are you sure you want to delete ${category.name}?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('Cancel'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             ref
  //                 .read(mainCategoryProvider.notifier)
  //                 .deleteCategory(category.id!);
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
