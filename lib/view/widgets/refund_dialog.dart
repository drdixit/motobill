import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class RefundDialog extends StatefulWidget {
  final double totalAmount;
  final double? suggestedAmount;
  final String title;

  const RefundDialog({
    super.key,
    required this.totalAmount,
    this.suggestedAmount,
    this.title = 'Add Refund',
  });

  @override
  State<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<RefundDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  String _selectedRefundMethod = 'cash';

  final List<Map<String, dynamic>> _refundMethods = [
    {'value': 'cash', 'label': 'Cash', 'icon': Icons.money},
    {'value': 'upi', 'label': 'UPI', 'icon': Icons.qr_code},
    {'value': 'card', 'label': 'Card', 'icon': Icons.credit_card},
    {
      'value': 'bank_transfer',
      'label': 'Bank Transfer',
      'icon': Icons.account_balance,
    },
    {'value': 'cheque', 'label': 'Cheque', 'icon': Icons.receipt_long},
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: (widget.suggestedAmount ?? widget.totalAmount).toStringAsFixed(2),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.orange),
          const SizedBox(width: AppSizes.paddingS),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Amount Info
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      // Show "Remaining" if suggestedAmount is provided
                      widget.suggestedAmount != null &&
                              widget.suggestedAmount != widget.totalAmount
                          ? 'Remaining Amount:'
                          : 'Credit Note Amount:',
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₹${widget.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),

              // Refund Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Refund Amount *',
                  prefixText: '₹ ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_circle),
                    tooltip: 'Full Amount',
                    onPressed: () {
                      // Use suggested amount (remaining) if provided, else total
                      final fullAmount =
                          widget.suggestedAmount ?? widget.totalAmount;
                      _amountController.text = fullAmount.toStringAsFixed(2);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter valid amount';
                  }
                  // Check against suggested amount (remaining) if provided, else total
                  final maxAmount =
                      widget.suggestedAmount ?? widget.totalAmount;
                  // Use epsilon for floating-point comparison
                  const epsilon = 0.01;
                  if (amount > maxAmount + epsilon) {
                    return 'Amount cannot exceed remaining (₹${maxAmount.toStringAsFixed(2)})';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.paddingM),

              // Refund Method
              Text(
                'Refund Method',
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.paddingS),
              Wrap(
                spacing: AppSizes.paddingS,
                runSpacing: AppSizes.paddingS,
                children: _refundMethods.map((method) {
                  final isSelected = _selectedRefundMethod == method['value'];
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          method['icon'] as IconData,
                          size: AppSizes.iconS,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(method['label'] as String),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedRefundMethod = method['value'] as String;
                        });
                      }
                    },
                    selectedColor: Colors.orange,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.white
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSizes.paddingM),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Add any refund notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppSizes.fontM,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final amount = double.parse(_amountController.text);
              Navigator.of(context).pop({
                'amount': amount,
                'refund_method': _selectedRefundMethod,
                'notes': _notesController.text.isEmpty
                    ? null
                    : _notesController.text,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingL,
              vertical: AppSizes.paddingM,
            ),
          ),
          child: Text(
            'Confirm Refund',
            style: TextStyle(
              fontSize: AppSizes.fontM,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
