import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/purchase_repository.dart';
import '../transactions_screen.dart';
import 'purchase_details_screen.dart';

// Provider for purchases list with date filtering
final purchasesListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = PurchaseRepository(db);
  final dateRange = ref.watch(transactionDateRangeProvider);
  return repository.getPurchasesByDateRange(dateRange.start, dateRange.end);
});

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
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

  List<Map<String, dynamic>> _filterPurchases(
    List<Map<String, dynamic>> purchases,
  ) {
    if (_searchQuery.isEmpty) return purchases;

    final query = _searchQuery.toLowerCase();
    return purchases.where((purchase) {
      final purchaseNumber = (purchase['purchase_number'] as String)
          .toLowerCase();
      final vendorName = (purchase['vendor_name'] as String? ?? '')
          .toLowerCase();
      return _fuzzyMatch(purchaseNumber, query) ||
          _fuzzyMatch(vendorName, query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesListProvider);

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
                      hintText: 'Search by purchase number or vendor...',
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
                  onPressed: () => ref.invalidate(purchasesListProvider),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Purchases List
          Expanded(
            child: purchasesAsync.when(
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
              data: (purchases) {
                final filteredPurchases = _filterPurchases(purchases);

                if (filteredPurchases.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No purchases found'
                              : 'No matching purchases',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Purchases will appear here'
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
                  itemCount: filteredPurchases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final purchase = filteredPurchases[index];
                    return _buildPurchaseCard(context, purchase);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(
    BuildContext context,
    Map<String, dynamic> purchase,
  ) {
    final purchaseNumber = purchase['purchase_number'] as String;
    final vendorName = purchase['vendor_name'] as String? ?? 'Unknown Vendor';
    final totalAmount = (purchase['total_amount'] as num).toDouble();
    final createdAt = DateTime.parse(purchase['created_at'] as String);

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
              builder: (context) =>
                  PurchaseDetailsScreen(purchaseId: purchase['id'] as int),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First line: Purchase number (left) and total (right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    purchaseNumber,
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
            // Second line: vendor name and date
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
          ],
        ),
      ),
    );
  }
}
