import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/database_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../repository/purchase_repository.dart';
import '../../repository/debit_note_repository.dart';
import '../../view_model/pos_viewmodel.dart';

final debitNotesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final repo = DebitNoteRepository(db);
  return repo.getAllDebitNotes();
});

final debitNoteItemsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((
      ref,
      debitNoteId,
    ) async {
      final db = await ref.watch(databaseProvider);
      final repo = DebitNoteRepository(db);
      return repo.getDebitNoteItems(debitNoteId);
    });

final purchasesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final repo = PurchaseRepository(db);
  return repo.getAllPurchases();
});

final purchaseItemsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((
      ref,
      purchaseId,
    ) async {
      final db = await ref.watch(databaseProvider);
      final repo = PurchaseRepository(db);
      return repo.getPurchaseItems(purchaseId);
    });

final debitNotesForPurchaseProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((
      ref,
      purchaseId,
    ) async {
      final db = await ref.watch(databaseProvider);
      return await db.rawQuery(
        '''SELECT * FROM debit_notes WHERE purchase_id = ? AND is_deleted = 0 ORDER BY id DESC''',
        [purchaseId],
      );
    });

final returnedQuantitiesForPurchaseProvider =
    FutureProvider.family<Map<int, int>, int>((ref, purchaseId) async {
      final db = await ref.watch(databaseProvider);
      final rows = await db.rawQuery(
        '''SELECT dni.purchase_item_id as purchase_item_id, SUM(dni.quantity) as returned_qty
       FROM debit_note_items dni
       INNER JOIN debit_notes dn ON dni.debit_note_id = dn.id
       WHERE dn.purchase_id = ? AND dni.is_deleted = 0 AND dn.is_deleted = 0
       GROUP BY dni.purchase_item_id''',
        [purchaseId],
      );
      final Map<int, int> m = {};
      for (final r in rows) {
        m[r['purchase_item_id'] as int] = (r['returned_qty'] as num).toInt();
      }
      return m;
    });

final availableStockForPurchaseProvider =
    FutureProvider.family<Map<int, int>, int>((ref, purchaseId) async {
      final db = await ref.watch(databaseProvider);
      final repo = DebitNoteRepository(db);
      return repo.getAvailableStockForPurchase(purchaseId);
    });

class DebitNotesScreen extends ConsumerStatefulWidget {
  const DebitNotesScreen({super.key});

  @override
  ConsumerState<DebitNotesScreen> createState() => _DebitNotesScreenState();
}

