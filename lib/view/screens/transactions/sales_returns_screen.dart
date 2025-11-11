import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/bill_repository.dart';
import '../../widgets/refund_dialog.dart';
import '../transactions_screen.dart';
import 'credit_note_details_screen.dart' as credit_note_details;

// Provider for credit notes list with date filtering
final creditNotesProviderForTransactions =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final db = await ref.watch(databaseProvider);
      final dateRange = ref.watch(transactionDateRangeProvider);
      final startStr = dateRange.start.toIso8601String().split('T')[0];
      final endStr = dateRange.end.toIso8601String().split('T')[0];

      final result = await db.rawQuery(
        '''
        SELECT cn.*,
               c.name as customer_name,
               b.bill_number,
               b.total_amount as bill_total,
               b.paid_amount as bill_paid,
               COALESCE(cn.refunded_amount, 0) as refunded_amount,
               COALESCE(cn.refund_status, 'pending') as refund_status,
               COALESCE(cn.max_refundable_amount, 0) as max_refundable_amount,
               COUNT(DISTINCT cni.id) as item_count,
               SUM(cni.quantity) as total_quantity
        FROM credit_notes cn
        LEFT JOIN customers c ON cn.customer_id = c.id
        LEFT JOIN bills b ON cn.bill_id = b.id
        LEFT JOIN credit_note_items cni ON cn.id = cni.credit_note_id AND cni.is_deleted = 0
        WHERE cn.is_deleted = 0
          AND DATE(cn.created_at) BETWEEN ? AND ?
        GROUP BY cn.id
        ORDER BY cn.id DESC
        ''',
        [startStr, endStr],
      );
      return result;
    });

class SalesReturnsScreen extends ConsumerStatefulWidget {
  const SalesReturnsScreen({super.key});

  @override
  ConsumerState<SalesReturnsScreen> createState() => _SalesReturnsScreenState();
}

class _SalesReturnsScreenState extends ConsumerState<SalesReturnsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _fuzzyMatch(String text, String query) {
    if (query.isEmpty) return true;
    if (text.isEmpty) return false;

    int textIndex = 0;
    int queryIndex = 0;

    while (textIndex < text.length && queryIndex < query.length) {
      if (text[textIndex] == query[queryIndex]) {
        queryIndex++;
      }
      textIndex++;
    }

