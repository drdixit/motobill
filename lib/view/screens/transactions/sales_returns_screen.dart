import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
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
        '''SELECT cn.*, c.name as customer_name
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
