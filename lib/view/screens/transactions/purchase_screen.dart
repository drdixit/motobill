import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/purchase_repository.dart';
import '../../widgets/payment_dialog.dart';
import '../transactions_screen.dart';
import 'purchase_details_screen.dart' as purchase_details;

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
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by purchase number or vendor...',
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
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.invalidate(purchasesListProvider),
                  tooltip: 'Refresh',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
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
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredPurchases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    final paidAmount = (purchase['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final paymentStatus = purchase['payment_status'] as String? ?? 'unpaid';
    final remainingAmount = totalAmount - paidAmount;
    final createdAt = DateTime.parse(purchase['created_at'] as String);

    // Determine status color and label
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (paymentStatus) {
      case 'paid':
        statusColor = Colors.green;
        statusLabel = 'Paid';
        statusIcon = Icons.check_circle;
        break;
      case 'partial':
        statusColor = Colors.orange;
        statusLabel = 'Partial';
        statusIcon = Icons.access_time;
        break;
      default:
        statusColor = Colors.red;
        statusLabel = 'Unpaid';
        statusIcon = Icons.cancel;
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
              builder: (context) => purchase_details.PurchaseDetailsScreen(
                purchaseId: purchase['id'] as int,
              ),
            ),
          );
          // Refresh purchases list when returning from details
          ref.invalidate(purchasesListProvider);
        },
        child: Row(
          children: [
            // Purchase Number - Fixed width
            SizedBox(
              width: 120,
              child: Text(
                purchaseNumber,
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
              width: 80,
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
            ),
            const SizedBox(width: 12),
            // Vendor Name - Flexible
            Expanded(
              child: Text(
                vendorName,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // Total - Fixed width
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
            const SizedBox(width: 12),
            // Paid - Fixed width (always reserve space)
            SizedBox(
              width: 120,
              child: paymentStatus != 'unpaid'
                  ? Row(
                      children: [
                        Text(
                          'Paid: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '₹${paidAmount.toStringAsFixed(2)}',
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
            const SizedBox(width: 12),
            // Due - Fixed width (always reserve space)
            SizedBox(
              width: 130,
              child: (paymentStatus == 'partial' && remainingAmount > 0.01)
                  ? Row(
                      children: [
                        Text(
                          'Due: ',
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
            const SizedBox(width: 12),
            // Date - Fixed width
            SizedBox(
              width: 90,
              child: Text(
                '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            // Pay More Button - Fixed width (always reserve space)
            SizedBox(
              width: 110,
              child: (paymentStatus != 'paid' && remainingAmount > 0.01)
                  ? ElevatedButton(
                      onPressed: () async {
                        await _showAddPaymentDialog(context, purchase);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        fixedSize: const Size.fromHeight(28),
                      ),
                      child: const Text(
                        'Pay More',
                        style: TextStyle(fontSize: 13),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            // View Details Button
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        purchase_details.PurchaseDetailsScreen(
                          purchaseId: purchase['id'] as int,
                        ),
                  ),
                );
                ref.invalidate(purchasesListProvider);
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

  Future<void> _showAddPaymentDialog(
    BuildContext context,
    Map<String, dynamic> purchase,
  ) async {
    final purchaseId = purchase['id'] as int;
    final totalAmount = (purchase['total_amount'] as num).toDouble();
    final paidAmount = (purchase['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final remainingAmount = totalAmount - paidAmount;

    final paymentResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PaymentDialog(
        totalAmount: remainingAmount,
        suggestedAmount: remainingAmount,
        title: 'Add Payment',
      ),
    );

    if (paymentResult == null || !context.mounted) return;

    try {
      final db = await ref.read(databaseProvider);
      final repository = PurchaseRepository(db);

      await repository.addPayment(
        purchaseId: purchaseId,
        amount: paymentResult['amount'],
        paymentMethod: paymentResult['payment_method'],
        notes: paymentResult['notes'],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ₹${paymentResult['amount'].toStringAsFixed(2)} added successfully!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Refresh purchases list and purchase details
      ref.invalidate(purchasesListProvider);
      ref.invalidate(purchase_details.purchaseDetailsProvider(purchaseId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add payment: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
