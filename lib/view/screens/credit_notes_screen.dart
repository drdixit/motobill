import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/providers/database_provider.dart';
import '../../repository/bill_repository.dart';

final creditNotesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final result = await db.rawQuery('''SELECT cn.*, c.name as customer_name
       FROM credit_notes cn
       LEFT JOIN customers c ON cn.customer_id = c.id
       WHERE cn.is_deleted = 0
       ORDER BY cn.id DESC''');
  return result;
});

final creditNoteItemsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((
      ref,
      creditNoteId,
    ) async {
      final db = await ref.watch(databaseProvider);
      // Join credit_note_items with credit_notes and customers so the result
      // contains the credit note metadata (number, customer_name, created_at, reason)
      // which the details screen expects.
      return await db.rawQuery(
        '''
      SELECT cni.*, cn.credit_note_number, cn.created_at, cn.reason, c.name as customer_name
      FROM credit_note_items cni
      LEFT JOIN credit_notes cn ON cni.credit_note_id = cn.id
      LEFT JOIN customers c ON cn.customer_id = c.id
      WHERE cni.credit_note_id = ? AND cni.is_deleted = 0
      ORDER BY cni.id
      ''',
        [creditNoteId],
      );
    });

final creditNotesBillsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final repo = BillRepository(db);
  return repo.getAllBills();
});

final creditNotesBillItemsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, billId) async {
      final db = await ref.watch(databaseProvider);
      final repo = BillRepository(db);
      return repo.getBillItems(billId);
    });

// Credit notes for a specific bill
final creditNotesForBillProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, billId) async {
      final db = await ref.watch(databaseProvider);
      return await db.rawQuery(
        '''SELECT * FROM credit_notes WHERE bill_id = ? AND is_deleted = 0 ORDER BY id DESC''',
        [billId],
      );
    });

// Returned quantities per bill_item_id for a bill
final returnedQuantitiesProvider = FutureProvider.family<Map<int, int>, int>((
  ref,
  billId,
) async {
  final db = await ref.watch(databaseProvider);
  final repo = BillRepository(db);
  return repo.getReturnedQuantitiesForBill(billId);
});

class CreditNotesScreen extends ConsumerStatefulWidget {
  const CreditNotesScreen({super.key});

  @override
  ConsumerState<CreditNotesScreen> createState() => _CreditNotesScreenState();
}

