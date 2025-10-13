import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../view_model/pos_viewmodel.dart';
import '../widgets/pos/pos_filters.dart';
import '../widgets/pos/pos_product_card.dart';
import '../widgets/pos/pos_cart.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posViewModelProvider);

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

  Widget _buildProductsSection(PosState state, WidgetRef ref) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(AppSizes.paddingM),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingM,
                  vertical: AppSizes.paddingS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Text(
                  '${state.filteredProducts.length} items',
                  style: TextStyle(
                    fontSize: AppSizes.fontM,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(child: _buildSearchBar(ref, state)),
            ],
          ),
        ),

        // Products Grid or Loading/Error
        Expanded(
          child: state.isLoading
              ? _buildLoading()
              : state.error != null
              ? _buildError(state.error!)
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
        hintText: 'Search products...',
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
      padding: const EdgeInsets.all(AppSizes.paddingM),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.85,
        crossAxisSpacing: AppSizes.paddingM,
        mainAxisSpacing: AppSizes.paddingM,
      ),
      itemCount: state.filteredProducts.length,
      itemBuilder: (context, index) {
        final product = state.filteredProducts[index];
        return PosProductCard(
          product: product,
          onTap: () => viewModel.addToCart(product),
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

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: AppSizes.iconXL * 1.5,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'Error',
              style: TextStyle(
                fontSize: AppSizes.fontXL,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              error,
              style: TextStyle(
                fontSize: AppSizes.fontM,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
