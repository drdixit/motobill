import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../view_model/pos_viewmodel.dart';
import '../../../model/bill.dart';
import '../../../model/customer.dart';
import '../../../repository/customer_repository.dart';
import '../../../core/providers/database_provider.dart';
import '../customer_form_dialog.dart';
import '../bill_print_dialog.dart';
import '../../screens/transactions/sales_screen.dart';
import '../../screens/debit_notes_screen.dart';

// Custom formatter to allow only one decimal point and max 2 decimal places
class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty text
    if (text.isEmpty) {
      return newValue;
    }

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

    // If there's a decimal point, check decimal places
    if (text.contains('.')) {
      final parts = text.split('.');
      // Reject if more than 2 digits after decimal point
      if (parts[1].length > 2) {
        return oldValue;
      }
    }

    return newValue;
  }
}

class PosCart extends ConsumerWidget {
  const PosCart({super.key});

  /// Fuzzy search helper that checks if searchText matches targetText
  /// Returns true if all characters in searchText appear in targetText in order
  bool _fuzzyMatch(String searchText, String targetText) {
    if (searchText.isEmpty) return true;
    if (targetText.isEmpty) return false;

    final search = searchText.toLowerCase();
    final target = targetText.toLowerCase();

    int searchIndex = 0;
    int targetIndex = 0;

    while (searchIndex < search.length && targetIndex < target.length) {
      if (search[searchIndex] == target[targetIndex]) {
        searchIndex++;
      }
      targetIndex++;
    }

    return searchIndex == search.length;
  }

