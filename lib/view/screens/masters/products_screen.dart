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
      final description = product.description?.toLowerCase() ?? '';
      return name.contains(query) ||
          partNumber.contains(query) ||
          description.contains(query);
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
                      hintText:
                          'Search by name or part number or description...',
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(strokeWidth: 6),
                        ),
                        const SizedBox(height: AppSizes.paddingL),
                        Text(
                          'Loading all products...',
                          style: TextStyle(
                            fontSize: AppSizes.fontL,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.paddingS),
                        Text(
                          'This may take a few seconds',
                          style: TextStyle(
                            fontSize: AppSizes.fontM,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : productState.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: AppSizes.paddingM),
                        Text(
                          'Error loading products',
                          style: TextStyle(
                            fontSize: AppSizes.fontL,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.paddingS),
                        Text(
                          productState.error!,
                          style: TextStyle(
                            fontSize: AppSizes.fontM,
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSizes.paddingL),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(productViewModelProvider.notifier)
                                .loadProducts();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSizes.paddingM),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No products found'
                              : 'No products match your search',
                          style: TextStyle(
                            fontSize: AppSizes.fontL,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Info bar showing count and search results
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingL,
                          vertical: AppSizes.paddingS,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          border: Border(
                            bottom: BorderSide(color: AppColors.divider),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSizes.paddingS),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Total: ${productState.products.length} products'
                                  : 'Found: ${filteredProducts.length} of ${productState.products.length} products',
                              style: TextStyle(
                                fontSize: AppSizes.fontS,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppSizes.paddingL),
                          itemCount: filteredProducts.length,
                          // Aggressive performance optimizations for fast scrolling
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          addSemanticIndexes: false,
                          // Increase cache for smoother fast scrolling - aggressive caching
                          cacheExtent: 5000,
                          // Fixed height improves scrolling performance drastically
                          itemExtent: 112,
                          // Better scroll physics for fast scrolling
                          physics: const ClampingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSizes.paddingM,
                              ),
                              child: _buildProductCard(context, ref, product),
                            );
                          },
                        ),
                      ),
                    ],
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
    // Wrap in RepaintBoundary to isolate repaints
    return RepaintBoundary(
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              // Image thumbnail
              RepaintBoundary(child: _buildImageThumbnail(ref, product)),
              const SizedBox(width: AppSizes.paddingM),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.partNumber != null
                          ? '${product.name} (${product.partNumber})'
                          : product.name,
                      style: const TextStyle(
                        fontSize: AppSizes.fontL,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Roboto',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Row(
                      children: [
                        Text(
                          'Cost: ₹${product.costPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: AppSizes.fontM,
                            color: AppColors.textSecondary,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Text(
                          'Selling: ₹${product.sellingPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: AppSizes.fontM,
                            color: AppColors.textSecondary,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        if (product.mrp != null) ...[
                          const SizedBox(width: AppSizes.paddingM),
                          Text(
                            'MRP: ₹${product.mrp!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: AppSizes.fontM,
                              color: AppColors.textSecondary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
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
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(WidgetRef ref, Product product) {
    // Use keepAlive provider to prevent rebuilding during fast scrolling
    final primaryImageAsync = ref.watch(productImagesProvider(product.id!));

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
        child: primaryImageAsync.when(
          data: (images) {
            final primaryImage = images
                .where((img) => img.isPrimary)
                .firstOrNull;
            if (primaryImage == null) {
              return _buildPlaceholder('No\nImage', Icons.image_not_supported);
            }
            final imagePath =
                'C:\\motobill\\database\\images\\${primaryImage.imagePath}';
            return Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              // Optimize image decoding for fast scrolling
              cacheWidth: 160,
              cacheHeight: 160,
              // Use FilterQuality.low for faster rendering during scrolling
              filterQuality: FilterQuality.low,
              // Prevent unnecessary rebuilds
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholder('Broken\nLink', Icons.broken_image);
              },
            );
          },
          loading: () => Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          error: (error, stack) =>
              _buildPlaceholder('Error', Icons.error_outline),
        ),
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
