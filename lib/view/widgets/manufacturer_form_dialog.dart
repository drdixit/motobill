import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/manufacturer.dart';

class ManufacturerFormDialog extends StatefulWidget {
  final Manufacturer? manufacturer;
  final Function(Manufacturer) onSave;

  const ManufacturerFormDialog({
    super.key,
    this.manufacturer,
    required this.onSave,
  });

  @override
  State<ManufacturerFormDialog> createState() => _ManufacturerFormDialogState();
}

class _ManufacturerFormDialogState extends State<ManufacturerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late bool _isEnabled;
  String? _selectedImageFileName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.manufacturer?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.manufacturer?.description ?? '',
    );
    _isEnabled = widget.manufacturer?.isEnabled ?? true;
    _selectedImageFileName = widget.manufacturer?.image;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      final manufacturer = Manufacturer(
        id: widget.manufacturer?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        image: _selectedImageFileName,
        isEnabled: _isEnabled,
      );
      widget.onSave(manufacturer);
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
                  widget.manufacturer == null
                      ? 'New Manufacturer'
                      : 'Edit Manufacturer',
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
                      _buildTextField(
                        controller: _nameController,
                        label: 'Name *',
                        hint: 'Manufacturer Name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Manufacturer Description',
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
                      // Enabled checkbox - Commented out: Manufacturers are always enabled
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
          ),
        ),
      ],
    );
  }
}