  /// Search customer across multiple fields with fuzzy matching
  bool _matchesCustomer(Customer customer, String query) {
    if (query.isEmpty) return true;

    // Search in name (required field)
    if (_fuzzyMatch(query, customer.name)) return true;

    // Search in legal name (optional)
    if (customer.legalName != null && _fuzzyMatch(query, customer.legalName!)) {
      return true;
    }

    // Search in GST number (optional)
    if (customer.gstNumber != null && _fuzzyMatch(query, customer.gstNumber!)) {
      return true;
    }

    // Search in mobile number (optional)
    if (customer.phone != null && _fuzzyMatch(query, customer.phone!)) {
      return true;
    }

    // Search in email (optional)
    if (customer.email != null && _fuzzyMatch(query, customer.email!)) {
      return true;
    }

    return false;
  }

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
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
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
                  child: Autocomplete<Customer>(
                    key: ValueKey(state.selectedCustomer?.id),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return state.customers;
                      }
                      return state.customers.where((customer) {
                        return _matchesCustomer(
                          customer,
                          textEditingValue.text,
                        );
                      });
                    },
                    displayStringForOption: (Customer customer) =>
                        customer.name,
                    onSelected: (Customer customer) {
                      viewModel.selectCustomer(customer);
                    },
                    initialValue: state.selectedCustomer != null
                        ? TextEditingValue(text: state.selectedCustomer!.name)
                        : null,
                    fieldViewBuilder:
                        (
                          BuildContext context,
                          TextEditingController textController,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Select Customer *',
                              labelStyle: TextStyle(
                                color: state.selectedCustomer == null
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                              hintText: 'Search by name, GST, mobile, email...',
                              hintStyle: TextStyle(
                                fontSize: AppSizes.fontS,
                                color: AppColors.textTertiary,
                              ),
                              prefixIcon: Icon(
                                Icons.person,
                                color: state.selectedCustomer == null
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                              suffixIcon: state.selectedCustomer != null
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        size: AppSizes.iconS,
                                      ),
                                      onPressed: () {
                                        textController.clear();
                                        viewModel.selectCustomer(null);
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusM,
                                ),
                                borderSide: BorderSide(
                                  color: state.selectedCustomer == null
                                      ? AppColors.error
                                      : AppColors.border,
                                  width: state.selectedCustomer == null ? 2 : 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusM,
                                ),
                                borderSide: BorderSide(
                                  color: state.selectedCustomer == null
                                      ? AppColors.error
                                      : AppColors.border,
                                  width: state.selectedCustomer == null ? 2 : 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusM,
                                ),
                                borderSide: BorderSide(
                                  color: state.selectedCustomer == null
                                      ? AppColors.error
                                      : AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.paddingM,
                                vertical: AppSizes.paddingM,
                              ),
                            ),
                          );
                        },
                    optionsViewBuilder:
                        (
                          BuildContext context,
                          AutocompleteOnSelected<Customer> onSelected,
                          Iterable<Customer> options,
                        ) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusM,
                              ),
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                width: 400,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusM,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final customer = options.elementAt(index);
                                    return ListTile(
                                      leading: Icon(
                                        Icons.person,
                                        color: AppColors.primary,
                                        size: AppSizes.iconM,
                                      ),
                                      title: Text(
                                        customer.legalName != null
                                            ? '${customer.name} (${customer.legalName})'
                                            : customer.name,
                                        style: TextStyle(
                                          fontSize: AppSizes.fontM,
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      subtitle: customer.gstNumber != null
                                          ? Text(
                                              'GST: ${customer.gstNumber}',
                                              style: TextStyle(
                                                fontSize: AppSizes.fontS,
                                                color: AppColors.textSecondary,
                                              ),
                                            )
                                          : null,
                                      onTap: () {
                                        onSelected(customer);
                                      },
                                      hoverColor: AppColors.primary.withOpacity(
                                        0.1,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                ElevatedButton.icon(
                  onPressed: () => _showAddCustomerDialog(context, ref),
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
                      final lastPrice = state.lastCustomPrices[item.productId];
                      return _buildCartItem(
                        context,
                        item,
                        viewModel,
                        lastPrice,
                      );
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

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(posViewModelProvider.notifier);
    final db = await ref.read(databaseProvider);
    final customerRepository = CustomerRepository(db);

    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(
        customer: null,
        onSave: (newCustomer) async {
          Navigator.of(context).pop();
          try {
            // Create customer in database
            final customerId = await customerRepository.createCustomer(
              newCustomer,
            );
            // Refresh customer list and auto-select the new customer
            await viewModel.refreshCustomersAndSelect(customerId);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to create customer: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
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
    double? lastCustomPrice,
  ) {
    return _CartItemWidget(
      key: ValueKey(item.productId),
      item: item,
      viewModel: viewModel,
      lastCustomPrice: lastCustomPrice,
    );
  }
}

class _CartItemWidget extends StatefulWidget {
  final BillItem item;
  final PosViewModel viewModel;
  final double? lastCustomPrice;

  const _CartItemWidget({
    super.key,
    required this.item,
    required this.viewModel,
    this.lastCustomPrice,
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
      color: AppColors.backgroundTertiary,
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
            // Last Custom Price Display (if exists)
            if (widget.lastCustomPrice != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '₹${widget.lastCustomPrice!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: AppSizes.fontXS,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
            if (widget.lastCustomPrice != null)
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
                Icons.delete,
                size: AppSizes.iconM,
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
                child: Consumer(
                  builder: (context, consumerRef, child) {
                    final state = consumerRef.watch(posViewModelProvider);

                    return OutlinedButton.icon(
                      onPressed:
                          state.cartItems.isEmpty ||
                              state.selectedCustomer == null ||
                              (state.selectedCustomer?.phone == null ||
                                  state.selectedCustomer!.phone!.isEmpty)
                          ? null
                          : () => _sendWhatsAppMessage(context, state),
                      icon: Icon(Icons.phone, size: AppSizes.iconS),
                      label: Text(
                        'WhatsApp',
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.paddingM,
                        ),
                        side: BorderSide(
                          color:
                              state.cartItems.isEmpty ||
                                  state.selectedCustomer == null ||
                                  (state.selectedCustomer?.phone == null ||
                                      state.selectedCustomer!.phone!.isEmpty)
                              ? AppColors.border
                              : Colors.green,
                        ),
                        foregroundColor:
                            state.cartItems.isEmpty ||
                                state.selectedCustomer == null ||
                                (state.selectedCustomer?.phone == null ||
                                    state.selectedCustomer!.phone!.isEmpty)
                            ? AppColors.textTertiary
                            : Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        ),
                        disabledForegroundColor: AppColors.textTertiary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                flex: 2,
                child: Consumer(
                  builder: (context, consumerRef, child) {
                    final state = consumerRef.watch(posViewModelProvider);
                    final viewModel = consumerRef.read(
                      posViewModelProvider.notifier,
                    );

                    return ElevatedButton(
                      onPressed: state.selectedCustomer == null
                          ? null
                          : () async {
                              final billNumber = await viewModel.checkout();
                              if (billNumber != null && context.mounted) {
                                // Invalidate bills list so it refreshes in Sales screen
                                consumerRef.invalidate(billsListProvider);
                                // Invalidate purchases list so auto-purchases show in Debit Notes
                                consumerRef.invalidate(purchasesProvider);
                                // Invalidate POS viewmodel to refresh stock after bill creation
                                consumerRef.invalidate(posViewModelProvider);

                                // Show print dialog
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) =>
                                      BillPrintDialog(billNumber: billNumber),
                                );
                              } else if (state.error != null &&
                                  context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(state.error!),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
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
                    );
                  },
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

  Future<void> _sendWhatsAppMessage(
    BuildContext context,
    PosState state,
  ) async {
    // Validate cart and customer
    if (state.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cart is empty'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (state.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a customer'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final customerPhone = state.selectedCustomer?.phone;
    if (customerPhone == null || customerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Customer does not have a phone number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Build WhatsApp message
    final customerName = state.selectedCustomer?.name ?? 'Customer';

    final StringBuffer message = StringBuffer();
    message.writeln('Hello $customerName,');
    message.writeln('');
    message.writeln('Thank you for shopping with us!');
    message.writeln('');
    message.writeln('📋 *Cart Details:*');
    message.writeln('―――――――――――――');

    // Add cart items
    for (final item in state.cartItems) {
      final productName = item.productName;
      final quantity = item.quantity;
      final price = item.sellingPrice;
      final total = item.totalAmount;

      message.writeln('');
      message.writeln('*$productName*');
      message.writeln('Qty: $quantity × ₹${price.toStringAsFixed(2)}');
      message.writeln('Amount: ₹${total.toStringAsFixed(2)}');
    }

    message.writeln('');
    message.writeln('―――――――――――――');
    message.writeln('*Subtotal:* ₹${state.subtotal.toStringAsFixed(2)}');
    message.writeln('*Tax:* ₹${state.taxAmount.toStringAsFixed(2)}');
    message.writeln('*Total Amount:* ₹${state.totalAmount.toStringAsFixed(2)}');
    message.writeln('');
    message.writeln('Please visit us again! 🙏');

    // Clean phone number (remove spaces, dashes, etc.)
    String cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9+]'), '');

    // If phone doesn't start with country code, add India code
    if (!cleanPhone.startsWith('+')) {
      if (cleanPhone.startsWith('91')) {
        cleanPhone = '+$cleanPhone';
      } else {
        cleanPhone = '+91$cleanPhone';
      }
    }

    // URL encode the message
    final encodedMessage = Uri.encodeComponent(message.toString());

    // Create WhatsApp URL
    final whatsappUrl = 'https://wa.me/$cleanPhone?text=$encodedMessage';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open WhatsApp'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
  }
}