class _CreditNotesScreenState extends ConsumerState<CreditNotesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(creditNotesProvider);
    final billsAsync = ref.watch(creditNotesBillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Notes'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
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
              tabs: const [
                Tab(text: 'Existing'),
                Tab(text: 'Create'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Existing credit notes
          notesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (notes) {
              if (notes.isEmpty)
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: AppSizes.iconXL * 2,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppSizes.paddingL),
                      Text(
                        'No credit notes',
                        style: TextStyle(
                          fontSize: AppSizes.fontXL,
                          color: AppColors.textSecondary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                );

              return ListView.separated(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                itemCount: notes.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSizes.paddingM),
                itemBuilder: (context, idx) {
                  final n = notes[idx];
                  return Container(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: InkWell(
                      onTap: () => _openCreditNoteDetails(context, n['id']),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First line: CN number (left) and total (right)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'CN${n['credit_note_number']}',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontL,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSizes.paddingS),
                              Text(
                                '₹${(n['total_amount'] as num).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.paddingXS),
                          // Second line: customer name and optional reason (compact)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${n['customer_name'] ?? '-'}',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontM,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if ((n['reason'] as String?)?.isNotEmpty ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSizes.paddingS,
                                  ),
                                  child: Text(
                                    'Reason: ${n['reason']}',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: AppSizes.fontS,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Create: list bills to create credit note from
          billsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (bills) {
              if (bills.isEmpty)
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: AppSizes.iconXL * 2,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppSizes.paddingL),
                      Text(
                        'No bills found',
                        style: TextStyle(
                          fontSize: AppSizes.fontXL,
                          color: AppColors.textSecondary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                );

              return ListView.builder(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                itemCount: bills.length,
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  return Container(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    margin: const EdgeInsets.symmetric(
                      vertical: AppSizes.paddingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bill: ${bill['bill_number'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: AppSizes.fontL,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSizes.paddingXS),
                              Text(
                                bill['customer_name'] ?? '-',
                                style: TextStyle(
                                  fontSize: AppSizes.fontM,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.note_add_outlined),
                              color: AppColors.primary,
                              onPressed: () =>
                                  _openCreateCreditNote(context, bill['id']),
                              tooltip: 'Create Credit Note',
                            ),
                            IconButton(
                              icon: const Icon(Icons.receipt_long),
                              onPressed: () =>
                                  _openBillItems(context, bill['id']),
                              tooltip: 'View Items',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _openBillItems(BuildContext context, int billId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => BillItemsForCreditNote(billId: billId),
      ),
    );
  }

  void _openCreateCreditNote(BuildContext context, int billId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CreateCreditNoteScreen(billId: billId),
      ),
    );
  }

  void _openCreditNoteDetails(BuildContext context, int creditNoteId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CreditNoteDetailsScreen(creditNoteId: creditNoteId),
      ),
    );
  }
}

class CreditNoteDetailsScreen extends ConsumerWidget {
  final int creditNoteId;
  const CreditNoteDetailsScreen({super.key, required this.creditNoteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(creditNoteItemsProvider(creditNoteId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Credit Note Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No items'));

          // Split items into taxable and non-taxable
          final taxableItems = items.where((it) {
            final totalGst =
                (it['cgst_rate'] as num).toDouble() +
                (it['sgst_rate'] as num).toDouble() +
                (it['igst_rate'] as num).toDouble() +
                (it['utgst_rate'] as num).toDouble();
            return totalGst > 0;
          }).toList();
          final nonTaxableItems = items.where((it) {
            final totalGst =
                (it['cgst_rate'] as num).toDouble() +
                (it['sgst_rate'] as num).toDouble() +
                (it['igst_rate'] as num).toDouble() +
                (it['utgst_rate'] as num).toDouble();
            return totalGst == 0;
          }).toList();

          // Calculate totals
          double subtotal = 0.0;
          double totalTax = 0.0;
          for (var it in items) {
            subtotal += (it['subtotal'] as num).toDouble();
            totalTax += (it['tax_amount'] as num).toDouble();
          }
          final grandTotal = subtotal + totalTax;

          // Get credit note number, customer, date, reason from first item (all items have same credit_note_id)
          final creditNoteNumber = items.first['credit_note_number'] ?? '-';
          final customerName = items.first['customer_name'] ?? '-';
          final createdAtStr = items.first['created_at'] ?? '';
          DateTime? createdAt;
          if (createdAtStr is String && createdAtStr.isNotEmpty) {
            try {
              createdAt = DateTime.parse(createdAtStr);
            } catch (_) {}
          }
          final reason = items.first['reason'] ?? '';

          Widget buildTable(
            List<Map<String, dynamic>> list, {
            required bool showTaxCols,
          }) {
            return LayoutBuilder(
              builder: (ctx2, constraints) {
                final width = constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: width),
                    child: Container(
                      width: width,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: DataTable(
                        columnSpacing: 16,
                        horizontalMargin: 8,
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade100,
                        ),
                        headingRowHeight: 48,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 56,
                        border: TableBorder.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        columns: [
                          const DataColumn(
                            label: Text(
                              'No',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'Product Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'P/N',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'HSN',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'UQC',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'Qty',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            numeric: true,
                          ),
                          const DataColumn(
                            label: Text(
                              'Rate Per Unit',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            numeric: true,
                          ),
                          const DataColumn(
                            label: Text(
                              'Amount',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            numeric: true,
                          ),
                          if (showTaxCols) ...[
                            const DataColumn(
                              label: Text(
                                'CGST%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text(
                                'SGST%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text(
                                'IGST%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text(
                                'UTGST%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text(
                                'Tax Amt',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                          ],
                          const DataColumn(
                            label: Text(
                              'Total Amount',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            numeric: true,
                          ),
                        ],
                        rows: list.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final it = entry.value;
                          final productName =
                              it['product_name'] as String? ?? '-';
                          final partNumber =
                              it['part_number'] as String? ?? '-';
                          final hsn = it['hsn_code'] as String? ?? '-';
                          final uqc = it['uqc_code'] as String? ?? '-';
                          final qty = it['quantity'] as int;
                          final rate = (it['selling_price'] as num).toDouble();
                          final amount = (it['subtotal'] as num).toDouble();
                          final cgstR = (it['cgst_rate'] as num).toDouble();
                          final sgstR = (it['sgst_rate'] as num).toDouble();
                          final igstR = (it['igst_rate'] as num).toDouble();
                          final utgstR = (it['utgst_rate'] as num).toDouble();
                          final taxAmt = (it['tax_amount'] as num).toDouble();
                          final totalAmt = (it['total_amount'] as num)
                              .toDouble();

                          final cells = <DataCell>[
                            DataCell(
                              Text(
                                '$idx',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  productName,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                partNumber,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(hsn, style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(uqc, style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(
                                '$qty',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                '₹${rate.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                '₹${amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ];

                          if (showTaxCols) {
                            cells.addAll([
                              DataCell(
                                Text(
                                  '${cgstR.toStringAsFixed(2)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${sgstR.toStringAsFixed(2)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${igstR.toStringAsFixed(2)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${utgstR.toStringAsFixed(2)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₹${taxAmt.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ]);
                          }

                          cells.add(
                            DataCell(
                              Text(
                                '₹${totalAmt.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                          return DataRow(cells: cells);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: AppColors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Credit Note',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'CN$creditNoteNumber',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Customer Info
                    Row(
                      children: [
                        Text(
                          'Customer: ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (createdAt != null)
                      Row(
                        children: [
                          Text(
                            'Date: ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    if (reason is String && reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Reason: ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Taxable Items Table
                    if (taxableItems.isNotEmpty) ...[
                      Text(
                        'Taxable Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildTable(taxableItems, showTaxCols: true),
                      const SizedBox(height: 16),
                    ],
                    // Non-taxable Items Table
                    if (nonTaxableItems.isNotEmpty) ...[
                      Text(
                        'Non-taxable Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildTable(nonTaxableItems, showTaxCols: false),
                      const SizedBox(height: 16),
                    ],

                    const Divider(),
                    const SizedBox(height: 16),

                    // Totals
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (taxableItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tax',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₹${totalTax.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '₹${grandTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class BillItemsForCreditNote extends ConsumerWidget {
  final int billId;
  const BillItemsForCreditNote({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(creditNotesBillItemsProvider(billId));
    final existingCNAsync = ref.watch(creditNotesForBillProvider(billId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bill Items'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No items'));

          final taxable = items.where((it) {
            final totalGst =
                (it['cgst_rate'] as num).toDouble() +
                (it['sgst_rate'] as num).toDouble() +
                (it['igst_rate'] as num).toDouble() +
                (it['utgst_rate'] as num).toDouble();
            return totalGst > 0;
          }).toList();

          final nonTaxable = items.where((it) {
            final totalGst =
                (it['cgst_rate'] as num).toDouble() +
                (it['sgst_rate'] as num).toDouble() +
                (it['igst_rate'] as num).toDouble() +
                (it['utgst_rate'] as num).toDouble();
            return totalGst == 0;
          }).toList();

          double subtotal = 0.0;
          double totalTax = 0.0;
          for (var it in items) {
            subtotal += (it['subtotal'] as num).toDouble();
            totalTax += (it['tax_amount'] as num).toDouble();
          }
          final grandTotal = subtotal + totalTax;

          Widget buildTable(
            List<Map<String, dynamic>> list, {
            required bool showTaxCols,
          }) {
            return LayoutBuilder(
              builder: (ctx2, constraints) {
                final width = constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: width),
                    child: Container(
                      width: width,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: DataTable(
                        columnSpacing: 16,
                        horizontalMargin: 8,
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade100,
                        ),
                        headingRowHeight: 48,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 56,
                        border: TableBorder.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        columns: [
                          const DataColumn(
                            label: Text(
                              'No',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'Product Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'P/N',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'HSN',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'UQC',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              'Qty',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            numeric: true,
                          ),
                          const DataColumn(
                            label: Text(
                              'Rate Per Unit',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            numeric: true,
                          ),
                          const DataColumn(
                            label: Text(
                              'Amount',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            numeric: true,
                          ),
                          if (showTaxCols) ...[
                            const DataColumn(
                              label: Text(
                                'CGST%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text(
                                'SGST%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text(
                                'IGST%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text(
                                'UTGST%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text(
                                'Tax Amt',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              numeric: true,
                            ),
                          ],
                          const DataColumn(
                            label: Text(
                              'Total Amount',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            numeric: true,
                          ),
                        ],
                        rows: list.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final it = entry.value;
                          final productName =
                              it['product_name'] as String? ?? '-';
                          final partNumber =
                              it['part_number'] as String? ?? '-';
                          final hsn = it['hsn_code'] as String? ?? '-';
                          final uqc = it['uqc_code'] as String? ?? '-';
                          final qty = it['quantity'] as int;
                          final rate = (it['selling_price'] as num).toDouble();
                          final amount = (it['subtotal'] as num).toDouble();
                          final cgstR = (it['cgst_rate'] as num).toDouble();
                          final sgstR = (it['sgst_rate'] as num).toDouble();
                          final igstR = (it['igst_rate'] as num).toDouble();
                          final utgstR = (it['utgst_rate'] as num).toDouble();
                          final taxAmt = (it['tax_amount'] as num).toDouble();
                          final totalAmt = (it['total_amount'] as num)
                              .toDouble();

                          final cells = <DataCell>[
                            DataCell(
                              Text(
                                '$idx',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  productName,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                partNumber,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(hsn, style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(uqc, style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(
                                '$qty',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                '₹${rate.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                '₹${amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ];

                          if (showTaxCols) {
                            cells.addAll([
                              DataCell(
                                Text(
                                  '${cgstR.toStringAsFixed(2)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${sgstR.toStringAsFixed(2)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${igstR.toStringAsFixed(2)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${utgstR.toStringAsFixed(2)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₹${taxAmt.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ]);
                          }

                          cells.add(
                            DataCell(
                              Text(
                                '₹${totalAmt.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                          return DataRow(cells: cells);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: AppColors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Bill Items',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // You can add a bill number or other info here if available
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    if (taxable.isNotEmpty) ...[
                      Text(
                        'Taxable Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildTable(taxable, showTaxCols: true),
                      const SizedBox(height: 16),
                    ],
                    if (nonTaxable.isNotEmpty) ...[
                      Text(
                        'Non-taxable Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildTable(nonTaxable, showTaxCols: false),
                      const SizedBox(height: 16),
                    ],

                    const Divider(),
                    const SizedBox(height: 16),

                    // Existing Credit Notes
                    existingCNAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, st) => Text('Error loading credit notes: $e'),
                      data: (cns) {
                        if (cns.isEmpty) return const SizedBox.shrink();
                        return Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Existing Credit Notes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...cns.map((cn) {
                                  final createdAt =
                                      cn['created_at'] as String? ?? '';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      cn['credit_note_number'] ?? '-',
                                    ),
                                    subtitle: Text(
                                      'Total: ₹${(cn['total_amount'] as num).toStringAsFixed(2)} • ${createdAt.split('T').first}',
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                    ),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CreditNoteDetailsScreen(
                                          creditNoteId: cn['id'] as int,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CreateCreditNoteScreen extends ConsumerStatefulWidget {
  final int billId;
  const CreateCreditNoteScreen({super.key, required this.billId});

  @override
  ConsumerState<CreateCreditNoteScreen> createState() =>
      _CreateCreditNoteScreenState();
}

class _CreateCreditNoteScreenState
    extends ConsumerState<CreateCreditNoteScreen> {
  final Map<int, int> _returnQuantities = {}; // bill_item_id -> qty to return
  final TextEditingController _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(creditNotesBillItemsProvider(widget.billId));
    final returnedAsync = ref.watch(returnedQuantitiesProvider(widget.billId));

    return Scaffold(
      appBar: AppBar(title: const Text('Create Credit Note')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty)
            return const Center(child: Text('No items to return'));

          return returnedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (returnedMap) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Reason field
                    TextField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason for return (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, idx) {
                          final it = items[idx];
                          final id = it['id'] as int; // bill_item id
                          final boughtQty = it['quantity'] as int;
                          final alreadyReturned = returnedMap[id] ?? 0;
                          final remaining = boughtQty - alreadyReturned;

                          final returnQty = _returnQuantities[id] ?? 0;

                          return ListTile(
                            title: Text(it['product_name'] ?? '-'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bought: $boughtQty   Remaining: $remaining',
                                ),
                                Text(
                                  'Price: ₹${(it['selling_price'] as num).toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                            trailing: SizedBox(
                              width: 140,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: returnQty > 0
                                        ? () => setState(
                                            () => _returnQuantities[id] =
                                                returnQty - 1,
                                          )
                                        : null,
                                  ),
                                  Text('$returnQty'),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: returnQty < remaining
                                        ? () => setState(
                                            () => _returnQuantities[id] =
                                                returnQty + 1,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _returnQuantities.values.any((v) => v > 0)
                          ? _submitCreditNote
                          : null,
                      child: const Text('Create Credit Note'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _submitCreditNote() async {
    final db = await ref.read(databaseProvider);
    final repo = BillRepository(db);

    // Fetch bill and items to build credit note
    final bill = await repo.getBillById(widget.billId);
    if (bill == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bill not found')));
      return;
    }

    final items = await repo.getBillItems(widget.billId);
    final returned = await repo.getReturnedQuantitiesForBill(widget.billId);

    final List<Map<String, dynamic>> creditItems = [];
    double subtotal = 0.0;
    double taxAmount = 0.0;

    for (final it in items) {
      final billItemId = it['id'] as int;
      final qtyToReturn = _returnQuantities[billItemId] ?? 0;
      if (qtyToReturn <= 0) continue;

      final boughtQty = it['quantity'] as int;
      final alreadyReturned = returned[billItemId] ?? 0;
      final allowed = boughtQty - alreadyReturned;
      if (qtyToReturn > allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Return qty for ${it['product_name']} exceeds allowed ($allowed)',
            ),
          ),
        );
        return;
      }

      final sellingPrice = (it['selling_price'] as num).toDouble();
      final lineSubtotal = sellingPrice * qtyToReturn;
      final cgstRate = (it['cgst_rate'] as num).toDouble();
      final sgstRate = (it['sgst_rate'] as num).toDouble();
      final igstRate = (it['igst_rate'] as num).toDouble();
      final utgstRate = (it['utgst_rate'] as num).toDouble();

      final cgstAmount = lineSubtotal * cgstRate / 100;
      final sgstAmount = lineSubtotal * sgstRate / 100;
      final igstAmount = lineSubtotal * igstRate / 100;
      final utgstAmount = lineSubtotal * utgstRate / 100;
      final lineTax = cgstAmount + sgstAmount + igstAmount + utgstAmount;
      final lineTotal = lineSubtotal + lineTax;

      subtotal += lineSubtotal;
      taxAmount += lineTax;

      creditItems.add({
        'bill_item_id': billItemId,
        'product_id': it['product_id'],
        'product_name': it['product_name'],
        'part_number': it['part_number'],
        'hsn_code': it['hsn_code'],
        'uqc_code': it['uqc_code'],
        'selling_price': sellingPrice,
        'quantity': qtyToReturn,
        'subtotal': lineSubtotal,
        'cgst_rate': cgstRate,
        'sgst_rate': sgstRate,
        'igst_rate': igstRate,
        'utgst_rate': utgstRate,
        'cgst_amount': cgstAmount,
        'sgst_amount': sgstAmount,
        'igst_amount': igstAmount,
        'utgst_amount': utgstAmount,
        'tax_amount': lineTax,
        'total_amount': lineTotal,
      });
    }

    if (creditItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected for return')),
      );
      return;
    }

    final totalAmount = subtotal + taxAmount;

    // Build credit note data
    final creditNoteData = {
      'bill_id': widget.billId,
      'credit_note_number': await repo.generateCreditNoteNumber(),
      'customer_id': bill['customer_id'],
      'reason': _reasonController.text.trim(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
    };

    try {
      final newId = await repo.createCreditNote(creditNoteData, creditItems);
      // Refresh the credit notes provider so Existing tab shows the new credit note immediately
      ref.invalidate(creditNotesProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Credit Note $newId created')));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating credit note: $e')));
    }
  }
}
