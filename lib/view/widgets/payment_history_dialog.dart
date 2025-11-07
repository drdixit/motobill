import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class PaymentHistoryDialog extends StatelessWidget {
  final List<Map<String, dynamic>> payments;
  final double totalAmount;
  final double paidAmount;
  final double totalReturned;

  const PaymentHistoryDialog({
    super.key,
    required this.payments,
    required this.totalAmount,
    required this.paidAmount,
    this.totalReturned = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Net remaining = (bill total - paid) - returned products value
    final billRemaining = totalAmount - paidAmount;
    final netRemaining = billRemaining - totalReturned;
    final remainingAmount = netRemaining > 0 ? netRemaining : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radiusL),
                  topRight: Radius.circular(AppSizes.radiusL),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: AppColors.primary,
                    size: AppSizes.iconL,
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment History',
                          style: TextStyle(
                            fontSize: AppSizes.fontXL,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${payments.length} payment(s)',
                          style: TextStyle(
                            fontSize: AppSizes.fontS,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Payment Summary
            Container(
              margin: const EdgeInsets.all(AppSizes.paddingM),
              padding: const EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Bill Total',
                    '₹${totalAmount.toStringAsFixed(2)}',
                    AppColors.textPrimary,
                  ),
                  const Divider(height: AppSizes.paddingM),
                  _buildSummaryRow(
                    'Total Paid',
                    '₹${paidAmount.toStringAsFixed(2)}',
                    Colors.green,
                  ),
                  if (totalReturned > 0.01) ...[
                    const Divider(height: AppSizes.paddingM),
                    _buildSummaryRow(
                      'Returned (Products)',
                      '- ₹${totalReturned.toStringAsFixed(2)}',
                      Colors.blue,
                    ),
                  ],
                  const Divider(height: AppSizes.paddingM),
                  _buildSummaryRow(
                    'Remaining',
                    '₹${remainingAmount.toStringAsFixed(2)}',
                    remainingAmount > 0 ? Colors.orange : Colors.green,
                    bold: true,
                  ),
                ],
              ),
            ),

            // Payments List
            Expanded(
              child: payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payment_outlined,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: AppSizes.paddingM),
                          Text(
                            'No payments yet',
                            style: TextStyle(
                              fontSize: AppSizes.fontL,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                      ),
                      itemCount: payments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        return _buildPaymentItem(payment);
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppSizes.radiusL),
                  bottomRight: Radius.circular(AppSizes.radiusL),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.paddingM,
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String amount,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.fontM,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: bold ? AppSizes.fontL : AppSizes.fontM,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final amount = (payment['amount'] as num).toDouble();
    final paymentMethod = payment['payment_method'] as String;
    final paymentDate = DateTime.parse(payment['payment_date'] as String);
    final notes = payment['notes'] as String?;

    // Payment method icon and label
    IconData methodIcon;
    String methodLabel;

    switch (paymentMethod) {
      case 'cash':
        methodIcon = Icons.money;
        methodLabel = 'Cash';
        break;
      case 'upi':
        methodIcon = Icons.qr_code;
        methodLabel = 'UPI';
        break;
      case 'card':
        methodIcon = Icons.credit_card;
        methodLabel = 'Card';
        break;
      case 'bank_transfer':
        methodIcon = Icons.account_balance;
        methodLabel = 'Bank Transfer';
        break;
      case 'cheque':
        methodIcon = Icons.receipt_long;
        methodLabel = 'Cheque';
        break;
      default:
        methodIcon = Icons.payment;
        methodLabel = 'Other';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusS),
            ),
            child: Icon(methodIcon, color: Colors.green, size: AppSizes.iconM),
          ),
          const SizedBox(width: AppSizes.paddingM),

          // Payment details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      methodLabel,
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${paymentDate.day.toString().padLeft(2, '0')}/${paymentDate.month.toString().padLeft(2, '0')}/${paymentDate.year} at ${paymentDate.hour.toString().padLeft(2, '0')}:${paymentDate.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: AppSizes.fontS,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: TextStyle(
                      fontSize: AppSizes.fontS,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
