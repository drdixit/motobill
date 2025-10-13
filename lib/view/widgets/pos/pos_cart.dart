import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../view_model/pos_viewmodel.dart';
import '../../../model/bill.dart';
import '../../../model/customer.dart';

// Custom formatter to allow only one decimal point
class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow only digits and single decimal point
    final text = newValue.text;

    // Check if text contains only valid characters (digits and decimal point)
    if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(text)) {
      return oldValue;
    }

    // Count decimal points
    final decimalCount = text.split('.').length - 1;

    // Reject if more than one decimal point
    if (decimalCount > 1) {
      return oldValue;
    }

    return newValue;
  }
}

class PosCart extends ConsumerWidget {
  const PosCart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posViewModelProvider);
    final viewModel = ref.read(posViewModelProvider.notifier);

    return Container(
      width: 520,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Header with Customer Selection
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: AppSizes.paddingM),
                // Customer Selection Dropdown
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: state.selectedCustomer == null
                          ? AppColors.error
                          : AppColors.border,
                      width: state.selectedCustomer == null ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: DropdownButtonFormField<Customer>(
                    value: state.selectedCustomer,
                    decoration: InputDecoration(
                      labelText: 'Select Customer *',
                      labelStyle: TextStyle(
                        color: state.selectedCustomer == null
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.person,
                        color: state.selectedCustomer == null
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                        vertical: AppSizes.paddingS,
                      ),
                    ),
                    hint: Text(
                      'Choose customer to create bill',
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    items: state.customers.map((customer) {
                      return DropdownMenuItem<Customer>(
                        value: customer,
                        child: Text(
                          customer.name,
                          style: TextStyle(
                            fontSize: AppSizes.fontM,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (customer) => viewModel.selectCustomer(customer),
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
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
    final qtyController = TextEditingController(text: '${item.quantity}');
    final priceController = TextEditingController(
      text: item.sellingPrice.toStringAsFixed(2),
    );
    final totalController = TextEditingController(
      text: item.totalAmount.toStringAsFixed(2),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
      elevation: 0,
      color: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingS),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product name
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.partNumber != null
                      ? '${item.productName} (${item.partNumber})'
                      : item.productName,
                  style: TextStyle(
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            // Quantity (editable)
            SizedBox(
              width: 50,
              child: TextFormField(
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizes.fontS,
                  fontWeight: FontWeight.w600,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
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
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  final newQty = int.tryParse(value);
                  if (newQty != null && newQty > 0) {
                    viewModel.updateCartItemQuantity(item.productId, newQty);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            // Single Price (editable)
            SizedBox(
              width: 70,
              child: TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizes.fontS,
                  fontWeight: FontWeight.w600,
                ),
                inputFormatters: [DecimalTextInputFormatter()],
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
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
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  final newPrice = double.tryParse(value);
                  if (newPrice != null && newPrice > 0) {
                    viewModel.updateCartItemPrice(item.productId, newPrice);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            // Tax (non-editable)
            SizedBox(
              width: 55,
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  '₹${item.taxAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: AppSizes.fontXS,
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            // Total (editable)
            SizedBox(
              width: 75,
              child: TextFormField(
                controller: totalController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizes.fontS,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                inputFormatters: [DecimalTextInputFormatter()],
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  final newTotal = double.tryParse(value);
                  if (newTotal != null && newTotal > 0) {
                    viewModel.updateCartItemTotal(item.productId, newTotal);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            // Delete button
            InkWell(
              onTap: () => viewModel.removeFromCart(item.productId),
              child: Icon(
                Icons.close,
                size: AppSizes.iconS,
                color: AppColors.error,
              ),
            ),
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
          const SizedBox(height: 4),

          // Tax
          _buildSummaryRow('Tax:', state.taxAmount),
          const SizedBox(height: 4),

          // Divider
          Divider(color: AppColors.border, thickness: 1),
          const SizedBox(height: 4),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '₹${state.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: AppSizes.fontL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingM),

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
                  onPressed: state.selectedCustomer == null
                      ? null
                      : () {
                          // TODO: Navigate to checkout or save bill
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Creating bill for ${state.selectedCustomer!.name}...',
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.selectedCustomer == null
                        ? AppColors.border
                        : AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.paddingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textTertiary,
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

          // Customer warning
          if (state.selectedCustomer == null) ...[
            const SizedBox(height: AppSizes.paddingM),
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingS),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: AppSizes.iconS,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSizes.paddingS),
                  Expanded(
                    child: Text(
                      'Please select a customer to checkout',
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            fontSize: AppSizes.fontS,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: AppSizes.fontS,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
