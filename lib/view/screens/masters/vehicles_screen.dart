import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/vehicle.dart';
import '../../../view_model/vehicle_viewmodel.dart';
import '../../widgets/vehicle_form_dialog.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleState = ref.watch(vehicleProvider);
    final manufacturersAsync = ref.watch(manufacturersListProvider);

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
                  'Vehicles',
                  style: TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showVehicleDialog(context, ref, null),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New Vehicle'),
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
            child: vehicleState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vehicleState.error != null
                ? Center(
                    child: Text(
                      'Error: ${vehicleState.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                : vehicleState.vehicles.isEmpty
                ? Center(
                    child: Text(
                      'No vehicles found',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : manufacturersAsync.when(
                    data: (manufacturers) {
                      // Create a map for quick lookup
                      final manufacturerMap = {
                        for (var m in manufacturers) m.id: m.name,
                      };

                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSizes.paddingL),
                        itemCount: vehicleState.vehicles.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSizes.paddingM),
                        itemBuilder: (context, index) {
                          final vehicle = vehicleState.vehicles[index];
                          final manufacturerName =
                              manufacturerMap[vehicle.manufacturerId] ??
                              'Unknown';
                          return _buildVehicleCard(
                            context,
                            ref,
                            vehicle,
                            manufacturerName,
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text(
                        'Error loading manufacturers: $error',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
    String manufacturerName,
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
          _buildImageThumbnail(vehicle),
          const SizedBox(width: AppSizes.paddingM),
          // Vehicle info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First line: Vehicle name (Manufacturer)
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: AppSizes.fontL,
                      fontFamily: 'Roboto',
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: vehicle.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' ($manufacturerName)',
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
                if (vehicle.description != null)
                  Text(
                    vehicle.description!,
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
                onPressed: () => _showVehicleDialog(context, ref, vehicle),
                tooltip: 'Edit',
              ),
              // Toggle button
              IconButton(
                icon: Icon(
                  vehicle.isEnabled ? Icons.toggle_on : Icons.toggle_off,
                  size: 36,
                ),
                color: vehicle.isEnabled
                    ? AppColors.success
                    : AppColors.textSecondary,
                onPressed: () => _toggleVehicle(ref, vehicle),
                tooltip: vehicle.isEnabled ? 'Disable' : 'Enable',
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete, size: 20),
                color: AppColors.error,
                onPressed: () => _deleteVehicle(context, ref, vehicle),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(Vehicle vehicle) {
    final imagePath = vehicle.image != null
        ? 'C:\\motobill\\database\\images\\${vehicle.image}'
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

  void _showVehicleDialog(
    BuildContext context,
    WidgetRef ref,
    Vehicle? vehicle,
  ) {
    showDialog(
      context: context,
      builder: (context) => VehicleFormDialog(
        vehicle: vehicle,
        onSave: (vehicle) {
          if (vehicle.id == null) {
            ref.read(vehicleProvider.notifier).createVehicle(vehicle);
          } else {
            ref.read(vehicleProvider.notifier).updateVehicle(vehicle);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _toggleVehicle(WidgetRef ref, Vehicle vehicle) {
    ref
        .read(vehicleProvider.notifier)
        .toggleVehicleEnabled(vehicle.id!, !vehicle.isEnabled);
  }

  void _deleteVehicle(BuildContext context, WidgetRef ref, Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Are you sure you want to delete ${vehicle.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(vehicleProvider.notifier).deleteVehicle(vehicle.id!);
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
