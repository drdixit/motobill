import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/providers/database_provider.dart';
import 'dashboard/create_bill_screen.dart';
import 'credit_notes_screen.dart';
import 'dashboard/create_purchase_screen.dart';
import 'debit_notes_screen.dart';

// Provider for sales statistics
final salesStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = await ref.watch(databaseProvider);

  // Get total sales amount (lifetime)
  final salesResult = await db.rawQuery(
    'SELECT SUM(total_amount) as total FROM bills WHERE is_deleted = 0',
  );
  final totalSales = (salesResult.first['total'] as num?) ?? 0;

  // Get total bills count (lifetime)
  final billsResult = await db.rawQuery(
    'SELECT COUNT(*) as count FROM bills WHERE is_deleted = 0',
  );
  final totalBills = (billsResult.first['count'] as int?) ?? 0;

  // Get total refunds (credit notes) (lifetime)
  final refundsResult = await db.rawQuery(
    'SELECT SUM(total_amount) as total FROM credit_notes WHERE is_deleted = 0',
  );
  final totalRefunds = (refundsResult.first['total'] as num?) ?? 0;

  // Get daily sales for the last 7 days
  final dailySales = await db.rawQuery('''
    SELECT
      date(created_at) as day,
      SUM(total_amount) as total
    FROM bills
    WHERE is_deleted = 0
      AND date(created_at) >= date('now', '-7 days')
    GROUP BY day
    ORDER BY day ASC
  ''');

  // Get taxable vs non-taxable sales for last 7 days
  final taxableSales = await db.rawQuery('''
    SELECT SUM(bi.total_amount) as total
    FROM bill_items bi
    INNER JOIN bills b ON bi.bill_id = b.id
    WHERE bi.is_deleted = 0
      AND b.is_deleted = 0
      AND date(b.created_at) >= date('now', '-7 days')
      AND bi.tax_amount > 0
  ''');

  final nonTaxableSales = await db.rawQuery('''
    SELECT SUM(bi.total_amount) as total
    FROM bill_items bi
    INNER JOIN bills b ON bi.bill_id = b.id
    WHERE bi.is_deleted = 0
      AND b.is_deleted = 0
      AND date(b.created_at) >= date('now', '-7 days')
      AND bi.tax_amount = 0
  ''');

  final taxableAmount = (taxableSales.first['total'] as num?) ?? 0;
  final nonTaxableAmount = (nonTaxableSales.first['total'] as num?) ?? 0;

  // Get top 5 customers by sales (last 7 days)
  final topCustomers = await db.rawQuery('''
    SELECT
      c.name as customer_name,
      SUM(b.total_amount) as total_amount,
      COUNT(b.id) as bill_count
    FROM bills b
    INNER JOIN customers c ON b.customer_id = c.id
    WHERE b.is_deleted = 0
      AND c.is_deleted = 0
      AND date(b.created_at) >= date('now', '-7 days')
    GROUP BY b.customer_id, c.name
    ORDER BY total_amount DESC
    LIMIT 5
  ''');

  // Get top 5 selling products (last 7 days)
  final topProducts = await db.rawQuery('''
    SELECT
      p.name as product_name,
      SUM(bi.quantity) as total_quantity,
      SUM(bi.total_amount) as total_amount
    FROM bill_items bi
    INNER JOIN bills b ON bi.bill_id = b.id
    INNER JOIN products p ON bi.product_id = p.id
    WHERE bi.is_deleted = 0
      AND b.is_deleted = 0
      AND p.is_deleted = 0
      AND date(b.created_at) >= date('now', '-7 days')
    GROUP BY bi.product_id, p.name
    ORDER BY total_quantity DESC
    LIMIT 5
  ''');

  return {
    'totalSales': totalSales,
    'totalBills': totalBills,
    'totalRefunds': totalRefunds,
    'dailySales': dailySales,
    'taxableAmount': taxableAmount,
    'nonTaxableAmount': nonTaxableAmount,
    'topCustomers': topCustomers,
    'topProducts': topProducts,
  };
});

