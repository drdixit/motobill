import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../model/credit_note_refund.dart';

class RefundHistoryDialog extends StatelessWidget {
  final List<CreditNoteRefund> refunds;
  final double totalAmount;
  final double refundedAmount;

  const RefundHistoryDialog({
    super.key,
    required this.refunds,
    required this.totalAmount,
    required this.refundedAmount,
  });

  IconData _getRefundMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'upi':
        return Icons.qr_code;
      case 'card':
        return Icons.credit_card;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'cheque':
        return Icons.receipt_long;
      default:
        return Icons.payment;
    }
  }

  String _formatRefundMethod(String method) {
    return method
        .split('_')
        .map((word) {
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final remainingAmount = totalAmount - refundedAmount;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.history, color: Colors.orange, size: 28),
                const SizedBox(width: AppSizes.paddingM),
                Text(
                  'Refund History',
                  style: TextStyle(
                    fontSize: AppSizes.fontXL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingL),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Amount',
                    totalAmount,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: _buildSummaryCard(
                    'Refunded',
                    refundedAmount,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: _buildSummaryCard(
                    'Remaining',
                    remainingAmount,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingL),

            // Refunds List
            if (refunds.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingXL),
                  child: Text(
                    'No refunds yet',
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: refunds.length,
                  separatorBuilder: (context, index) => Divider(
                    color: AppColors.border.withOpacity(0.3),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final refund = refunds[index];
                    return _buildRefundTile(refund);
                  },
                ),
              ),
            const SizedBox(height: AppSizes.paddingL),

            // Close Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontSize: AppSizes.fontM,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontS,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundTile(CreditNoteRefund refund) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingM),
      child: Row(
        children: [
          // Refund Method Icon
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Icon(
              _getRefundMethodIcon(refund.refundMethod),
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),

          // Refund Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatRefundMethod(refund.refundMethod),
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${refund.amount.toStringAsFixed(2)}',
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
                  '${refund.refundDate.day.toString().padLeft(2, '0')}/${refund.refundDate.month.toString().padLeft(2, '0')}/${refund.refundDate.year} at ${refund.refundDate.hour.toString().padLeft(2, '0')}:${refund.refundDate.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: AppSizes.fontS,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (refund.notes != null && refund.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    refund.notes!,
                    style: TextStyle(
                      fontSize: AppSizes.fontS,
                      color: AppColors.textSecondary,
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
