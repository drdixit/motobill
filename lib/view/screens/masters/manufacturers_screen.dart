import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/manufacturer.dart';
import '../../../view_model/manufacturer_viewmodel.dart';
import '../../widgets/manufacturer_form_dialog.dart';

class ManufacturersScreen extends ConsumerWidget {
  const ManufacturersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manufacturerState = ref.watch(manufacturerProvider);

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
                  'Manufacturers',
                  style: TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showManufacturerDialog(context, ref, null),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New Manufacturer'),
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
            child: manufacturerState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : manufacturerState.error != null
                ? Center(
                    child: Text(
                      'Error: ${manufacturerState.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                : manufacturerState.manufacturers.isEmpty
                ? Center(
                    child: Text(
                      'No manufacturers found',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    itemCount: manufacturerState.manufacturers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSizes.paddingM),
                    itemBuilder: (context, index) {
                      final manufacturer =
                          manufacturerState.manufacturers[index];
                      return _buildManufacturerCard(context, ref, manufacturer);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildManufacturerCard(
    BuildContext context,
    WidgetRef ref,
    Manufacturer manufacturer,
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
          _buildImageThumbnail(manufacturer),
          const SizedBox(width: AppSizes.paddingM),
          // Manufacturer info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First line: Name
                Text(
                  manufacturer.name,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                // Second line: Description
                if (manufacturer.description != null)
                  Text(
                    manufacturer.description!,
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
                    _showManufacturerDialog(context, ref, manufacturer),
                tooltip: 'Edit',
              ),
              // Toggle button
              IconButton(
                icon: Icon(
                  manufacturer.isEnabled ? Icons.toggle_on : Icons.toggle_off,
                  size: 36,
                ),
                color: manufacturer.isEnabled
                    ? AppColors.success
                    : AppColors.textSecondary,
                onPressed: () => _toggleManufacturer(ref, manufacturer),
                tooltip: manufacturer.isEnabled ? 'Disable' : 'Enable',
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete, size: 20),
                color: AppColors.error,
                onPressed: () =>
                    _deleteManufacturer(context, ref, manufacturer),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(Manufacturer manufacturer) {
    final imagePath = manufacturer.image != null
        ? 'C:\\motobill\\database\\images\\${manufacturer.image}'
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

  void _showManufacturerDialog(
    BuildContext context,
    WidgetRef ref,
    Manufacturer? manufacturer,
  ) {
    showDialog(
      context: context,
      builder: (context) => ManufacturerFormDialog(
        manufacturer: manufacturer,
        onSave: (manufacturer) {
          if (manufacturer.id == null) {
            ref
                .read(manufacturerProvider.notifier)
                .createManufacturer(manufacturer);
          } else {
            ref
                .read(manufacturerProvider.notifier)
                .updateManufacturer(manufacturer);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _toggleManufacturer(WidgetRef ref, Manufacturer manufacturer) {
    ref
        .read(manufacturerProvider.notifier)
        .toggleManufacturerEnabled(manufacturer.id!, !manufacturer.isEnabled);
  }

  void _deleteManufacturer(
    BuildContext context,
    WidgetRef ref,
    Manufacturer manufacturer,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Manufacturer'),
        content: Text('Are you sure you want to delete ${manufacturer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(manufacturerProvider.notifier)
                  .deleteManufacturer(manufacturer.id!);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