// Provider for purchase statistics
final purchaseStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = await ref.watch(databaseProvider);

  // Get total purchase amount (lifetime)
  final purchaseResult = await db.rawQuery(
    'SELECT SUM(total_amount) as total FROM purchases WHERE is_deleted = 0',
  );
  final totalPurchases = (purchaseResult.first['total'] as num?) ?? 0;

  // Get total purchases count (lifetime)
  final purchasesCountResult = await db.rawQuery(
    'SELECT COUNT(*) as count FROM purchases WHERE is_deleted = 0',
  );
  final totalPurchasesCount =
      (purchasesCountResult.first['count'] as int?) ?? 0;

  // Get total returns (debit notes) (lifetime)
  final returnsResult = await db.rawQuery(
    'SELECT SUM(total_amount) as total FROM debit_notes WHERE is_deleted = 0',
  );
  final totalReturns = (returnsResult.first['total'] as num?) ?? 0;

  // Get daily purchases for the last 7 days
  final dailyPurchases = await db.rawQuery('''
    SELECT
      date(created_at) as day,
      SUM(total_amount) as total
    FROM purchases
    WHERE is_deleted = 0
      AND date(created_at) >= date('now', '-7 days')
    GROUP BY day
    ORDER BY day ASC
  ''');

  // Get taxable vs non-taxable purchases for last 7 days
  final taxablePurchases = await db.rawQuery('''
    SELECT SUM(pi.total_amount) as total
    FROM purchase_items pi
    INNER JOIN purchases p ON pi.purchase_id = p.id
    WHERE pi.is_deleted = 0
      AND p.is_deleted = 0
      AND date(p.created_at) >= date('now', '-7 days')
      AND pi.tax_amount > 0
  ''');

  final nonTaxablePurchases = await db.rawQuery('''
    SELECT SUM(pi.total_amount) as total
    FROM purchase_items pi
    INNER JOIN purchases p ON pi.purchase_id = p.id
    WHERE pi.is_deleted = 0
      AND p.is_deleted = 0
      AND date(p.created_at) >= date('now', '-7 days')
      AND pi.tax_amount = 0
  ''');

  final taxableAmount = (taxablePurchases.first['total'] as num?) ?? 0;
  final nonTaxableAmount = (nonTaxablePurchases.first['total'] as num?) ?? 0;

  return {
    'totalPurchases': totalPurchases,
    'totalPurchasesCount': totalPurchasesCount,
    'totalReturns': totalReturns,
    'dailyPurchases': dailyPurchases,
    'taxableAmount': taxableAmount,
    'nonTaxableAmount': nonTaxableAmount,
  };
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  final List<String> _tabs = ['Sales', 'Purchase'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh data when app resumes
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _refreshData() {
    // Invalidate providers to refresh dashboard data
    ref.invalidate(salesStatsProvider);
    ref.invalidate(purchaseStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildSalesTab(context), _buildPurchaseTab(context)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelPadding: const EdgeInsets.symmetric(horizontal: 32),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
          letterSpacing: 0.3,
        ),
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildSalesTab(BuildContext context) {
    final statsAsync = ref.watch(salesStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (stats) {
        final totalSales = stats['totalSales'] as num;
        final totalBills = stats['totalBills'] as int;
        final totalRefunds = stats['totalRefunds'] as num;
        final dailySales = stats['dailySales'] as List<Map<String, dynamic>>;
        final taxableAmount = stats['taxableAmount'] as num;
        final nonTaxableAmount = stats['nonTaxableAmount'] as num;
        final topCustomers =
            stats['topCustomers'] as List<Map<String, dynamic>>;
        final topProducts = stats['topProducts'] as List<Map<String, dynamic>>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Row: Pie Chart (left) and Stats + Graph (right)
              LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Statistics Cards and Graph
                      Expanded(
                        child: Column(
                          children: [
                            // Statistics Cards (horizontal on top)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Total Sales',
                                    value: '₹${totalSales.toStringAsFixed(2)}',
                                    icon: Icons.currency_rupee,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Total Bills',
                                    value: totalBills.toString(),
                                    icon: Icons.receipt_long,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Total Refunds',
                                    value:
                                        '₹${totalRefunds.toStringAsFixed(2)}',
                                    icon: Icons.assignment_return,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Sales Overview Graph (below stats)
                            _buildSalesOverviewGraph(dailySales),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right side - Pie Chart
                      SizedBox(
                        width: 350,
                        child: _buildTaxablePieChart(
                          taxableAmount.toDouble(),
                          nonTaxableAmount.toDouble(),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Top Customers and Top Products Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTopCustomers(topCustomers)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildTopProducts(topProducts)),
                ],
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    context: context,
                    label: 'Create Bill',
                    icon: Icons.add_circle_outline,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateBillScreen(),
                        ),
                      );
                      // Refresh data when coming back from Create Bill screen
                      _refreshData();
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    context: context,
                    label: 'Credit Notes',
                    icon: Icons.note_add_outlined,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreditNotesScreen(),
                        ),
                      );
                      // Refresh data when coming back from Credit Notes screen
                      _refreshData();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPurchaseTab(BuildContext context) {
    final statsAsync = ref.watch(purchaseStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (stats) {
        final totalPurchases = stats['totalPurchases'] as num;
        final totalPurchasesCount = stats['totalPurchasesCount'] as int;
        final totalReturns = stats['totalReturns'] as num;
        final dailyPurchases =
            stats['dailyPurchases'] as List<Map<String, dynamic>>;
        final taxableAmount = stats['taxableAmount'] as num;
        final nonTaxableAmount = stats['nonTaxableAmount'] as num;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Row: Pie Chart (left) and Stats + Graph (right)
              LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Statistics Cards and Graph
                      Expanded(
                        child: Column(
                          children: [
                            // Statistics Cards (horizontal on top)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Total Purchases',
                                    value:
                                        '₹${totalPurchases.toStringAsFixed(2)}',
                                    icon: Icons.shopping_cart,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Total Orders',
                                    value: totalPurchasesCount.toString(),
                                    icon: Icons.inventory,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Total Returns',
                                    value:
                                        '₹${totalReturns.toStringAsFixed(2)}',
                                    icon: Icons.undo,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Purchase Overview Graph (below stats)
                            _buildPurchaseOverviewGraph(dailyPurchases),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right side - Pie Chart
                      SizedBox(
                        width: 350,
                        child: _buildPurchasePieChart(
                          taxableAmount.toDouble(),
                          nonTaxableAmount.toDouble(),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    context: context,
                    label: 'Create Purchase',
                    icon: Icons.add_shopping_cart_outlined,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreatePurchaseScreen(),
                        ),
                      );
                      // Refresh data when coming back from Create Purchase screen
                      _refreshData();
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    context: context,
                    label: 'Debit Notes',
                    icon: Icons.note_outlined,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DebitNotesScreen(),
                        ),
                      );
                      // Refresh data when coming back from Debit Notes screen
                      _refreshData();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingXL,
          vertical: AppSizes.paddingL,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        elevation: 2,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon on left (spans two lines)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          // Title and value on right (two lines)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                // Line 2: Value
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxablePieChart(double taxableAmount, double nonTaxableAmount) {
    final total = taxableAmount + nonTaxableAmount;

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No sales data available',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final taxablePercentage = (taxableAmount / total * 100);
    final nonTaxablePercentage = (nonTaxableAmount / total * 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Distribution (Last 7 Days)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          // Pie Chart
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: CustomPaint(
                painter: _PieChartPainter(
                  taxableAmount: taxableAmount,
                  nonTaxableAmount: nonTaxableAmount,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Legend
          Column(
            children: [
              _buildLegendItem(
                color: Colors.blue,
                label:
                    '₹${taxableAmount.toStringAsFixed(2)} (${taxablePercentage.toStringAsFixed(1)}%)',
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                color: Colors.orange,
                label:
                    '₹${nonTaxableAmount.toStringAsFixed(2)} (${nonTaxablePercentage.toStringAsFixed(1)}%)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSalesOverviewGraph(List<Map<String, dynamic>> dailySales) {
    if (dailySales.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No sales data available',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    // Data is already in ascending order (oldest to newest)
    final salesData = dailySales;

    // Find max value for scaling
    double maxValue = 0;
    for (final data in salesData) {
      final value = (data['total'] as num).toDouble();
      if (value > maxValue) maxValue = value;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Overview (Last 7 Days)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: Builder(
              builder: (context) {
                // Generate all dates for the last 7 days
                final now = DateTime.now();
                final List<DateTime> allDates = List.generate(
                  7,
                  (index) =>
                      DateTime(now.year, now.month, now.day - (6 - index)),
                );

                // Create a map of sales data by date
                final Map<String, double> salesMap = {};
                for (final data in salesData) {
                  final day = data['day'] as String;
                  final total = (data['total'] as num).toDouble();
                  salesMap[day] = total;
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: allDates.map((date) {
                    final dateStr =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    final total = salesMap[dateStr] ?? 0.0;
                    final hasData = total > 0;

                    // Reserve space for labels: 24px top label + 4px spacing + 8px bottom spacing + 18px day label = 54px
                    // Available height for bar: 250 - 54 = 196px
                    final maxBarHeight = 196.0;
                    final barHeight = maxValue > 0 && hasData
                        ? (total / maxValue) * maxBarHeight
                        : 0.0;

                    // Format day (DD/MM)
                    final dayLabel =
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Value label (only show if there's data)
                            SizedBox(
                              height: 24,
                              child: hasData
                                  ? Text(
                                      total >= 1000
                                          ? '₹${(total / 1000).toStringAsFixed(1)}k'
                                          : '₹${total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 4),
                            // Bar (only show if there's data)
                            hasData
                                ? Container(
                                    height: barHeight < 20 ? 20.0 : barHeight,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppColors.primary,
                                          AppColors.primary.withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    height: 20,
                                  ), // Maintain spacing
                            const SizedBox(height: 8),
                            // Day label (always show)
                            SizedBox(
                              height: 18,
                              child: Text(
                                dayLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasePieChart(double taxableAmount, double nonTaxableAmount) {
    final total = taxableAmount + nonTaxableAmount;

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No purchase data available',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final taxablePercentage = (taxableAmount / total * 100);
    final nonTaxablePercentage = (nonTaxableAmount / total * 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Purchase Distribution (Last 7 Days)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          // Pie Chart
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: CustomPaint(
                painter: _PieChartPainter(
                  taxableAmount: taxableAmount,
                  nonTaxableAmount: nonTaxableAmount,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Legend
          Column(
            children: [
              _buildLegendItem(
                color: Colors.blue,
                label:
                    '₹${taxableAmount.toStringAsFixed(2)} (${taxablePercentage.toStringAsFixed(1)}%)',
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                color: Colors.orange,
                label:
                    '₹${nonTaxableAmount.toStringAsFixed(2)} (${nonTaxablePercentage.toStringAsFixed(1)}%)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseOverviewGraph(
    List<Map<String, dynamic>> dailyPurchases,
  ) {
    if (dailyPurchases.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No purchase data available',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    // Data is already in ascending order (oldest to newest)
    final purchaseData = dailyPurchases;

    // Find max value for scaling
    double maxValue = 0;
    for (final data in purchaseData) {
      final value = (data['total'] as num).toDouble();
      if (value > maxValue) maxValue = value;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Purchase Overview (Last 7 Days)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: Builder(
              builder: (context) {
                // Generate all dates for the last 7 days
                final now = DateTime.now();
                final List<DateTime> allDates = List.generate(
                  7,
                  (index) =>
                      DateTime(now.year, now.month, now.day - (6 - index)),
                );

                // Create a map of purchase data by date
                final Map<String, double> purchaseMap = {};
                for (final data in purchaseData) {
                  final day = data['day'] as String;
                  final total = (data['total'] as num).toDouble();
                  purchaseMap[day] = total;
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: allDates.map((date) {
                    final dateStr =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    final total = purchaseMap[dateStr] ?? 0.0;
                    final hasData = total > 0;

                    // Reserve space for labels: 24px top label + 4px spacing + 8px bottom spacing + 18px day label = 54px
                    // Available height for bar: 250 - 54 = 196px
                    final maxBarHeight = 196.0;
                    final barHeight = maxValue > 0 && hasData
                        ? (total / maxValue) * maxBarHeight
                        : 0.0;

                    // Format day (DD/MM)
                    final dayLabel =
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Value label (only show if there's data)
                            SizedBox(
                              height: 24,
                              child: hasData
                                  ? Text(
                                      total >= 1000
                                          ? '₹${(total / 1000).toStringAsFixed(1)}k'
                                          : '₹${total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 4),
                            // Bar (only show if there's data)
                            hasData
                                ? Container(
                                    height: barHeight < 20 ? 20.0 : barHeight,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppColors.primary,
                                          AppColors.primary.withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    height: 20,
                                  ), // Maintain spacing
                            const SizedBox(height: 8),
                            // Day label (always show)
                            SizedBox(
                              height: 18,
                              child: Text(
                                dayLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildTopCustomers(List<Map<String, dynamic>> topCustomers) {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Top Customers (Last 7 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (topCustomers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No customer data available',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...topCustomers.asMap().entries.map((entry) {
            final index = entry.key;
            final customer = entry.value;
            final customerName = customer['customer_name'] as String;
            final totalAmount = (customer['total_amount'] as num).toDouble();
            final billCount = customer['bill_count'] as int;

            return Column(
              children: [
                if (index > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      // Rank
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? Colors.amber.shade100
                              : index == 1
                              ? Colors.grey.shade200
                              : index == 2
                              ? Colors.orange.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: index < 3
                                  ? Colors.black87
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Customer info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$billCount ${billCount == 1 ? 'bill' : 'bills'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Amount
                      Text(
                        '₹${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
      ],
    ),
  );
}

Widget _buildTopProducts(List<Map<String, dynamic>> topProducts) {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Top Selling Products (Last 7 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (topProducts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No product data available',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...topProducts.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            final productName = product['product_name'] as String;
            final totalQuantity = (product['total_quantity'] as num).toDouble();
            final totalAmount = (product['total_amount'] as num).toDouble();

            return Column(
              children: [
                if (index > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      // Rank
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? Colors.amber.shade100
                              : index == 1
                              ? Colors.grey.shade200
                              : index == 2
                              ? Colors.orange.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: index < 3
                                  ? Colors.black87
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Product info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Qty: ${totalQuantity.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Amount
                      Text(
                        '₹${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
      ],
    ),
  );
}

// Custom painter for pie chart
class _PieChartPainter extends CustomPainter {
  final double taxableAmount;
  final double nonTaxableAmount;

  _PieChartPainter({
    required this.taxableAmount,
    required this.nonTaxableAmount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final total = taxableAmount + nonTaxableAmount;

    if (total == 0) return;

    // Draw taxable portion (blue)
    final taxableSweepAngle = (taxableAmount / total) * 2 * 3.14159;
    final taxablePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      taxableSweepAngle,
      true,
      taxablePaint,
    );

    // Draw non-taxable portion (orange)
    final nonTaxablePaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2 + taxableSweepAngle, // Start after taxable
      (nonTaxableAmount / total) * 2 * 3.14159,
      true,
      nonTaxablePaint,
    );

    // Draw white border around chart
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) {
    return oldDelegate.taxableAmount != taxableAmount ||
        oldDelegate.nonTaxableAmount != nonTaxableAmount;
  }
}
