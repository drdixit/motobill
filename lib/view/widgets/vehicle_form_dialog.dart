import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/vehicle.dart';
import '../../../view_model/vehicle_viewmodel.dart';

class VehicleFormDialog extends ConsumerStatefulWidget {
  final Vehicle? vehicle;
  final Function(Vehicle) onSave;

  const VehicleFormDialog({super.key, this.vehicle, required this.onSave});

  @override
  ConsumerState<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends ConsumerState<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _modelYearController;
  late TextEditingController _descriptionController;
  late bool _isEnabled;
  String? _selectedImageFileName;
  int? _selectedManufacturerId;
  int? _selectedVehicleTypeId;
  int? _selectedFuelTypeId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.vehicle?.name ?? '');
    _modelYearController = TextEditingController(
      text: widget.vehicle?.modelYear?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.vehicle?.description ?? '',
    );
    _isEnabled = widget.vehicle?.isEnabled ?? true;
    _selectedImageFileName = widget.vehicle?.image;
    _selectedManufacturerId = widget.vehicle?.manufacturerId;
    _selectedVehicleTypeId = widget.vehicle?.vehicleTypeId;
    _selectedFuelTypeId = widget.vehicle?.fuelTypeId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelYearController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final sourcePath = file.path;

        if (sourcePath != null) {
          // Generate unique filename using UUID
          final uuid = const Uuid();
          final extension = path.extension(sourcePath);
          final uniqueFileName = '${uuid.v4()}$extension';

          // Destination path
          final destinationPath =
              'C:\\motobill\\database\\images\\$uniqueFileName';

          // Copy file to destination
          final sourceFile = File(sourcePath);
          await sourceFile.copy(destinationPath);

          setState(() {
            _selectedImageFileName = uniqueFileName;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      // Additional validation: required fields
      if (_selectedManufacturerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a manufacturer'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedVehicleTypeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a vehicle type'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedFuelTypeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a fuel type'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final vehicle = Vehicle(
        id: widget.vehicle?.id,
        name: _nameController.text.trim(),
        modelYear: _modelYearController.text.trim().isEmpty
            ? null
            : int.tryParse(_modelYearController.text.trim()),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        image: _selectedImageFileName,
        manufacturerId: _selectedManufacturerId!,
        vehicleTypeId: _selectedVehicleTypeId!,
        fuelTypeId: _selectedFuelTypeId!,
        isEnabled: _isEnabled,
      );

      try {
        widget.onSave(vehicle);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving vehicle: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildImagePreview() {
    final imagePath = _selectedImageFileName != null
        ? 'C:\\motobill\\database\\images\\$_selectedImageFileName'
        : null;

    return InkWell(
      onTap: _pickAndUploadImage,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(color: AppColors.divider),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: imagePath != null
              ? Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholder(
                      'Broken Link\n(Click to upload)',
                      Icons.broken_image,
                    );
                  },
                )
              : _buildPlaceholder(
                  'No Image\n(Click to upload)',
                  Icons.image_not_supported,
                ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String text, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 40, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: AppSizes.fontS,
            color: AppColors.textSecondary,
            fontFamily: 'Roboto',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final manufacturersAsync = ref.watch(manufacturersListProvider);
    final vehicleTypesAsync = ref.watch(vehicleTypesListProvider);
    final fuelTypesAsync = ref.watch(fuelTypesListProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.vehicle == null ? 'New Vehicle' : 'Edit Vehicle',
                  style: TextStyle(
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            // Form
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Name field
                      _buildTextField(
                        controller: _nameController,
                        label: 'Name *',
                        hint: 'Vehicle Name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Manufacturer dropdown
                      manufacturersAsync.when(
                        data: (manufacturers) {
                          final enabledManufacturers = manufacturers
                              .where((m) => m.isEnabled)
                              .toList();

                          if (enabledManufacturers.isEmpty) {
                            return _buildErrorMessage(
                              'No active manufacturers available.\nPlease create and enable a manufacturer first.',
                            );
                          }

                          // Validate that selected value exists in filtered list
                          final validManufacturerId =
                              _selectedManufacturerId != null &&
                                  enabledManufacturers.any(
                                    (m) => m.id == _selectedManufacturerId,
                                  )
                              ? _selectedManufacturerId
                              : null;

                          return _buildDropdownField(
                            label: 'Manufacturer *',
                            hint: 'Select Manufacturer',
                            value: validManufacturerId,
                            items: enabledManufacturers.map((manufacturer) {
                              return DropdownMenuItem<int>(
                                value: manufacturer.id,
                                child: Text(manufacturer.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedManufacturerId = value;
                              });
                            },
                          );
                        },
                        loading: () => _buildLoadingField('Manufacturer *'),
                        error: (error, stack) => _buildErrorMessage(
                          'Error loading manufacturers: $error',
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Vehicle Type dropdown
                      vehicleTypesAsync.when(
                        data: (vehicleTypes) {
                          if (vehicleTypes.isEmpty) {
                            return _buildErrorMessage(
                              'No vehicle types available.',
                            );
                          }

                          return _buildDropdownField(
                            label: 'Vehicle Type *',
                            hint: 'Select Vehicle Type',
                            value: _selectedVehicleTypeId,
                            items: vehicleTypes.map((type) {
                              return DropdownMenuItem<int>(
                                value: type.id,
                                child: Text(type.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedVehicleTypeId = value;
                              });
                            },
                          );
                        },
                        loading: () => _buildLoadingField('Vehicle Type *'),
                        error: (error, stack) => _buildErrorMessage(
                          'Error loading vehicle types: $error',
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Fuel Type dropdown
                      fuelTypesAsync.when(
                        data: (fuelTypes) {
                          if (fuelTypes.isEmpty) {
                            return _buildErrorMessage(
                              'No fuel types available.',
                            );
                          }

                          return _buildDropdownField(
                            label: 'Fuel Type *',
                            hint: 'Select Fuel Type',
                            value: _selectedFuelTypeId,
                            items: fuelTypes.map((type) {
                              return DropdownMenuItem<int>(
                                value: type.id,
                                child: Text(type.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedFuelTypeId = value;
                              });
                            },
                          );
                        },
                        loading: () => _buildLoadingField('Fuel Type *'),
                        error: (error, stack) => _buildErrorMessage(
                          'Error loading fuel types: $error',
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Model Year field
                      _buildTextField(
                        controller: _modelYearController,
                        label: 'Model Year',
                        hint: 'e.g., 2024',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final year = int.tryParse(value);
                            if (year == null || year < 1900 || year > 2100) {
                              return 'Enter a valid year (1900-2100)';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Description field
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Vehicle Description',
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Image field with preview
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              'Image',
                              style: TextStyle(
                                fontSize: AppSizes.fontL,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildImagePreview(),
                                const SizedBox(height: AppSizes.paddingS),
                                Text(
                                  'Supported formats: JPG, JPEG, PNG, GIF, BMP, WEBP',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontS,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Roboto',
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      // Enabled checkbox - Commented out: Vehicles are always enabled
                      // Row(
                      //   children: [
                      //     Checkbox(
                      //       value: _isEnabled,
                      //       onChanged: (value) {
                      //         setState(() {
                      //           _isEnabled = value ?? true;
                      //         });
                      //       },
                      //       activeColor: AppColors.primary,
                      //     ),
                      //     Text(
                      //       'Enabled',
                      //       style: TextStyle(
                      //         fontSize: AppSizes.fontM,
                      //         color: AppColors.textPrimary,
                      //         fontFamily: 'Roboto',
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                ElevatedButton(
                  onPressed: _handleSave,
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
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        const SizedBox(width: AppSizes.paddingM),
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.5),
                fontFamily: 'Roboto',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(
                  color: AppColors.textSecondary,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(
                  color: AppColors.textSecondary,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(color: AppColors.error),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
                vertical: AppSizes.paddingM,
              ),
            ),
            style: TextStyle(
              fontFamily: 'Roboto',
              color: AppColors.textPrimary,
            ),
            validator: validator,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required int? value,
    required List<DropdownMenuItem<int>> items,
    required void Function(int?) onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        const SizedBox(width: AppSizes.paddingM),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: value,
            hint: Text(
              hint,
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.5),
                fontFamily: 'Roboto',
              ),
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(
                  color: AppColors.textSecondary,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(
                  color: AppColors.textSecondary,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                borderSide: BorderSide(color: AppColors.error),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
                vertical: AppSizes.paddingM,
              ),
            ),
            style: TextStyle(
              fontFamily: 'Roboto',
              color: AppColors.textPrimary,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingField(String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        const SizedBox(width: AppSizes.paddingM),
        const Expanded(
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String message) {
    return Text(
      message,
      style: TextStyle(
        fontSize: AppSizes.fontM,
        color: AppColors.error,
        fontFamily: 'Roboto',
      ),
      textAlign: TextAlign.center,
    );
  }
}
