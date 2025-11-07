import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/providers/database_provider.dart';
import '../../model/company_info.dart';
import '../../view_model/company_info_viewmodel.dart';

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
  Future<pw.Document> _generateA4Invoice(
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
    final email = companyInfo?.email ?? '';
    final gstNumber = companyInfo?.gstNumber ?? '';

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

    // Customer details
    final customerName = bill['customer_name'] as String? ?? 'Walk-in';
    final customerPhone = bill['customer_phone'] as String? ?? '';
    final customerGst = bill['customer_gst'] as String? ?? '';
    final customerAddress1 = bill['address_line1'] as String? ?? '';
    final customerCity = bill['city'] as String? ?? '';
    final customerState = bill['state'] as String? ?? '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Company Info (Left)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      if (addressParts.isNotEmpty)
                        pw.Text(
                          addressParts.join(', '),
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      if (phone.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Phone: $phone',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                      if (email.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Email: $email',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                      if (gstNumber.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'GST: $gstNumber',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Invoice Title and Details (Right)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Bill : E${bill['bill_number']}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Date: $formattedDate',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),
            // Customer Details Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Bill To:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    customerName,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (customerAddress1.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      customerAddress1,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                  if (customerCity.isNotEmpty || customerState.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      [
                        customerCity,
                        customerState,
                      ].where((s) => s.isNotEmpty).join(', '),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                  if (customerPhone.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Phone: $customerPhone',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                  if (customerGst.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'GST: $customerGst',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.6), // No.
                1: const pw.FlexColumnWidth(2.5), // Product Name
                2: const pw.FlexColumnWidth(1.5), // Part Number
                3: const pw.FlexColumnWidth(0.7), // UQC
                4: const pw.FlexColumnWidth(1.2), // HSN Code
                5: const pw.FlexColumnWidth(0.5), // Qty
                6: const pw.FlexColumnWidth(1.5), // Rate Per Unit
                7: const pw.FlexColumnWidth(1.1), // Value
                8: const pw.FlexColumnWidth(1.4), // Taxable Amt
                9: const pw.FlexColumnWidth(0.9), // CGST%
                10: const pw.FlexColumnWidth(0.9), // SGST%
                11: const pw.FlexColumnWidth(0.9), // IGST%
                12: const pw.FlexColumnWidth(1), // UTGST%
                13: const pw.FlexColumnWidth(1.3), // Tax Amt
                14: const pw.FlexColumnWidth(1.5), // Total
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildTableCell(
                      'No.',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildTableCell('Product Name', isHeader: true),
                    _buildTableCell('Part Number', isHeader: true),
                    _buildTableCell(
                      'UQC',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'HSN Code',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Qty',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Rate Per Unit',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                    _buildTableCell(
                      'Value',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                    _buildTableCell(
                      'Taxable Amt',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                    _buildTableCell(
                      'CGST%',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'SGST%',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'IGST%',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'UTGST%',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Tax Amt',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                    _buildTableCell(
                      'Total',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                // Table Rows
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final productName =
                      item['product_name'] as String? ?? 'Unknown';
                  final partNumber = item['part_number'] as String? ?? '';
                  final hsnCode = item['hsn_code'] as String? ?? '';
                  final uqcCode = item['uqc_code'] as String? ?? '';
                  final quantity = (item['quantity'] as num).toDouble();
                  final sellingPrice = (item['selling_price'] as num)
                      .toDouble();

                  // Calculate values
                  final value = quantity * sellingPrice;
                  final cgstRate =
                      (item['cgst_rate'] as num?)?.toDouble() ?? 0.0;
                  final sgstRate =
                      (item['sgst_rate'] as num?)?.toDouble() ?? 0.0;
                  final igstRate =
                      (item['igst_rate'] as num?)?.toDouble() ?? 0.0;
                  final utgstRate =
                      (item['utgst_rate'] as num?)?.toDouble() ?? 0.0;

                  final cgstAmount =
                      (item['cgst_amount'] as num?)?.toDouble() ?? 0.0;
                  final sgstAmount =
                      (item['sgst_amount'] as num?)?.toDouble() ?? 0.0;
                  final igstAmount =
                      (item['igst_amount'] as num?)?.toDouble() ?? 0.0;
                  final utgstAmount =
                      (item['utgst_amount'] as num?)?.toDouble() ?? 0.0;

                  final taxAmount =
                      cgstAmount + sgstAmount + igstAmount + utgstAmount;
                  final totalAmount = (item['total_amount'] as num).toDouble();
                  final taxableAmount = totalAmount - taxAmount;

                  return pw.TableRow(
                    children: [
                      _buildTableCell(
                        '${index + 1}',
                        align: pw.TextAlign.center,
                      ),
                      _buildTableCell(productName, allowWrap: true),
                      _buildTableCell(partNumber),
                      _buildTableCell(uqcCode, align: pw.TextAlign.center),
                      _buildTableCell(hsnCode, align: pw.TextAlign.center),
                      _buildTableCell(
                        quantity.toStringAsFixed(0),
                        align: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        sellingPrice.toStringAsFixed(2),
                        align: pw.TextAlign.right,
                      ),
                      _buildTableCell(
                        value.toStringAsFixed(2),
                        align: pw.TextAlign.right,
                      ),
                      _buildTableCell(
                        taxableAmount.toStringAsFixed(2),
                        align: pw.TextAlign.right,
                      ),
                      _buildTableCell(
                        cgstRate.toStringAsFixed(2),
                        align: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        sgstRate.toStringAsFixed(2),
                        align: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        igstRate.toStringAsFixed(2),
                        align: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        utgstRate.toStringAsFixed(2),
                        align: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        taxAmount.toStringAsFixed(2),
                        align: pw.TextAlign.right,
                      ),
                      _buildTableCell(
                        totalAmount.toStringAsFixed(2),
                        align: pw.TextAlign.right,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // Totals Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left side - empty space
                pw.Expanded(child: pw.Container()),
                // Right side - totals
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      _buildTotalRow(
                        'Subtotal:',
                        (bill['subtotal'] as num).toDouble().toStringAsFixed(2),
                      ),
                      if ((bill['tax_amount'] as num?)?.toDouble() != null &&
                          (bill['tax_amount'] as num).toDouble() > 0)
                        _buildTotalRow(
                          'Tax:',
                          (bill['tax_amount'] as num)
                              .toDouble()
                              .toStringAsFixed(2),
                        ),
                      pw.Divider(thickness: 1.5),
                      _buildTotalRow(
                        'TOTAL:',
                        (bill['total_amount'] as num)
                            .toDouble()
                            .toStringAsFixed(2),
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.Spacer(),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Thank You for Your Business!',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf;
  }

  // Helper method to build table cells
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    bool allowWrap = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 6 : 5.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
        maxLines: allowWrap ? 2 : 1,
        softWrap: allowWrap,
      ),
    );
  }

  // Helper method to build total rows
  pw.Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printBill() async {
    try {
      final companyInfo = await ref.read(companyInfoForPrintProvider.future);
      final billData = await ref.read(
        billDetailsProvider(widget.billNumber).future,
      );

      final pdf = await _generateA4Invoice(companyInfo, billData);

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

      final pdf = await _generateA4Invoice(companyInfo, billData);

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
