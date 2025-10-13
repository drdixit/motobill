import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../view_model/pos_viewmodel.dart';
import '../../../model/bill.dart';

class PosCart extends ConsumerWidget {
  const PosCart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posViewModelProvider);
    final viewModel = ref.read(posViewModelProvider.notifier);

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
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
                Icon(Icons.shopping_cart, size: AppSizes.iconM),
                const SizedBox(width: AppSizes.paddingS),
                Text(
                  'Cart',
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (state.cartItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: Text(
                      '${state.totalItems}',
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

          // Cart Items
          Expanded(
            child: state.cartItems.isEmpty
                ? _buildEmptyCart()
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    itemCount: state.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = state.cartItems[index];
                      return _buildCartItem(context, item, viewModel);
                    },
                  ),
          ),

          // Summary and Actions
          if (state.cartItems.isNotEmpty)
            _buildCartSummary(state, viewModel, context),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: AppSizes.iconXL * 1.5,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'Cart is empty',
            style: TextStyle(
              fontSize: AppSizes.fontL,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            'Add products to get started',
            style: TextStyle(
              fontSize: AppSizes.fontM,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    BillItem item,
    PosViewModel viewModel,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingM),
      elevation: 0,
      color: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.partNumber != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.partNumber!,
                          style: TextStyle(
                            fontSize: AppSizes.fontS,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: AppSizes.iconM,
                    color: AppColors.error,
                  ),
                  onPressed: () => viewModel.removeFromCart(item.productId),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            Row(
              children: [
                // Quantity Controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: AppSizes.iconS),
                        onPressed: () {
                          viewModel.updateCartItemQuantity(
                            item.productId,
                            item.quantity - 1,
                          );
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingM,
                        ),
                        child: Text(
                          '${item.quantity}',
                          style: TextStyle(
                            fontSize: AppSizes.fontM,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: AppSizes.iconS),
                        onPressed: () {
                          viewModel.updateCartItemQuantity(
                            item.productId,
                            item.quantity + 1,
                          );
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Price
                Text(
                  '₹${item.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            // Tax info
            if (item.taxAmount > 0) ...[
              const SizedBox(height: AppSizes.paddingS),
              Text(
                'Tax: ₹${item.taxAmount.toStringAsFixed(2)} (${(item.cgstRate + item.sgstRate).toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: AppSizes.fontXS,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(
    PosState state,
    PosViewModel viewModel,
    BuildContext context,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        children: [
          // Subtotal
          _buildSummaryRow('Subtotal:', state.subtotal),
          const SizedBox(height: AppSizes.paddingS),

          // Tax
          _buildSummaryRow('Tax:', state.taxAmount),
          const SizedBox(height: AppSizes.paddingS),

          // Divider
          Divider(color: AppColors.border, thickness: 1),
          const SizedBox(height: AppSizes.paddingS),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: TextStyle(
                  fontSize: AppSizes.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '₹${state.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingL),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => viewModel.clearCart(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.paddingM,
                    ),
                    side: BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Navigate to checkout or save bill
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Checkout functionality coming soon'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.paddingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                  child: Text(
                    'Checkout',
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.fontM,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: AppSizes.fontM,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
