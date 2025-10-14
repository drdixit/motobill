import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../view_model/pos_viewmodel.dart';
import '../widgets/pos/pos_filters.dart';
import '../widgets/pos/pos_product_card.dart';
import '../widgets/pos/pos_cart.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String? _lastShownError;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posViewModelProvider);

    // Show error dialog when error occurs
    if (state.error != null && state.error != _lastShownError) {
      _lastShownError = state.error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog(context, state.error!);
      });
    } else if (state.error == null) {
      _lastShownError = null;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left: Filters
          const PosFilters(),

          // Middle: Products Grid
          Expanded(child: _buildProductsSection(state, ref)),

          // Right: Cart
          const PosCart(),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: AppSizes.iconL,
            ),
            const SizedBox(width: AppSizes.paddingS),
            Text(
              'Error',
              style: TextStyle(
                fontSize: AppSizes.fontXL,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          error,
          style: TextStyle(
            fontSize: AppSizes.fontM,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear the error after dismissing dialog
              ref.read(posViewModelProvider.notifier).clearError();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL,
                vertical: AppSizes.paddingM,
              ),
            ),
            child: Text(
              'OK',
              style: TextStyle(
                fontSize: AppSizes.fontM,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(PosState state, WidgetRef ref) {
    return Column(
      children: [
        // Header
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingM,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2, size: AppSizes.iconM),
              const SizedBox(width: AppSizes.paddingS),
              Text(
                'Products',
                style: TextStyle(
                  fontSize: AppSizes.fontL,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(child: _buildSearchBar(ref, state)),
              const SizedBox(width: AppSizes.paddingM),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingS,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Text(
                  '${state.filteredProducts.length}',
                  style: TextStyle(
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Products Grid or Loading
        Expanded(
          child: state.isLoading
              ? _buildLoading()
              : state.filteredProducts.isEmpty
              ? _buildEmptyState()
              : _buildProductsGrid(state, ref),
        ),
      ],
    );
  }

  Widget _buildSearchBar(WidgetRef ref, PosState state) {
    final viewModel = ref.read(posViewModelProvider.notifier);

    return TextField(
      decoration: InputDecoration(
        hintText: 'Search by name or part number...',
        hintStyle: TextStyle(
          fontSize: AppSizes.fontM,
          color: AppColors.textTertiary,
        ),
        prefixIcon: Icon(Icons.search, size: AppSizes.iconM),
        suffixIcon: state.searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: AppSizes.iconM),
                onPressed: () => viewModel.setSearchQuery(''),
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: AppSizes.paddingS,
        ),
        isDense: true,
      ),
      onChanged: (value) => viewModel.setSearchQuery(value),
    );
  }

  Widget _buildProductsGrid(PosState state, WidgetRef ref) {
    final viewModel = ref.read(posViewModelProvider.notifier);

    return GridView.builder(
      padding: const EdgeInsets.all(AppSizes.paddingS),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: AppSizes.paddingS,
        mainAxisSpacing: AppSizes.paddingS,
      ),
      itemCount: state.filteredProducts.length,
      itemBuilder: (context, index) {
        final product = state.filteredProducts[index];
        final cartItem = state.cartItems
            .where((item) => item.productId == product.id)
            .firstOrNull;
        final cartQuantity = cartItem?.quantity ?? 0;

        return PosProductCard(
          product: product,
          cartQuantity: cartQuantity,
          onTap: () => viewModel.addToCart(product),
          onSecondaryTap: () {
            if (cartQuantity > 1) {
              viewModel.updateCartItemQuantity(product.id, cartQuantity - 1);
            } else if (cartQuantity == 1) {
              viewModel.removeFromCart(product.id);
            }
          },
        );
      },
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'Loading products...',
            style: TextStyle(
              fontSize: AppSizes.fontM,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: AppSizes.iconXL * 2,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: AppSizes.fontM,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
