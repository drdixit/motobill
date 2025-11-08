import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/database_provider.dart';
import '../../model/payment_summary.dart';
import '../../view_model/payment_viewmodel.dart';
import 'transactions/bill_details_screen.dart';

class PaymentNavigationScreen extends ConsumerStatefulWidget {
  const PaymentNavigationScreen({super.key});

  @override
  ConsumerState<PaymentNavigationScreen> createState() =>
      _PaymentNavigationScreenState();
}

class _PaymentNavigationScreenState
    extends ConsumerState<PaymentNavigationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load data when screen first appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  List<PaymentSummary> _filterItems(List<PaymentSummary> items) {
    if (_searchQuery.isEmpty) return items;

    final query = _searchQuery.toLowerCase();
    return items.where((item) {
      final name = item.name.toLowerCase();
      final phone = (item.phone ?? '').toLowerCase();
      return _fuzzyMatch(name, query) || _fuzzyMatch(phone, query);
    }).toList();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  void _refreshData() {
    // Invalidate all providers to refresh data
    ref.invalidate(paymentStatsProvider);
    ref.invalidate(receivablesProvider);
    ref.invalidate(payablesProvider);
    ref.invalidate(customerRefundablesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final paymentStats = ref.watch(paymentStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Management'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          paymentStats.when(
            data: (stats) => _buildStatsSection(stats),
            loading: () => const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'Error loading stats: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Receivables (Lene Hai)'),
                Tab(text: 'Vendor Payables'),
                Tab(text: 'Customer Refunds'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReceivablesTab(),
                _buildPayablesTab(),
                _buildCustomerRefundablesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, double> stats) {
    final totalReceivables = stats['total_receivables'] ?? 0.0;
    final totalPayables = stats['total_payables'] ?? 0.0;
    final vendorPayables = stats['vendor_payables'] ?? 0.0;
    final customerRefundables = stats['customer_refundables'] ?? 0.0;
    final netPosition = stats['net_position'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Receivables',
                  subtitle: 'Customers se lene hai (after returns)',
                  amount: totalReceivables,
                  color: Colors.green,
                  icon: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Total Payables',
                  subtitle: 'Vendors + Customer refunds',
                  amount: totalPayables,
                  color: Colors.red,
                  icon: Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Net Position',
                  subtitle: netPosition >= 0
                      ? 'Profit position'
                      : 'Loss position',
                  amount: netPosition.abs(),
                  color: netPosition >= 0 ? Colors.blue : Colors.orange,
                  icon: netPosition >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Breakdown row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBreakdownChip(
                'Vendors: ${_formatCurrency(vendorPayables)}',
                Colors.red.shade700,
              ),
              const SizedBox(width: 12),
              _buildBreakdownChip(
                'Customer Refunds: ${_formatCurrency(customerRefundables)}',
                Colors.orange.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivablesTab() {
    final receivables = ref.watch(receivablesProvider);

    return receivables.when(
      data: (list) {
        if (list.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            message: 'No pending receivables',
            subtitle: 'All customers have paid!',
          );
        }

        final filteredList = _filterItems(list);

        return Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
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
              ),
            ),
            // List
            Expanded(
              child: filteredList.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.search_off,
                      message: 'No results found',
                      subtitle: 'Try a different search term',
                    )
                  : _buildPaymentList(filteredList, isReceivable: true),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildPayablesTab() {
    final payables = ref.watch(payablesProvider);

    return payables.when(
      data: (list) {
        if (list.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            message: 'No pending payables',
            subtitle: 'All vendors have been paid!',
          );
        }

        final filteredList = _filterItems(list);

        return Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by vendor name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
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
              ),
            ),
            // List
            Expanded(
              child: filteredList.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.search_off,
                      message: 'No results found',
                      subtitle: 'Try a different search term',
                    )
                  : _buildPaymentList(filteredList, isReceivable: false),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildCustomerRefundablesTab() {
    final refundables = ref.watch(customerRefundablesProvider);

    return refundables.when(
      data: (list) {
        if (list.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            message: 'No pending refunds',
            subtitle: 'All customer refunds completed!',
          );
        }

        final filteredList = _filterItems(list);

        return Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by customer name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
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
              ),
            ),
            // List
            Expanded(
              child: filteredList.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.search_off,
                      message: 'No results found',
                      subtitle: 'Try a different search term',
                    )
                  : _buildPaymentList(
                      filteredList,
                      isReceivable: false,
                      isRefund: true,
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentList(
    List<PaymentSummary> items, {
    required bool isReceivable,
    bool isRefund = false,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildPaymentCard(
          item,
          isReceivable: isReceivable,
          isRefund: isRefund,
        );
      },
    );
  }

  Widget _buildPaymentCard(
    PaymentSummary item, {
    required bool isReceivable,
    bool isRefund = false,
  }) {
    final color = isRefund
        ? Colors.orange
        : (isReceivable ? Colors.green : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => _showDetailBottomSheet(item, isReceivable, isRefund),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      isRefund
                          ? Icons.receipt_long
                          : (isReceivable ? Icons.person : Icons.business),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.phone != null && item.phone!.isNotEmpty)
                          Text(
                            item.phone!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isRefund
                          ? '${item.billCount} ${item.billCount == 1 ? 'Credit Note' : 'Credit Notes'}'
                          : '${item.billCount} ${item.billCount == 1 ? 'Bill' : 'Bills'}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildAmountRow(
                      isRefund ? 'Return Amount' : 'Total Amount',
                      item.totalAmount,
                      Colors.grey.shade700,
                    ),
                    if (isReceivable || isRefund) ...[
                      const SizedBox(height: 8),
                      _buildAmountRow(
                        isRefund ? 'Refunded' : 'Paid Amount',
                        item.paidAmount,
                        Colors.blue.shade700,
                      ),
                    ],
                    const Divider(height: 20),
                    _buildAmountRow(
                      isRefund
                          ? 'Pending Refund (Dene Hai)'
                          : (isReceivable
                                ? 'Remaining (Lene Hai)'
                                : 'To Pay (Dene Hai)'),
                      item.remainingAmount,
                      color,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetailBottomSheet(
    PaymentSummary item,
    bool isReceivable,
    bool isRefund,
  ) async {
    final db = await ref.read(databaseProvider);

    // Fetch bills or credit notes for this customer/vendor
    List<Map<String, dynamic>> items;

    if (isRefund) {
      // Fetch pending credit notes for this customer
      items = await db.rawQuery(
        '''
        SELECT cn.*, b.bill_number
        FROM credit_notes cn
        LEFT JOIN bills b ON cn.bill_id = b.id
        WHERE cn.customer_id = ?
          AND cn.is_deleted = 0
          AND cn.refund_status IN ('pending', 'partial')
          AND (cn.max_refundable_amount - cn.refunded_amount) > 0.01
        ORDER BY cn.created_at DESC
        ''',
        [item.id],
      );
    } else if (isReceivable) {
      // Fetch unpaid/partially paid bills for this customer
      items = await db.rawQuery(
        '''
        SELECT b.*,
               (b.total_amount - b.paid_amount) as remaining,
               COALESCE((SELECT SUM(cn.max_refundable_amount - COALESCE(cn.refunded_amount, 0))
                         FROM credit_notes cn
                         WHERE cn.bill_id = b.id
                         AND cn.is_deleted = 0
                         AND cn.refund_status != 'refunded'), 0) as pending_refunds
        FROM bills b
        WHERE b.customer_id = ?
          AND b.is_deleted = 0
          AND b.payment_status IN ('unpaid', 'partial')
          AND ((b.total_amount - b.paid_amount) -
               COALESCE((SELECT SUM(cn.max_refundable_amount - COALESCE(cn.refunded_amount, 0))
                         FROM credit_notes cn
                         WHERE cn.bill_id = b.id
                         AND cn.is_deleted = 0
                         AND cn.refund_status != 'refunded'), 0)) > 0.01
        ORDER BY b.created_at DESC
        ''',
        [item.id],
      );
    } else {
      // Fetch unpaid purchases for this vendor
      items = await db.rawQuery(
        '''
        SELECT p.*,
               (p.total_amount - p.paid_amount) as remaining
        FROM purchases p
        WHERE p.vendor_id = ?
          AND p.is_deleted = 0
          AND p.payment_status IN ('unpaid', 'partial')
        ORDER BY p.created_at DESC
        ''',
        [item.id],
      );
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.phone != null && item.phone!.isNotEmpty)
                      Text(
                        item.phone!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      isRefund
                          ? '${items.length} Credit Note${items.length != 1 ? 's' : ''} Pending'
                          : '${items.length} ${isReceivable ? 'Bill' : 'Purchase'}${items.length != 1 ? 's' : ''} Pending',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final itemData = items[index];
                    return _buildDetailCard(itemData, isReceivable, isRefund);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(
    Map<String, dynamic> itemData,
    bool isReceivable,
    bool isRefund,
  ) {
    final color = isRefund
        ? Colors.orange
        : (isReceivable ? Colors.green : Colors.red);

    if (isRefund) {
      // Credit Note Card
      final creditNoteNumber = itemData['credit_note_number'] as String;
      final billNumber = itemData['bill_number'] as String? ?? 'N/A';
      final totalAmount = (itemData['total_amount'] as num).toDouble();
      final maxRefundable =
          (itemData['max_refundable_amount'] as num?)?.toDouble() ?? 0.0;
      final refunded = (itemData['refunded_amount'] as num?)?.toDouble() ?? 0.0;
      final remaining = maxRefundable - refunded;
      final billId = itemData['bill_id'] as int;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            // Navigate to bill details
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BillDetailsScreen(billId: billId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CN$creditNoteNumber',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Bill: $billNumber',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'To Refund: ₹${remaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Bill/Purchase Card
      final number =
          itemData[isReceivable ? 'bill_number' : 'purchase_number'] as String;
      final totalAmount = (itemData['total_amount'] as num).toDouble();
      final paidAmount = (itemData['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final remaining = (itemData['remaining'] as num).toDouble();
      final id = itemData['id'] as int;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            // Navigate to bill/purchase details
            if (isReceivable) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BillDetailsScreen(billId: id),
                ),
              );
            }
            // TODO: Add purchase details navigation when available
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      number,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: ₹${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          'Paid: ₹${paidAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${remaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildAmountRow(
    String label,
    double amount,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          _formatCurrency(amount),
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