class _DebitNotesScreenState extends ConsumerState<DebitNotesScreen>
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
    final notesAsync = ref.watch(debitNotesProvider);
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debit Notes'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
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
          notesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (notes) {
              if (notes.isEmpty)
                return const Center(child: Text('No debit notes'));

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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DebitNoteDetailsScreen(
                            debitNoteId: n['id'] as int,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'DN${n['debit_note_number'] ?? '-'}',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontL,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSizes.paddingS),
                              Text(
                                '₹${(n['total_amount'] as num).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.paddingXS),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n['vendor_name'] ?? '-',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontM,
                                    color: Colors.grey.shade600,
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
                                      color: Colors.grey.shade600,
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

          purchasesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (purchases) {
              if (purchases.isEmpty)
                return const Center(child: Text('No purchases found'));

              return ListView.builder(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                itemCount: purchases.length,
                itemBuilder: (context, index) {
                  final p = purchases[index];
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
                                'Purchase: ${p['purchase_number'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: AppSizes.fontL,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSizes.paddingXS),
                              Text(
                                p['vendor_name'] ?? '-',
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
                            // Don't show Create Debit Note button for auto purchases
                            if ((p['is_auto_purchase'] as int? ?? 0) == 0)
                              IconButton(
                                icon: const Icon(Icons.note_add_outlined),
                                color: AppColors.primary,
                                onPressed: () => _openCreateDebitNote(
                                  context,
                                  p['id'] as int,
                                ),
                                tooltip: 'Create Debit Note',
                              ),
                            IconButton(
                              icon: const Icon(Icons.receipt_long),
                              onPressed: () =>
                                  _openPurchaseItems(context, p['id'] as int),
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

  void _openPurchaseItems(BuildContext context, int purchaseId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseItemsForDebitNote(purchaseId: purchaseId),
      ),
    );
  }

  void _openCreateDebitNote(BuildContext context, int purchaseId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateDebitNoteScreen(purchaseId: purchaseId),
      ),
    );
  }
}

class DebitNoteDetailsScreen extends ConsumerWidget {
  final int debitNoteId;
  const DebitNoteDetailsScreen({super.key, required this.debitNoteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(debitNoteItemsProvider(debitNoteId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Debit Note Details'),
        backgroundColor: Colors.green,
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

          // Get debit note number, vendor, date, reason from first item
          final debitNoteNumber = items.first['debit_note_number'] ?? '-';
          final vendorName = items.first['vendor_name'] ?? '-';
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
                          final rate = (it['cost_price'] as num).toDouble();
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
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Debit Note',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'DN$debitNoteNumber',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Vendor Info
                    Row(
                      children: [
                        Text(
                          'Vendor: ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          vendorName,
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

class PurchaseItemsForDebitNote extends ConsumerWidget {
  Widget _buildTotalRow(String label, double amount, {bool isGrand = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isGrand ? FontWeight.w700 : FontWeight.w600,
            fontSize: isGrand ? 16 : 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: isGrand ? 18 : 14,
            color: isGrand ? Colors.green.shade700 : Colors.black87,
          ),
        ),
      ],
    );
  }

  // Helper for summary row
  final int purchaseId;
  const PurchaseItemsForDebitNote({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(purchaseItemsProvider(purchaseId));
    final existingAsync = ref.watch(debitNotesForPurchaseProvider(purchaseId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Purchase Items'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No items'));
          }

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
                          final rate = (it['cost_price'] as num).toDouble();
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
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Purchase Items',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // You can add a purchase number or other info here if available
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

                    // Summary section after tables
                    Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTotalRow('Subtotal:', subtotal),
                          const SizedBox(height: 8),
                          _buildTotalRow('Tax:', totalTax),
                          const SizedBox(height: 8),
                          _buildTotalRow('Total:', grandTotal, isGrand: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Existing Debit Notes
                    existingAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, st) => Text('Error loading debit notes: $e'),
                      data: (cns) {
                        if (cns.isEmpty) return const SizedBox.shrink();
                        return Card(
                          elevation: 2,
                          color: AppColors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Existing Debit Notes',
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
                                    title: Text(cn['debit_note_number'] ?? '-'),
                                    subtitle: Text(
                                      'Total: ₹${(cn['total_amount'] as num).toStringAsFixed(2)} • ${createdAt.split('T').first}',
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                    ),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => DebitNoteDetailsScreen(
                                          debitNoteId: cn['id'] as int,
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

class CreateDebitNoteScreen extends ConsumerStatefulWidget {
  final int purchaseId;
  const CreateDebitNoteScreen({super.key, required this.purchaseId});

  @override
  ConsumerState<CreateDebitNoteScreen> createState() =>
      _CreateDebitNoteScreenState();
}

class _CreateDebitNoteScreenState extends ConsumerState<CreateDebitNoteScreen> {
  final Map<int, int> _returnQuantities = {};
  final TextEditingController _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(purchaseItemsProvider(widget.purchaseId));
    final returnedAsync = ref.watch(
      returnedQuantitiesForPurchaseProvider(widget.purchaseId),
    );
    final availableStockAsync = ref.watch(
      availableStockForPurchaseProvider(widget.purchaseId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Debit Note'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('Error: $e', style: TextStyle(color: AppColors.error)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_outlined,
                    size: AppSizes.iconXL * 2,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSizes.paddingL),
                  Text(
                    'No items to return',
                    style: TextStyle(
                      fontSize: AppSizes.fontXL,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return returnedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Text(
                'Error: $e',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            data: (returnedMap) {
              return availableStockAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Text(
                    'Error: $e',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                data: (availableStockMap) {
                  // Calculate totals
                  double totalAmount = 0.0;
                  for (var entry in _returnQuantities.entries) {
                    final qty = entry.value;
                    if (qty > 0) {
                      final item = items.firstWhere(
                        (it) => it['id'] == entry.key,
                      );
                      final price = (item['cost_price'] as num).toDouble();
                      final subtotal = price * qty;
                      final cgst =
                          subtotal *
                          (item['cgst_rate'] as num).toDouble() /
                          100;
                      final sgst =
                          subtotal *
                          (item['sgst_rate'] as num).toDouble() /
                          100;
                      final igst =
                          subtotal *
                          (item['igst_rate'] as num).toDouble() /
                          100;
                      final utgst =
                          subtotal *
                          (item['utgst_rate'] as num).toDouble() /
                          100;
                      totalAmount += subtotal + cgst + sgst + igst + utgst;
                    }
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSizes.paddingL),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Reason field
                              Container(
                                padding: const EdgeInsets.all(
                                  AppSizes.paddingM,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusM,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Return Reason',
                                      style: TextStyle(
                                        fontSize: AppSizes.fontM,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSizes.paddingS),
                                    TextField(
                                      controller: _reasonController,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Enter reason for return (optional)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusS,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: AppSizes.paddingM,
                                              vertical: AppSizes.paddingS,
                                            ),
                                      ),
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSizes.paddingL),

                              // Items table
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusM,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 20,
                                    horizontalMargin: 16,
                                    headingRowColor: WidgetStateProperty.all(
                                      Colors.grey.shade100,
                                    ),
                                    headingRowHeight: 48,
                                    dataRowMinHeight: 56,
                                    dataRowMaxHeight: 72,
                                    border: TableBorder.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'No.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Product Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Part Number',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Price',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'CGST%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'SGST%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'IGST%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Purchased',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Returned',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Available Stock',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Return Qty',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: items.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final it = entry.value;
                                      final id = it['id'] as int;
                                      final boughtQty = it['quantity'] as int;
                                      final alreadyReturned =
                                          returnedMap[id] ?? 0;
                                      final availableStock =
                                          availableStockMap[id] ?? 0;
                                      final remaining =
                                          boughtQty - alreadyReturned;
                                      final returnQty =
                                          _returnQuantities[id] ?? 0;

                                      // Maximum returnable is minimum of remaining and available stock
                                      final maxReturnable =
                                          remaining < availableStock
                                          ? remaining
                                          : availableStock;

                                      return DataRow(
                                        cells: [
                                          DataCell(Text('${idx + 1}')),
                                          DataCell(
                                            SizedBox(
                                              width: 200,
                                              child: Text(
                                                it['product_name'] ?? '-',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(it['part_number'] ?? '-'),
                                          ),
                                          DataCell(
                                            Text(
                                              '₹${(it['cost_price'] as num).toStringAsFixed(2)}',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${(it['cgst_rate'] as num).toStringAsFixed(2)}%',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${(it['sgst_rate'] as num).toStringAsFixed(2)}%',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${(it['igst_rate'] as num).toStringAsFixed(2)}%',
                                            ),
                                          ),
                                          DataCell(Text('$boughtQty')),
                                          DataCell(
                                            Text(
                                              '$alreadyReturned',
                                              style: TextStyle(
                                                color: alreadyReturned > 0
                                                    ? Colors.orange
                                                    : null,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '$availableStock',
                                              style: TextStyle(
                                                color:
                                                    availableStock < remaining
                                                    ? Colors.red.shade700
                                                    : Colors.green.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                    size: 20,
                                                  ),
                                                  onPressed: returnQty > 0
                                                      ? () => setState(
                                                          () =>
                                                              _returnQuantities[id] =
                                                                  returnQty - 1,
                                                        )
                                                      : null,
                                                ),
                                                SizedBox(
                                                  width: 40,
                                                  child: Text(
                                                    '$returnQty',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16,
                                                      color: returnQty > 0
                                                          ? AppColors.primary
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                    size: 20,
                                                  ),
                                                  onPressed:
                                                      returnQty < maxReturnable
                                                      ? () => setState(
                                                          () =>
                                                              _returnQuantities[id] =
                                                                  returnQty + 1,
                                                        )
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom bar with total and save button
                      Container(
                        padding: const EdgeInsets.all(AppSizes.paddingL),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Total Return Amount',
                                    style: TextStyle(
                                      fontSize: AppSizes.fontM,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: AppSizes.fontXXL,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed:
                                  _returnQuantities.values.any((v) => v > 0)
                                  ? _submitDebitNote
                                  : null,
                              icon: const Icon(Icons.save),
                              label: const Text('Create Debit Note'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.paddingXL,
                                  vertical: AppSizes.paddingL,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusS,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _submitDebitNote() async {
    final db = await ref.read(databaseProvider);
    final repo = DebitNoteRepository(db);
    final purchaseRepo = PurchaseRepository(db);

    final purchase = await purchaseRepo.getPurchaseById(widget.purchaseId);
    if (purchase == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Purchase not found')));
      return;
    }

    final items = await purchaseRepo.getPurchaseItems(widget.purchaseId);

    final List<Map<String, dynamic>> debitItems = [];
    double subtotal = 0.0;
    double taxAmount = 0.0;

    for (final it in items) {
      final purchaseItemId = it['id'] as int;
      final qtyToReturn = _returnQuantities[purchaseItemId] ?? 0;
      if (qtyToReturn <= 0) continue;

      final costPrice = (it['cost_price'] as num).toDouble();
      final lineSubtotal = costPrice * qtyToReturn;
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

      debitItems.add({
        'purchase_item_id': purchaseItemId,
        'product_id': it['product_id'],
        'product_name': it['product_name'],
        'part_number': it['part_number'],
        'hsn_code': it['hsn_code'],
        'uqc_code': it['uqc_code'],
        'cost_price': costPrice,
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

    if (debitItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected for return')),
      );
      return;
    }

    final debitNoteData = {
      'purchase_id': widget.purchaseId,
      'debit_note_number': '',
      'vendor_id': purchase['vendor_id'],
      'reason': _reasonController.text.trim(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': subtotal + taxAmount,
    };

    try {
      final newId = await repo.createDebitNote(debitNoteData, debitItems);

      // Invalidate providers to refresh data across the app
      ref.invalidate(debitNotesProvider);
      ref.invalidate(purchasesProvider);
      ref.invalidate(posViewModelProvider);
      ref.invalidate(purchaseItemsProvider(widget.purchaseId));
      ref.invalidate(returnedQuantitiesForPurchaseProvider(widget.purchaseId));
      ref.invalidate(availableStockForPurchaseProvider(widget.purchaseId));
      ref.invalidate(debitNotesForPurchaseProvider(widget.purchaseId));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Debit Note $newId created')));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating debit note: $e')));
    }
  }
}
