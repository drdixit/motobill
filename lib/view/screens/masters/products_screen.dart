import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/product.dart';
import '../../../view_model/product_viewmodel.dart';
import '../../widgets/product_form_dialog.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(productViewModelProvider.notifier).loadProducts(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_searchQuery.isEmpty) return products;

    final query = _searchQuery.toLowerCase();
    return products.where((product) {
      final name = product.name.toLowerCase();
      final partNumber = product.partNumber?.toLowerCase() ?? '';
      return name.contains(query) || partNumber.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productViewModelProvider);
    final filteredProducts = _filterProducts(productState.products);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or part number...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppSizes.fontM,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                        vertical: AppSizes.paddingM,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingL),
                ElevatedButton.icon(
                  onPressed: () => _showProductDialog(context, ref, null),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New Product'),
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
          Expanded(
            child: productState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : productState.error != null
                ? Center(
                    child: Text(
                      'Error: ${productState.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                : filteredProducts.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No products found'
                          : 'No products match your search',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    itemCount: filteredProducts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSizes.paddingM),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductCard(context, ref, product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    WidgetRef ref,
    Product product,
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
          _buildImageThumbnail(ref, product),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.partNumber != null
                      ? '${product.name} (${product.partNumber})'
                      : product.name,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Row(
                  children: [
                    Text(
                      'Cost: ₹${product.costPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: AppColors.textSecondary,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Text(
                      'Selling: ₹${product.sellingPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: AppColors.textSecondary,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    if (product.isTaxable)
                      const Padding(
                        padding: EdgeInsets.only(left: AppSizes.paddingM),
                        child: Text(
                          '(Taxable)',
                          style: TextStyle(
                            fontSize: AppSizes.fontS,
                            color: AppColors.textSecondary,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                color: AppColors.primary,
                onPressed: () => _showProductDialog(context, ref, product),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(
                  product.isEnabled ? Icons.toggle_on : Icons.toggle_off,
                  size: 36,
                ),
                color: product.isEnabled
                    ? AppColors.success
                    : AppColors.textSecondary,
                onPressed: () => _toggleProduct(ref, product),
                tooltip: product.isEnabled ? 'Disable' : 'Enable',
              ),
              // Delete button - Hidden
              // IconButton(
              //   icon: const Icon(Icons.delete, size: 20),
              //   color: AppColors.error,
              //   onPressed: () => _deleteProduct(context, ref, product),
              //   tooltip: 'Delete',
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(WidgetRef ref, Product product) {
    final primaryImageAsync = ref.watch(productImagesProvider(product.id!));

    return primaryImageAsync.when(
      data: (images) {
        final primaryImage = images.where((img) => img.isPrimary).firstOrNull;
        final imagePath = primaryImage != null
            ? 'C:\\motobill\\database\\images\\${primaryImage.imagePath}'
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
                      return _buildPlaceholder(
                        'Broken\nLink',
                        Icons.broken_image,
                      );
                    },
                  )
                : _buildPlaceholder('No\nImage', Icons.image_not_supported),
          ),
        );
      },
      loading: () => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          border: Border.all(color: AppColors.divider),
        ),
        child: _buildPlaceholder('Error', Icons.error),
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

  void _showProductDialog(
    BuildContext context,
    WidgetRef ref,
    Product? product,
  ) {
    showDialog(
      context: context,
      builder: (context) => ProductFormDialog(
        product: product,
        onSave:
            (
              product,
              imageFileNames,
              primaryIndex,
              existingPrimaryImageId,
              deletedImageIds,
            ) async {
              try {
                if (product.id == null) {
                  final productId = await ref
                      .read(productViewModelProvider.notifier)
                      .addProduct(product);

                  // Add images with primary flag based on primaryIndex
                  for (int i = 0; i < imageFileNames.length; i++) {
                    await ref
                        .read(productViewModelProvider.notifier)
                        .addProductImage(
                          productId,
                          imageFileNames[i],
                          i == primaryIndex, // Mark selected image as primary
                        );
                  }
                  // Invalidate the images provider to refresh the UI
                  ref.invalidate(productImagesProvider(productId));
                } else {
                  await ref
                      .read(productViewModelProvider.notifier)
                      .updateProduct(product);

                  // Update existing image primary status if changed
                  if (existingPrimaryImageId != null) {
                    await ref
                        .read(productViewModelProvider.notifier)
                        .setPrimaryImage(product.id!, existingPrimaryImageId);
                  }

                  // Add new images for existing product
                  if (imageFileNames.isNotEmpty) {
                    // primaryIndex is the index within the NEW images list
                    // If it's -1, it means an existing image is primary (don't change)
                    // If it's >= 0, mark that new image as primary
                    for (int i = 0; i < imageFileNames.length; i++) {
                      await ref
                          .read(productViewModelProvider.notifier)
                          .addProductImage(
                            product.id!,
                            imageFileNames[i],
                            i == primaryIndex && primaryIndex >= 0,
                          );
                    }
                  }

                  // Invalidate the images provider to refresh the UI
                  ref.invalidate(productImagesProvider(product.id!));
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
      ),
    );
  }

  void _toggleProduct(WidgetRef ref, Product product) {
    ref
        .read(productViewModelProvider.notifier)
        .toggleProductStatus(product.id!, !product.isEnabled);
  }

  // Delete functionality - Hidden
  // void _deleteProduct(BuildContext context, WidgetRef ref, Product product) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Delete Product'),
  //       content: Text('Are you sure you want to delete ${product.name}?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('Cancel'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             ref
  //                 .read(productViewModelProvider.notifier)
  //                 .deleteProduct(product.id!);
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
