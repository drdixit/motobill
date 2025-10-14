import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../credit_notes_screen.dart';
import 'credit_note_details_screen.dart' as transactions;

class SalesReturnsScreen extends ConsumerWidget {
  const SalesReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditNotesAsync = ref.watch(creditNotesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(creditNotesProvider),
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
                if (creditNotes.isEmpty) {
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
                          'No credit notes found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Credit notes will appear here',
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
                  itemCount: creditNotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final creditNote = creditNotes[index];
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
    final createdAt = DateTime.parse(creditNote['created_at'] as String);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => transactions.CreditNoteDetailsScreen(
                creditNoteId: creditNote['id'] as int,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First line: Credit Note number (left) and total (right)
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
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Second line: customer name and date
            Row(
              children: [
                Expanded(
                  child: Text(
                    customerName,
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
          ],
        ),
      ),
    );
  }
}
