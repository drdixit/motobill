import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../model/payment_summary.dart';
import '../../view_model/payment_viewmodel.dart';

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
    super.dispose();
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

        return _buildPaymentList(list, isReceivable: true);
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

        return _buildPaymentList(list, isReceivable: false);
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

        return _buildPaymentList(list, isReceivable: false, isRefund: true);
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
    );
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
