import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../model/company_info.dart';
import '../../../repository/company_info_repository.dart';

// Provider for bill type
final billTypeProvider = StateProvider<String>((ref) => 'Thermal Receipt');

// Provider for company info
final companyInfoProvider = FutureProvider<CompanyInfo?>((ref) async {
  final db = await ref.watch(databaseProvider);
  final repository = CompanyInfoRepository(db);
  return repository.getPrimaryCompanyInfo();
});

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _printTestBill() async {
    final billType = ref.read(billTypeProvider);
    final companyInfo = await ref.read(companyInfoProvider.future);

    try {
      final pdf = billType == 'Thermal Receipt'
          ? await _generateThermalReceipt(companyInfo)
          : await _generateDetailedInvoice(companyInfo);

      // On Windows, this will open the system print dialog
      await Printing.layoutPdf(onLayout: (format) => pdf.save());

      if (mounted) {
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
    final billType = ref.read(billTypeProvider);
    final companyInfo = await ref.read(companyInfoProvider.future);

    try {
      final pdf = billType == 'Thermal Receipt'
          ? await _generateThermalReceipt(companyInfo)
          : await _generateDetailedInvoice(companyInfo);

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'test_bill_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF export error: $e')));
      }
    }
  }

  Future<pw.Document> _generateThermalReceipt(CompanyInfo? companyInfo) async {
    final pdf = pw.Document();

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
            // Company Details
            ...addressParts.map(
              (line) => pw.Text(
                line,
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (phone.isNotEmpty)
              pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),
            pw.Divider(),
            // Bill Details
            pw.Text(
              'TEST BILL',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            // Bill number and date in single line
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('E-TEST001', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                  '${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            // Items
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Item',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Qty',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Amount',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Sample Product',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text('2', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('200.00', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            // Total
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
                  '200.00',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.Text(
              'Thank you for your business!',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 20),
          ],
        ),
      ),
    );

    return pdf;
  }

  Future<pw.Document> _generateDetailedInvoice(CompanyInfo? companyInfo) async {
    final pdf = pw.Document();

    // Use company info or defaults
    final companyName = companyInfo?.name ?? 'Company Name';
    final address1 = companyInfo?.addressLine1 ?? '';
    final address2 = companyInfo?.addressLine2 ?? '';
    final city = companyInfo?.city ?? '';
    final state = companyInfo?.state ?? '';
    final pincode = companyInfo?.pincode ?? '';
    final phone = companyInfo?.phone ?? '';
    final gstNumber = companyInfo?.gstNumber ?? '';

    // Build full address lines
    final addressLines = <String>[];
    if (address1.isNotEmpty) addressLines.add(address1);
    if (address2.isNotEmpty) addressLines.add(address2);
    final cityStatePin = [
      city,
      state,
      pincode,
    ].where((s) => s.isNotEmpty).join(', ');
    if (cityStatePin.isNotEmpty) addressLines.add(cityStatePin);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    ...addressLines.map((line) => pw.Text(line)),
                    if (phone.isNotEmpty) pw.Text('Phone: $phone'),
                    if (gstNumber.isNotEmpty) pw.Text('GSTIN: $gstNumber'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Invoice No: TEST001'),
                    pw.Text(
                      'Date: ${DateTime.now().toString().substring(0, 10)}',
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 20),
            // Customer Details
            pw.Text(
              'Bill To:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Test Customer'),
            pw.Text('Customer Address'),
            pw.SizedBox(height: 20),
            // Items Table
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'No.',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Description',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Qty',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Price',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Tax',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Amount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                // Sample Item
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('1'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Sample Product'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('2'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('100.00'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('36.00'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('236.00'),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 150, child: pw.Text('Subtotal:')),
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                            '200.00',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 150, child: pw.Text('CGST (9%):')),
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                            '18.00',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 150, child: pw.Text('SGST (9%):')),
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                            '18.00',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 150,
                          child: pw.Text(
                            'Total:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                            '236.00',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Terms & Conditions:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('1. Payment due within 30 days'),
            pw.Text('2. Goods once sold will not be taken back'),
          ],
        ),
      ),
    );

    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    final billType = ref.watch(billTypeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Printer Configuration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure printer settings, bill formats, and test printing',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // Printer Info Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.print, size: 48, color: AppColors.primary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'System Printer',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bills will be printed using your Windows default printer.\nYou can select a different printer when printing.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bill Type Selection
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill Format',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<String>(
                      title: const Text('Thermal Receipt (80mm)'),
                      subtitle: const Text(
                        'Compact receipt for thermal printers',
                      ),
                      value: 'Thermal Receipt',
                      groupValue: billType,
                      onChanged: (value) {
                        ref.read(billTypeProvider.notifier).state = value!;
                      },
                      activeColor: AppColors.primary,
                    ),
                    RadioListTile<String>(
                      title: const Text('Detailed Invoice (A4)'),
                      subtitle: const Text(
                        'Full detailed invoice with company info',
                      ),
                      value: 'Detailed Invoice',
                      groupValue: billType,
                      onChanged: (value) {
                        ref.read(billTypeProvider.notifier).state = value!;
                      },
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test & Export',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _printTestBill,
                            icon: const Icon(Icons.print),
                            label: const Text('Print Test Bill'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exportToPdf,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export to PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