    return queryIndex == query.length;
  }

  List<Map<String, dynamic>> _filterCreditNotes(
    List<Map<String, dynamic>> creditNotes,
  ) {
    if (_searchQuery.isEmpty) return creditNotes;

    final query = _searchQuery.toLowerCase();
    return creditNotes.where((creditNote) {
      final creditNoteNumber = (creditNote['credit_note_number'] as String)
          .toLowerCase();
      final customerName = (creditNote['customer_name'] as String? ?? '')
          .toLowerCase();
      return _fuzzyMatch(creditNoteNumber, query) ||
          _fuzzyMatch(customerName, query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final creditNotesAsync = ref.watch(creditNotesProviderForTransactions);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header with Search
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by credit note number or customer...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () =>
                      ref.invalidate(creditNotesProviderForTransactions),
                  tooltip: 'Refresh',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Credit Notes List
          Expanded(
            child: creditNotesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
              data: (creditNotes) {
                final filteredCreditNotes = _filterCreditNotes(creditNotes);

                if (filteredCreditNotes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No credit notes found'
                              : 'No matching credit notes',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Credit notes will appear here'
                              : 'Try a different search term',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredCreditNotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final creditNote = filteredCreditNotes[index];
                    return _buildCreditNoteCard(context, creditNote);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditNoteCard(
    BuildContext context,
    Map<String, dynamic> creditNote,
  ) {
    final creditNoteNumber = creditNote['credit_note_number'] as String;
    final customerName =
        creditNote['customer_name'] as String? ?? 'Unknown Customer';
    final billNumber = creditNote['bill_number'] as String? ?? 'N/A';
    final totalAmount = (creditNote['total_amount'] as num).toDouble();
    final maxRefundable =
        (creditNote['max_refundable_amount'] as num?)?.toDouble() ?? 0.0;
    final refundedAmount =
        (creditNote['refunded_amount'] as num?)?.toDouble() ?? 0.0;
    final refundStatus = creditNote['refund_status'] as String? ?? 'pending';

    // Ensure max_refundable is never negative (floating-point fix)
    final safeMaxRefundable = maxRefundable < 0.01 ? 0.0 : maxRefundable;
    final remainingAmount = safeMaxRefundable - refundedAmount;

    // Fix status if max_refundable is 0 but status is pending
    final actualStatus = (safeMaxRefundable < 0.01 && refundStatus == 'pending')
        ? 'adjusted'
        : refundStatus;

    final createdAt = DateTime.parse(creditNote['created_at'] as String);

    // Status badge color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (actualStatus) {
      case 'refunded':
        statusColor = Colors.green;
        statusText = 'Refunded';
        statusIcon = Icons.check_circle;
        break;
      case 'partial':
        statusColor = Colors.orange;
        statusText = 'Partial';
        statusIcon = Icons.access_time;
        break;
      case 'adjusted':
        statusColor = Colors.blue;
        statusText = 'Adjusted';
        statusIcon = Icons.balance;
        break;
      default:
        statusColor = Colors.red;
        statusText = 'Pending';
        statusIcon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => credit_note_details.CreditNoteDetailsScreen(
                creditNoteId: creditNote['id'] as int,
              ),
            ),
          );
          // Refresh the list when returning from details
          ref.invalidate(creditNotesProviderForTransactions);
        },
        child: Row(
          children: [
            // Credit Note Number - Fixed width
            SizedBox(
              width: 120,
              child: Text(
                'CN$creditNoteNumber',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Status Badge - Fixed width
            SizedBox(
              width: 90,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 3),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Customer Name - Flexible
            Expanded(
              flex: 2,
              child: Text(
                customerName,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Bill Number - Fixed width
            SizedBox(
              width: 100,
              child: Row(
                children: [
                  Icon(Icons.receipt, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      billNumber,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Total Amount - Fixed width
            SizedBox(
              width: 130,
              child: Row(
                children: [
                  Text(
                    'Total: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Refundable - Fixed width (always reserve space)
            SizedBox(
              width: 160,
              child: actualStatus != 'adjusted' && safeMaxRefundable > 0.01
                  ? Row(
                      children: [
                        Text(
                          'Refundable: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '₹${safeMaxRefundable.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : actualStatus == 'adjusted'
                  ? Text(
                      'Adjusted',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            // Refunded - Fixed width (always reserve space)
            SizedBox(
              width: 150,
              child: refundedAmount > 0.01
                  ? Row(
                      children: [
                        Text(
                          'Refunded: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '₹${refundedAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            // Remaining - Fixed width (always reserve space)
            SizedBox(
              width: 160,
              child:
                  (actualStatus != 'refunded' &&
                      actualStatus != 'adjusted' &&
                      remainingAmount > 0.01)
                  ? Row(
                      children: [
                        Text(
                          'Remaining: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '₹${remainingAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            // Date - Fixed width
            SizedBox(
              width: 90,
              child: Text(
                '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            // Issue Refund Button - Fixed width (always reserve space)
            SizedBox(
              width: 120,
              child:
                  (actualStatus != 'refunded' &&
                      actualStatus != 'adjusted' &&
                      remainingAmount > 0.01)
                  ? ElevatedButton.icon(
                      onPressed: () => _showAddRefundDialog(
                        context,
                        creditNote['id'] as int,
                        remainingAmount,
                      ),
                      icon: const Icon(Icons.account_balance_wallet, size: 16),
                      label: const Text(
                        'Refund',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        fixedSize: const Size.fromHeight(28),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            // View Details Button (like Print in Sales)
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        credit_note_details.CreditNoteDetailsScreen(
                          creditNoteId: creditNote['id'] as int,
                        ),
                  ),
                );
                ref.invalidate(creditNotesProviderForTransactions);
              },
              icon: const Icon(Icons.visibility, size: 20),
              tooltip: 'View Details',
              color: Colors.blue,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              style: IconButton.styleFrom(
                side: const BorderSide(color: Colors.blue, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddRefundDialog(
    BuildContext context,
    int creditNoteId,
    double remainingAmount,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RefundDialog(
        totalAmount: remainingAmount,
        suggestedAmount: remainingAmount,
        title: 'Issue Refund',
      ),
    );

    if (result != null && mounted) {
      try {
        final db = await ref.read(databaseProvider);
        final repository = BillRepository(db);
        await repository.addRefund(
          creditNoteId: creditNoteId,
          amount: result['amount'] as double,
          refundMethod: result['refund_method'] as String,
          notes: result['notes'] as String?,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Refund added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the list and credit note details
          ref.invalidate(creditNotesProviderForTransactions);
          ref.invalidate(
            credit_note_details.creditNoteDetailsProvider(creditNoteId),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding refund: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
