import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../view_model/pos_viewmodel.dart';
import '../../../model/bill.dart';

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

          // Customer Selection
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: state.selectedCustomer == null
                            ? AppColors.error
                            : AppColors.border,
                        width: state.selectedCustomer == null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: DropdownButtonFormField(
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
                        return DropdownMenuItem(
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
                      onChanged: (customer) =>
                          viewModel.selectCustomer(customer),
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement add customer functionality
                  },
                  icon: Icon(Icons.person_add, size: AppSizes.iconS),
                  label: Text('Add Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                      vertical: AppSizes.paddingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
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
    return _CartItemWidget(
      key: ValueKey(item.productId),
      item: item,
      viewModel: viewModel,
    );
  }
}

class _CartItemWidget extends StatefulWidget {
  final BillItem item;
  final PosViewModel viewModel;

  const _CartItemWidget({
    super.key,
    required this.item,
    required this.viewModel,
  });

  @override
  State<_CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<_CartItemWidget> {
  late TextEditingController qtyController;
  late TextEditingController priceController;
  late TextEditingController totalController;

  late FocusNode qtyFocusNode;
  late FocusNode priceFocusNode;
  late FocusNode totalFocusNode;

  @override
  void initState() {
    super.initState();
    qtyController = TextEditingController(text: '${widget.item.quantity}');

    // Calculate price with tax (per unit including tax)
    final priceWithTax = _calculatePriceWithTax(widget.item);
    priceController = TextEditingController(
      text: priceWithTax.toStringAsFixed(2),
    );

    totalController = TextEditingController(
      text: widget.item.totalAmount.toStringAsFixed(2),
    );

    qtyFocusNode = FocusNode();
    priceFocusNode = FocusNode();
    totalFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_CartItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only update text if field is NOT focused (user is not editing)
    if (oldWidget.item.quantity != widget.item.quantity &&
        !qtyFocusNode.hasFocus) {
      final newText = '${widget.item.quantity}';
      if (qtyController.text != newText) {
        qtyController.text = newText;
      }
    }

    if ((oldWidget.item.sellingPrice != widget.item.sellingPrice ||
            oldWidget.item.taxAmount != widget.item.taxAmount) &&
        !priceFocusNode.hasFocus) {
      final priceWithTax = _calculatePriceWithTax(widget.item);
      final newText = priceWithTax.toStringAsFixed(2);
      if (priceController.text != newText) {
        priceController.text = newText;
      }
    }

    if (oldWidget.item.totalAmount != widget.item.totalAmount &&
        !totalFocusNode.hasFocus) {
      final newText = widget.item.totalAmount.toStringAsFixed(2);
      if (totalController.text != newText) {
        totalController.text = newText;
      }
    }
  }

  @override
  void dispose() {
    qtyController.dispose();
    priceController.dispose();
    totalController.dispose();
    qtyFocusNode.dispose();
    priceFocusNode.dispose();
    totalFocusNode.dispose();
    super.dispose();
  }

  // Calculate per-unit price including tax
  double _calculatePriceWithTax(BillItem item) {
    if (item.quantity == 0) return 0.0;
    return item.totalAmount / item.quantity;
  }

  @override
  Widget build(BuildContext context) {
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
                  widget.item.partNumber != null
                      ? '${widget.item.productName} (${widget.item.partNumber})'
                      : widget.item.productName,
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
                focusNode: qtyFocusNode,
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
                  if (value.isEmpty) return;
                  final newQty = int.tryParse(value);
                  if (newQty != null && newQty > 0) {
                    widget.viewModel.updateCartItemQuantity(
                      widget.item.productId,
                      newQty,
                    );
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
                focusNode: priceFocusNode,
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
                  if (value.isEmpty) return;
                  final priceWithTax = double.tryParse(value);
                  if (priceWithTax != null && priceWithTax > 0) {
                    // Reverse calculate price without tax
                    final totalTaxRate =
                        widget.item.cgstRate +
                        widget.item.sgstRate +
                        widget.item.igstRate;
                    final priceWithoutTax = totalTaxRate > 0
                        ? priceWithTax / (1 + totalTaxRate / 100)
                        : priceWithTax;
                    widget.viewModel.updateCartItemPrice(
                      widget.item.productId,
                      priceWithoutTax,
                    );
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
                  '₹${widget.item.taxAmount.toStringAsFixed(2)}',
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
                focusNode: totalFocusNode,
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
                  if (value.isEmpty) return;
                  final totalWithTax = double.tryParse(value);
                  if (totalWithTax != null && totalWithTax > 0) {
                    // Reverse calculate total without tax (subtotal)
                    final totalTaxRate =
                        widget.item.cgstRate +
                        widget.item.sgstRate +
                        widget.item.igstRate;
                    final subtotal = totalTaxRate > 0
                        ? totalWithTax / (1 + totalTaxRate / 100)
                        : totalWithTax;
                    widget.viewModel.updateCartItemTotal(
                      widget.item.productId,
                      subtotal,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            // Delete button
            InkWell(
              onTap: () =>
                  widget.viewModel.removeFromCart(widget.item.productId),
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
}

extension on PosCart {
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
          // Subtotal, Tax, and Total
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Subtotal: ',
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₹${state.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Tax: ',
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₹${state.taxAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Total: ',
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₹${state.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
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
}
