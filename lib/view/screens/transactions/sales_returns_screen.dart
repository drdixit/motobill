import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/bill_repository.dart';
import '../../widgets/refund_dialog.dart';
import '../transactions_screen.dart';
import 'credit_note_details_screen.dart' as transactions;

// Provider for credit notes list with date filtering
final creditNotesProviderForTransactions =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final db = await ref.watch(databaseProvider);
      final dateRange = ref.watch(transactionDateRangeProvider);
      final startStr = dateRange.start.toIso8601String().split('T')[0];
      final endStr = dateRange.end.toIso8601String().split('T')[0];

      final result = await db.rawQuery(
        '''SELECT cn.*, c.name as customer_name,
           COALESCE(cn.refunded_amount, 0) as refunded_amount,
           COALESCE(cn.refund_status, 'pending') as refund_status,
           COALESCE(cn.max_refundable_amount, 0) as max_refundable_amount
     FROM credit_notes cn
     LEFT JOIN customers c ON cn.customer_id = c.id
     WHERE cn.is_deleted = 0
     AND DATE(cn.created_at) BETWEEN ? AND ?
     ORDER BY cn.id DESC''',
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
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by credit note number or customer...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.invalidate(creditNotesProviderForTransactions),
                  tooltip: 'Refresh',
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
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredCreditNotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final totalAmount = (creditNote['total_amount'] as num).toDouble();
    final maxRefundable =
        (creditNote['max_refundable_amount'] as num?)?.toDouble() ??
        totalAmount;
    final refundedAmount =
        (creditNote['refunded_amount'] as num?)?.toDouble() ?? 0.0;
    final refundStatus = creditNote['refund_status'] as String? ?? 'pending';
    final remainingAmount = maxRefundable - refundedAmount;
    final createdAt = DateTime.parse(creditNote['created_at'] as String);

    // Status badge color and text
    Color statusColor;
    String statusText;
    switch (refundStatus) {
      case 'refunded':
        statusColor = Colors.green;
        statusText = 'Refunded';
        break;
      case 'partial':
        statusColor = Colors.orange;
        statusText = 'Partial';
        break;
      case 'adjusted':
        statusColor = Colors.blue;
        statusText = 'Adjusted';
        break;
      default:
        statusColor = Colors.red;
        statusText = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              builder: (context) => transactions.CreditNoteDetailsScreen(
                creditNoteId: creditNote['id'] as int,
              ),
            ),
          );
          // Refresh the list when returning from details
          ref.invalidate(creditNotesProviderForTransactions);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First line: Credit Note number and refund status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'CN$creditNoteNumber',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Second line: customer name
            Text(
              customerName,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Third line: Refund breakdown
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ₹${totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (refundStatus == 'adjusted') ...[
                        Text(
                          'Adjusted to bill remaining',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (refundStatus == 'refunded') ...[
                        Text(
                          'Refunded: ₹${refundedAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (refundStatus == 'partial') ...[
                        Text(
                          'Refunded: ₹${refundedAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (refundStatus != 'refunded' &&
                          refundStatus != 'adjusted' &&
                          remainingAmount > 0.01) ...[
                        Text(
                          'Remaining: ₹${remainingAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Add Refund button for pending/partial credit notes only
            // Don't show for adjusted (already settled) or refunded
            if (refundStatus != 'refunded' &&
                refundStatus != 'adjusted' &&
                remainingAmount > 0.01) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddRefundDialog(
                    context,
                    creditNote['id'] as int,
                    remainingAmount,
                  ),
                  icon: const Icon(Icons.account_balance_wallet, size: 18),
                  label: const Text('Issue Refund'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
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
          // Refresh the list
          ref.invalidate(creditNotesProviderForTransactions);
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
