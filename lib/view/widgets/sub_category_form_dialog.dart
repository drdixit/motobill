import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/sub_category.dart';
import '../../../view_model/sub_category_viewmodel.dart';

class SubCategoryFormDialog extends ConsumerStatefulWidget {
  final SubCategory? subCategory;
  final Function(SubCategory) onSave;

  const SubCategoryFormDialog({
    super.key,
    this.subCategory,
    required this.onSave,
  });

  @override
  ConsumerState<SubCategoryFormDialog> createState() =>
      _SubCategoryFormDialogState();
}

class _SubCategoryFormDialogState extends ConsumerState<SubCategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late bool _isEnabled;
  String? _selectedImageFileName;
  int? _selectedMainCategoryId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.subCategory?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.subCategory?.description ?? '',
    );
    _isEnabled = widget.subCategory?.isEnabled ?? true;
    _selectedImageFileName = widget.subCategory?.image;
    _selectedMainCategoryId = widget.subCategory?.mainCategoryId;
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
      // Additional validation: main category must be selected
      if (_selectedMainCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a main category'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final subCategory = SubCategory(
        id: widget.subCategory?.id,
        mainCategoryId: _selectedMainCategoryId!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        image: _selectedImageFileName,
        isEnabled: _isEnabled,
      );

      try {
        widget.onSave(subCategory);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving sub category: $e'),
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
    final mainCategoriesAsync = ref.watch(mainCategoriesListProvider);

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
                  widget.subCategory == null
                      ? 'New Sub Category'
                      : 'Edit Sub Category',
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
              child: mainCategoriesAsync.when(
                data: (mainCategories) {
                  // Filter only enabled main categories
                  final enabledCategories = mainCategories
                      .where((cat) => cat.isEnabled)
                      .toList();

                  if (enabledCategories.isEmpty) {
                    return Center(
                      child: Text(
                        'No active main categories available.\nPlease create and enable a main category first.',
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          color: AppColors.textSecondary,
                          fontFamily: 'Roboto',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  // Validate that selected value exists in filtered list
                  final validMainCategoryId =
                      _selectedMainCategoryId != null &&
                          enabledCategories.any(
                            (cat) => cat.id == _selectedMainCategoryId,
                          )
                      ? _selectedMainCategoryId
                      : null;

                  return SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Main Category dropdown
                          _buildDropdownField(
                            label: 'Main Category *',
                            hint: 'Select Main Category',
                            value: validMainCategoryId,
                            items: enabledCategories.map((category) {
                              return DropdownMenuItem<int>(
                                value: category.id,
                                child: Text(category.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedMainCategoryId = value;
                              });
                            },
                          ),
                          const SizedBox(height: AppSizes.paddingM),
                          _buildTextField(
                            controller: _nameController,
                            label: 'Name *',
                            hint: 'Sub Category Name',
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
                            hint: 'Sub Category Description',
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
                          // Enabled checkbox - Commented out: Sub Categories are always enabled
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
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(
                    'Error loading main categories: $error',
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      color: AppColors.error,
                      fontFamily: 'Roboto',
                    ),
                    textAlign: TextAlign.center,
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
}
