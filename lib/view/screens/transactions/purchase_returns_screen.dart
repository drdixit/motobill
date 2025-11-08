import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/debit_note_repository.dart';
import '../../widgets/refund_dialog.dart';
import '../transactions_screen.dart';
import 'debit_note_details_screen.dart' as debit_note_details;

// Provider for debit notes list with date filtering
final debitNotesListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = DebitNoteRepository(db);
  final dateRange = ref.watch(transactionDateRangeProvider);
  return repository.getDebitNotesByDateRange(dateRange.start, dateRange.end);
});

class PurchaseReturnsScreen extends ConsumerStatefulWidget {
  const PurchaseReturnsScreen({super.key});

  @override
  ConsumerState<PurchaseReturnsScreen> createState() =>
      _PurchaseReturnsScreenState();
}

class _PurchaseReturnsScreenState extends ConsumerState<PurchaseReturnsScreen> {
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

  List<Map<String, dynamic>> _filterDebitNotes(
    List<Map<String, dynamic>> debitNotes,
  ) {
    if (_searchQuery.isEmpty) return debitNotes;

    final query = _searchQuery.toLowerCase();
    return debitNotes.where((debitNote) {
      final debitNoteNumber = (debitNote['debit_note_number'] as String)
          .toLowerCase();
      final vendorName = (debitNote['vendor_name'] as String? ?? '')
          .toLowerCase();
      return _fuzzyMatch(debitNoteNumber, query) ||
          _fuzzyMatch(vendorName, query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final debitNotesAsync = ref.watch(debitNotesListProvider);

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
                      hintText: 'Search by debit note number or vendor...',
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
                  onPressed: () => ref.invalidate(debitNotesListProvider),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Debit Notes List
          Expanded(
            child: debitNotesAsync.when(
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
              data: (debitNotes) {
                final filteredDebitNotes = _filterDebitNotes(debitNotes);

                if (filteredDebitNotes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.undo_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No debit notes found'
                              : 'No matching debit notes',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Debit notes will appear here'
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
                  itemCount: filteredDebitNotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final debitNote = filteredDebitNotes[index];
                    return _buildDebitNoteCard(context, debitNote);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebitNoteCard(
    BuildContext context,
    Map<String, dynamic> debitNote,
  ) {
    final debitNoteNumber = debitNote['debit_note_number'] as String;
    final vendorName = debitNote['vendor_name'] as String? ?? 'Unknown Vendor';
    final totalAmount = (debitNote['total_amount'] as num).toDouble();
    final refundedAmount =
        (debitNote['refunded_amount'] as num?)?.toDouble() ?? 0.0;
    final maxRefundableAmount =
        (debitNote['max_refundable_amount'] as num?)?.toDouble() ?? 0.0;
    final refundStatus = debitNote['refund_status'] as String? ?? 'pending';
    final remainingAmount = maxRefundableAmount - refundedAmount;
    final createdAt = DateTime.parse(debitNote['created_at'] as String);

    // Determine status color and label
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (refundStatus == 'refunded') {
      statusColor = Colors.green;
      statusLabel = 'Refunded';
      statusIcon = Icons.check_circle;
    } else if (refundStatus == 'partial') {
      statusColor = Colors.orange;
      statusLabel = 'Partial';
      statusIcon = Icons.access_time;
    } else if (refundStatus == 'adjusted') {
      statusColor = Colors.blue;
      statusLabel = 'Adjusted';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.red;
      statusLabel = 'Pending';
      statusIcon = Icons.cancel;
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
              builder: (context) => debit_note_details.DebitNoteDetailsScreen(
                debitNoteId: debitNote['id'] as int,
              ),
            ),
          );
          // Refresh debit notes list when returning from details
          ref.invalidate(debitNotesListProvider);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First line: Debit Note number with status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'DN$debitNoteNumber',
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Vendor name and date
            Row(
              children: [
                Expanded(
                  child: Text(
                    vendorName,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Refund info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Max Refundable',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₹${maxRefundableAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                if (refundStatus != 'pending')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refunded',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${refundedAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                if (refundStatus == 'partial' && remainingAmount > 0.01)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${remainingAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            // Add Refund button - only show if not fully refunded and not adjusted
            if (refundStatus != 'refunded' &&
                refundStatus != 'adjusted' &&
                remainingAmount > 0.01) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _showAddRefundDialog(context, debitNote);
                  },
                  icon: const Icon(Icons.currency_rupee, size: 18),
                  label: Text(
                    refundStatus == 'pending'
                        ? 'Add Refund'
                        : 'Add More Refund',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
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
    Map<String, dynamic> debitNote,
  ) async {
    final debitNoteId = debitNote['id'] as int;
    final maxRefundableAmount =
        (debitNote['max_refundable_amount'] as num?)?.toDouble() ?? 0.0;
    final refundedAmount =
        (debitNote['refunded_amount'] as num?)?.toDouble() ?? 0.0;
    final remainingAmount = maxRefundableAmount - refundedAmount;

    final refundResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RefundDialog(
        totalAmount: remainingAmount,
        suggestedAmount: remainingAmount,
        title: 'Add Refund',
      ),
    );

    if (refundResult == null || !context.mounted) return;

    try {
      final db = await ref.read(databaseProvider);
      final repository = DebitNoteRepository(db);

      await repository.addRefund(
        debitNoteId: debitNoteId,
        amount: refundResult['amount'],
        refundMethod: refundResult['refund_method'],
        notes: refundResult['notes'],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refund of ₹${refundResult['amount'].toStringAsFixed(2)} added successfully!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Refresh debit notes list and debit note details
      ref.invalidate(debitNotesListProvider);
      ref.invalidate(debit_note_details.debitNoteDetailsProvider(debitNoteId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add refund: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
