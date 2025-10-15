import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/providers/database_provider.dart';
import '../../model/company_info.dart';
import '../../repository/company_info_repository.dart';

// Provider for company info
final companyInfoForPrintProvider = FutureProvider<CompanyInfo?>((ref) async {
  final db = await ref.watch(databaseProvider);
  final repository = CompanyInfoRepository(db);
  return repository.getPrimaryCompanyInfo();
});

// Provider to fetch bill details for printing
final billDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((
  ref,
  billNumber,
) async {
  final db = await ref.watch(databaseProvider);

  // Fetch bill
  final billResult = await db.rawQuery(
    '''SELECT b.*, c.name as customer_name, c.legal_name as customer_legal_name,
         c.phone as customer_phone, c.gst_number as customer_gst,
         c.address_line1, c.city, c.state
         FROM bills b
         LEFT JOIN customers c ON b.customer_id = c.id
         WHERE b.bill_number = ? AND b.is_deleted = 0''',
    [billNumber],
  );

  if (billResult.isEmpty) {
    throw Exception('Bill not found');
  }

  final bill = billResult.first;

  // Fetch bill items
  final itemsResult = await db.rawQuery(
    '''SELECT bi.*, p.name as product_name, p.part_number
         FROM bill_items bi
         LEFT JOIN products p ON bi.product_id = p.id
         WHERE bi.bill_id = ?
         ORDER BY bi.id''',
    [bill['id']],
  );

  return {'bill': bill, 'items': itemsResult};
});

class BillPrintDialog extends ConsumerStatefulWidget {
  final String billNumber;

  const BillPrintDialog({super.key, required this.billNumber});

  @override
  ConsumerState<BillPrintDialog> createState() => _BillPrintDialogState();
}

class _BillPrintDialogState extends ConsumerState<BillPrintDialog> {
  Future<pw.Document> _generateThermalReceipt(
    CompanyInfo? companyInfo,
    Map<String, dynamic> billData,
  ) async {
    final pdf = pw.Document();
    final bill = billData['bill'] as Map<String, dynamic>;
    final items = billData['items'] as List<Map<String, dynamic>>;

    // Use company info or defaults
    final companyName = companyInfo?.name ?? 'Company Name';
    final address1 = companyInfo?.addressLine1 ?? '';
    final address2 = companyInfo?.addressLine2 ?? '';
    final city = companyInfo?.city ?? '';
    final state = companyInfo?.state ?? '';
    final pincode = companyInfo?.pincode ?? '';
    final phone = companyInfo?.phone ?? '';

    // Build full address
    final addressParts = <String>[];
    if (address1.isNotEmpty) addressParts.add(address1);
    if (address2.isNotEmpty) addressParts.add(address2);
    final cityStatePin = [
      city,
      state,
      pincode,
    ].where((s) => s.isNotEmpty).join(', ');
    if (cityStatePin.isNotEmpty) addressParts.add(cityStatePin);

    // Format date
    final createdAt = DateTime.parse(bill['created_at'] as String);
    final formattedDate =
        '${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Company Name
            pw.Text(
              companyName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            // Phone
            if (phone.isNotEmpty)
              pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 10)),
            // Company Details
            ...addressParts.map(
              (line) => pw.Text(
                line,
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 10),
            // Bill number and date in single line
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'E${bill['bill_number']}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 5),
            // Customer name (legal name or regular name)
            pw.Container(
              width: double.infinity,
              child: pw.Text(
                'Customer: ${bill['customer_legal_name']?.toString().isNotEmpty == true ? bill['customer_legal_name'] : (bill['customer_name'] ?? 'Walk-in')}',
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.left,
              ),
            ),
            // Customer phone if available
            if (bill['customer_phone'] != null &&
                bill['customer_phone'].toString().isNotEmpty)
              pw.Container(
                width: double.infinity,
                child: pw.Text(
                  'Phone: ${bill['customer_phone']}',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.left,
                ),
              ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            // Items header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Item',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 25,
                  child: pw.Text(
                    'Qty',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.SizedBox(
                  width: 40,
                  child: pw.Text(
                    'Rate',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.SizedBox(
                  width: 50,
                  child: pw.Text(
                    'Amount',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            pw.Divider(),
            // Items
            ...items.map((item) {
              final sellingPrice = (item['selling_price'] as num).toDouble();
              final quantity = (item['quantity'] as num).toInt();
              final taxAmount = (item['tax_amount'] as num).toDouble();
              final taxPerUnit = quantity > 0 ? taxAmount / quantity : 0.0;
              final rateWithTax = sellingPrice + taxPerUnit;
              final itemTotal = (item['total_amount'] as num).toDouble();

              return pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          item['product_name'] ?? 'Product',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.SizedBox(
                        width: 25,
                        child: pw.Text(
                          '$quantity',
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.SizedBox(
                        width: 40,
                        child: pw.Text(
                          rateWithTax.toStringAsFixed(2),
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.SizedBox(
                        width: 50,
                        child: pw.Text(
                          itemTotal.toStringAsFixed(2),
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                ],
              );
            }),
            pw.SizedBox(height: 5),
            pw.Divider(),
            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                  (bill['subtotal'] as num).toDouble().toStringAsFixed(2),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Tax:', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                  (bill['tax_amount'] as num).toDouble().toStringAsFixed(2),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  (bill['total_amount'] as num).toDouble().toStringAsFixed(2),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        ),
      ),
    );

    return pdf;
  }

  Future<void> _printBill() async {
    try {
      final companyInfo = await ref.read(companyInfoForPrintProvider.future);
      final billData = await ref.read(
        billDetailsProvider(widget.billNumber).future,
      );

      final pdf = await _generateThermalReceipt(companyInfo, billData);

      await Printing.layoutPdf(onLayout: (format) => pdf.save());

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Print dialog opened')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Print error: $e')));
      }
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final companyInfo = await ref.read(companyInfoForPrintProvider.future);
      final billData = await ref.read(
        billDetailsProvider(widget.billNumber).future,
      );

      final pdf = await _generateThermalReceipt(companyInfo, billData);

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'bill_${widget.billNumber}.pdf',
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF export error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final billDataAsync = ref.watch(billDetailsProvider(widget.billNumber));

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: billDataAsync.when(
          data: (billData) {
            final bill = billData['bill'] as Map<String, dynamic>;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bill Created Successfully!',
                            style: TextStyle(
                              fontSize: AppSizes.fontXL,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bill E${widget.billNumber}',
                            style: TextStyle(
                              fontSize: AppSizes.fontM,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingL),

                // Bill info
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer',
                            style: TextStyle(
                              fontSize: AppSizes.fontS,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            bill['customer_name'] ?? 'Walk-in',
                            style: TextStyle(
                              fontSize: AppSizes.fontM,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: AppSizes.fontS,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '₹${(bill['total_amount'] as num).toDouble().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: AppSizes.fontL,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.paddingL),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportToPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.paddingM,
                          ),
                          side: BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _printBill,
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.paddingM,
                          ),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.paddingXL),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: AppSizes.paddingM),
              Text(
                'Error loading bill details',
                style: TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
