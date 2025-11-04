import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../model/product.dart';
import '../../view_model/product_viewmodel.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product;
  final Function(Product, List<String>, int, int?, List<int>) onSave;

  const ProductFormDialog({super.key, this.product, required this.onSave});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _partNumberController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _mrpController;
  late bool _isEnabled;
  late bool _isTaxable;
  late bool _negativeAllow;
  int? _selectedSubCategoryId;
  int? _selectedManufacturerId;
  int? _selectedHsnCodeId;
  int? _selectedUqcId;

  final List<String> _imageFileNames = [];
  final List<String> _newImageFileNames = []; // Track newly uploaded images
  final List<ProductImage> _existingImages =
      []; // Track existing images with IDs
  final List<int> _imagesToDelete = []; // Track image IDs to soft delete
  int _primaryImageIndex = 0;
  int _initialPrimaryIndex = 0; // Track initial primary to detect changes

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _partNumberController = TextEditingController(
      text: widget.product?.partNumber ?? '',
    );
    _costPriceController = TextEditingController(
      text: widget.product?.costPrice.toString() ?? '',
    );
    _sellingPriceController = TextEditingController(
      text: widget.product?.sellingPrice.toString() ?? '',
    );
    _mrpController = TextEditingController(
      text: widget.product?.mrp?.toString() ?? '',
    );
    _isEnabled = widget.product?.isEnabled ?? true;
    _isTaxable = widget.product?.isTaxable ?? false;
    _negativeAllow = widget.product?.negativeAllow ?? false;
    _selectedSubCategoryId = widget.product?.subCategoryId;
    _selectedManufacturerId = widget.product?.manufacturerId;
    _selectedHsnCodeId = widget.product?.hsnCodeId;
    _selectedUqcId = widget.product?.uqcId;

    // Load existing images if editing
    if (widget.product != null && widget.product!.id != null) {
      _loadExistingImages();
    }
  }

  Future<void> _loadExistingImages() async {
    try {
      final images = await ref.read(
        productImagesProvider(widget.product!.id!).future,
      );

      if (images.isNotEmpty && mounted) {
        setState(() {
          _imageFileNames.clear();
          _existingImages.clear();
          _existingImages.addAll(images);
          _imageFileNames.addAll(images.map((img) => img.imagePath));
          // Find primary image index
          final primaryIndex = images.indexWhere((img) => img.isPrimary);
          _primaryImageIndex = primaryIndex >= 0 ? primaryIndex : 0;
          _initialPrimaryIndex = _primaryImageIndex;
        });
      }
    } catch (e) {
      // Ignore errors loading existing images
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _partNumberController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAddImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          final sourcePath = file.path;
          if (sourcePath != null) {
            final uuid = const Uuid();
            final extension = path.extension(sourcePath);
            final uniqueFileName = '${uuid.v4()}$extension';
            final destinationPath =
                'C:\\motobill\\database\\images\\$uniqueFileName';
            final sourceFile = File(sourcePath);
            await sourceFile.copy(destinationPath);
            setState(() {
              _imageFileNames.add(uniqueFileName);
              _newImageFileNames.add(uniqueFileName); // Track as new image
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading images: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeImage(int index) async {
    final fileName = _imageFileNames[index];

    // If this is an existing image, mark it for deletion
    if (index < _existingImages.length) {
      final imageToDelete = _existingImages[index];
      if (imageToDelete.id != null) {
        // Immediately soft delete from database
        try {
          await ref
              .read(productViewModelProvider.notifier)
              .removeProductImage(imageToDelete.id!);
          _imagesToDelete.add(imageToDelete.id!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error removing image: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return; // Don't remove from UI if database delete failed
        }
      }
    }

    setState(() {
      _imageFileNames.removeAt(index);

      // Remove from new images if it exists there
      _newImageFileNames.remove(fileName);

      // Remove from existing images if applicable
      if (index < _existingImages.length) {
        _existingImages.removeAt(index);
      }

      if (_primaryImageIndex >= _imageFileNames.length &&
          _imageFileNames.isNotEmpty) {
        _primaryImageIndex = _imageFileNames.length - 1;
      } else if (_imageFileNames.isEmpty) {
        _primaryImageIndex = 0;
      }
    });

    // Invalidate the provider to refresh the image list
    if (widget.product?.id != null) {
      ref.invalidate(productImagesProvider(widget.product!.id!));
    }
  }

  void _setPrimaryImage(int index) {
    setState(() {
      _primaryImageIndex = index;
    });
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      if (_selectedSubCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a sub category'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedManufacturerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a manufacturer'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedHsnCodeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an HSN code'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedUqcId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a UQC'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final costPrice = double.tryParse(_costPriceController.text);
      final sellingPrice = double.tryParse(_sellingPriceController.text);

      if (costPrice == null || costPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cost price must be greater than 0'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (sellingPrice == null || sellingPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selling price must be greater than 0'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (sellingPrice < costPrice) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Warning'),
            content: const Text(
              'Selling price is less than cost price. This will result in a loss. Do you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveProduct();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        return;
      }

      _saveProduct();
    }
  }

  void _saveProduct() {
    final mrpText = _mrpController.text.trim();
    final mrp = mrpText.isEmpty ? null : double.tryParse(mrpText);

    final product = Product(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      partNumber: _partNumberController.text.trim().isEmpty
          ? null
          : _partNumberController.text.trim(),
      hsnCodeId: _selectedHsnCodeId!,
      uqcId: _selectedUqcId!,
      costPrice: double.parse(_costPriceController.text),
      sellingPrice: double.parse(_sellingPriceController.text),
      mrp: mrp,
      subCategoryId: _selectedSubCategoryId!,
      manufacturerId: _selectedManufacturerId!,
      isTaxable: _isTaxable,
      negativeAllow: _negativeAllow,
      isEnabled: _isEnabled,
    );

    // For new products, pass all images. For edits, pass only new images
    final imagesToSave = widget.product?.id == null
        ? _imageFileNames
        : _newImageFileNames;

    // Calculate the primary index within the new images list
    // Also determine if we need to update an existing image's primary status
    int primaryIndexForNewImages = _primaryImageIndex;
    int? existingPrimaryImageId;

    if (widget.product?.id != null) {
      // Editing existing product
      if (_newImageFileNames.isNotEmpty) {
        // Get the filename at primary index
        final primaryFileName = _imageFileNames[_primaryImageIndex];
        // Find its index in new images (or -1 if it's an existing image)
        primaryIndexForNewImages = _newImageFileNames.indexOf(primaryFileName);
      }

      // Check if primary changed to an existing image
      if (_primaryImageIndex != _initialPrimaryIndex &&
          _primaryImageIndex < _existingImages.length) {
        existingPrimaryImageId = _existingImages[_primaryImageIndex].id;
      }
    }

    widget.onSave(
      product,
      imagesToSave,
      primaryIndexForNewImages,
      existingPrimaryImageId,
      _imagesToDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subCategoriesAsync = ref.watch(subCategoriesForProductProvider);
    final manufacturersAsync = ref.watch(manufacturersForProductProvider);
    final hsnCodesAsync = ref.watch(hsnCodesListProvider);
    final uqcsAsync = ref.watch(uqcsListProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 800),
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product == null ? 'New Product' : 'Edit Product',
                style: const TextStyle(
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Name *',
                        style: TextStyle(fontSize: AppSizes.fontL),
                      ),
                      const SizedBox(height: AppSizes.paddingS),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter product name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Product name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      const Text(
                        'Part Number',
                        style: TextStyle(fontSize: AppSizes.fontL),
                      ),
                      const SizedBox(height: AppSizes.paddingS),
                      TextFormField(
                        controller: _partNumberController,
                        decoration: InputDecoration(
                          hintText: 'Enter part number (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sub Category *',
                                  style: TextStyle(fontSize: AppSizes.fontL),
                                ),
                                const SizedBox(height: AppSizes.paddingS),
                                subCategoriesAsync.when(
                                  data: (subCategories) {
                                    if (subCategories.isEmpty) {
                                      return const Text(
                                        'No sub categories available',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      );
                                    }
                                    // Validate that selected value exists in list
                                    final validValue =
                                        _selectedSubCategoryId != null &&
                                            subCategories.any(
                                              (sc) =>
                                                  sc.id ==
                                                  _selectedSubCategoryId,
                                            )
                                        ? _selectedSubCategoryId
                                        : null;
                                    return DropdownButtonFormField<int>(
                                      value: validValue,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusS,
                                          ),
                                        ),
                                      ),
                                      hint: const Text('Select sub category'),
                                      items: subCategories.map((sc) {
                                        return DropdownMenuItem<int>(
                                          value: sc.id,
                                          child: Text(
                                            sc.name,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedSubCategoryId = value;
                                        });
                                      },
                                    );
                                  },
                                  loading: () =>
                                      const CircularProgressIndicator(),
                                  error: (error, stack) => Text(
                                    'Error: $error',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Manufacturer *',
                                  style: TextStyle(fontSize: AppSizes.fontL),
                                ),
                                const SizedBox(height: AppSizes.paddingS),
                                manufacturersAsync.when(
                                  data: (manufacturers) {
                                    if (manufacturers.isEmpty) {
                                      return const Text(
                                        'No manufacturers available',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      );
                                    }
                                    // Validate that selected value exists in list
                                    final validValue =
                                        _selectedManufacturerId != null &&
                                            manufacturers.any(
                                              (m) =>
                                                  m.id ==
                                                  _selectedManufacturerId,
                                            )
                                        ? _selectedManufacturerId
                                        : null;
                                    return DropdownButtonFormField<int>(
                                      value: validValue,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusS,
                                          ),
                                        ),
                                      ),
                                      hint: const Text('Select manufacturer'),
                                      items: manufacturers.map((m) {
                                        return DropdownMenuItem<int>(
                                          value: m.id,
                                          child: Text(
                                            m.name,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedManufacturerId = value;
                                        });
                                      },
                                    );
                                  },
                                  loading: () =>
                                      const CircularProgressIndicator(),
                                  error: (error, stack) => Text(
                                    'Error: $error',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'HSN Code *',
                                  style: TextStyle(fontSize: AppSizes.fontL),
                                ),
                                const SizedBox(height: AppSizes.paddingS),
                                hsnCodesAsync.when(
                                  data: (hsnCodes) {
                                    if (hsnCodes.isEmpty) {
                                      return const Text(
                                        'No HSN codes available',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      );
                                    }

                                    // Find the initially selected HSN code
                                    final selectedHsn =
                                        _selectedHsnCodeId != null
                                        ? hsnCodes.firstWhere(
                                            (hsn) =>
                                                hsn.id == _selectedHsnCodeId,
                                            orElse: () => hsnCodes.first,
                                          )
                                        : null;

                                    return Autocomplete<HsnCode>(
                                      initialValue: selectedHsn != null
                                          ? TextEditingValue(
                                              text:
                                                  '${selectedHsn.code} - ${selectedHsn.description ?? ''}',
                                            )
                                          : const TextEditingValue(),
                                      optionsBuilder: (textEditingValue) {
                                        if (textEditingValue.text.isEmpty) {
                                          return hsnCodes;
                                        }
                                        final text = textEditingValue.text
                                            .toLowerCase();
                                        return hsnCodes.where((hsn) {
                                          final code = hsn.code.toLowerCase();
                                          final desc = (hsn.description ?? '')
                                              .toLowerCase();
                                          return code.contains(text) ||
                                              desc.contains(text);
                                        });
                                      },
                                      displayStringForOption: (hsn) =>
                                          '${hsn.code} - ${hsn.description ?? ''}',
                                      onSelected: (hsn) {
                                        setState(() {
                                          _selectedHsnCodeId = hsn.id;
                                        });
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        final optionsList = options.toList();
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxHeight: 200,
                                                maxWidth: 400,
                                              ),
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: optionsList.length,
                                                itemExtent: 48,
                                                cacheExtent: 500,
                                                addAutomaticKeepAlives: false,
                                                addRepaintBoundaries: true,
                                                itemBuilder: (context, index) {
                                                  final hsn =
                                                      optionsList[index];
                                                  return InkWell(
                                                    onTap: () =>
                                                        onSelected(hsn),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                      child: Text(
                                                        '${hsn.code} - ${hsn.description ?? ''}',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      fieldViewBuilder:
                                          (
                                            context,
                                            controller,
                                            focusNode,
                                            onSubmitted,
                                          ) {
                                            return TextFormField(
                                              controller: controller,
                                              focusNode: focusNode,
                                              decoration: InputDecoration(
                                                hintText: 'Search HSN code...',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSizes.radiusS,
                                                      ),
                                                ),
                                              ),
                                              onFieldSubmitted: (_) =>
                                                  onSubmitted(),
                                            );
                                          },
                                    );
                                  },
                                  loading: () =>
                                      const CircularProgressIndicator(),
                                  error: (error, stack) => Text(
                                    'Error: $error',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'UQC *',
                                  style: TextStyle(fontSize: AppSizes.fontL),
                                ),
                                const SizedBox(height: AppSizes.paddingS),
                                uqcsAsync.when(
                                  data: (uqcs) {
                                    if (uqcs.isEmpty) {
                                      return const Text(
                                        'No UQCs available',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      );
                                    }
                                    // Validate that selected value exists in list
                                    final validValue =
                                        _selectedUqcId != null &&
                                            uqcs.any(
                                              (uqc) => uqc.id == _selectedUqcId,
                                            )
                                        ? _selectedUqcId
                                        : null;
                                    return DropdownButtonFormField<int>(
                                      value: validValue,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusS,
                                          ),
                                        ),
                                      ),
                                      hint: const Text('Select UQC'),
                                      items: uqcs.map((uqc) {
                                        return DropdownMenuItem<int>(
                                          value: uqc.id,
                                          child: Text(
                                            '${uqc.code} - ${uqc.description ?? ''}',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedUqcId = value;
                                        });
                                      },
                                    );
                                  },
                                  loading: () =>
                                      const CircularProgressIndicator(),
                                  error: (error, stack) => Text(
                                    'Error: $error',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cost Price *',
                                  style: TextStyle(fontSize: AppSizes.fontL),
                                ),
                                const SizedBox(height: AppSizes.paddingS),
                                TextFormField(
                                  controller: _costPriceController,
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusS,
                                      ),
                                    ),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Cost price is required';
                                    }
                                    final price = double.tryParse(value);
                                    if (price == null || price <= 0) {
                                      return 'Invalid price';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selling Price *',
                                  style: TextStyle(fontSize: AppSizes.fontL),
                                ),
                                const SizedBox(height: AppSizes.paddingS),
                                TextFormField(
                                  controller: _sellingPriceController,
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusS,
                                      ),
                                    ),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Selling price is required';
                                    }
                                    final price = double.tryParse(value);
                                    if (price == null || price <= 0) {
                                      return 'Invalid price';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      const Text(
                        'MRP (Optional)',
                        style: TextStyle(fontSize: AppSizes.fontL),
                      ),
                      const SizedBox(height: AppSizes.paddingS),
                      TextFormField(
                        controller: _mrpController,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusS,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Invalid MRP';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      Row(
                        children: [
                          Checkbox(
                            value: _isTaxable,
                            onChanged: (value) {
                              setState(() {
                                _isTaxable = value ?? false;
                              });
                            },
                          ),
                          const Text('Taxable'),
                          const SizedBox(width: AppSizes.paddingL),
                          Checkbox(
                            value: _isEnabled,
                            onChanged: (value) {
                              setState(() {
                                _isEnabled = value ?? true;
                              });
                            },
                          ),
                          const Text('Enabled'),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      Row(
                        children: [
                          Checkbox(
                            value: _negativeAllow,
                            onChanged: (value) {
                              setState(() {
                                _negativeAllow = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Allow Negative Stock',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontM,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'When enabled, bills can be created even when stock is insufficient. System will automatically create purchase records.',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontS,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingM),
                      const Text(
                        'Product Images',
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingS),
                      OutlinedButton.icon(
                        onPressed: _pickAndAddImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Images'),
                      ),
                      const SizedBox(height: AppSizes.paddingS),
                      if (_imageFileNames.isNotEmpty)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: AppSizes.paddingS,
                                mainAxisSpacing: AppSizes.paddingS,
                                childAspectRatio: 1,
                              ),
                          itemCount: _imageFileNames.length,
                          itemBuilder: (context, index) {
                            final imagePath =
                                'C:\\motobill\\database\\images\\${_imageFileNames[index]}';
                            final file = File(imagePath);
                            final isPrimary = index == _primaryImageIndex;

                            return Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => _setPrimaryImage(index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isPrimary
                                            ? AppColors.primary
                                            : Colors.grey,
                                        width: isPrimary ? 3 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusS,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusS,
                                      ),
                                      child: file.existsSync()
                                          ? Image.file(
                                              file,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            )
                                          : Container(
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.broken_image,
                                                size: 40,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                if (isPrimary)
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'PRIMARY',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton(
                                    icon: const Icon(Icons.close),
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _removeImage(index),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  ElevatedButton(
                    onPressed: _handleSave,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
