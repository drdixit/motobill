import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/bill_repository.dart';
import '../../../model/company_info.dart';
import '../../../view_model/company_info_viewmodel.dart';
import '../../widgets/payment_dialog.dart';
import '../../widgets/bill_print_dialog.dart';
import '../transactions_screen.dart';
import 'bill_details_screen.dart';

// Provider for bills list with date filtering
final billsListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = BillRepository(db);
  final dateRange = ref.watch(transactionDateRangeProvider);
  return repository.getBillsByDateRange(dateRange.start, dateRange.end);
});

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
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

  List<Map<String, dynamic>> _filterBills(List<Map<String, dynamic>> bills) {
    if (_searchQuery.isEmpty) return bills;

    final query = _searchQuery.toLowerCase();
    return bills.where((bill) {
      final billNumber = (bill['bill_number'] as String).toLowerCase();
      final customerName = (bill['customer_name'] as String? ?? '')
          .toLowerCase();
      return _fuzzyMatch(billNumber, query) || _fuzzyMatch(customerName, query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);

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
                      hintText: 'Search by bill number or customer...',
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
                // Bulk PDF Print Button
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => _showBulkPrintDialog(billsAsync.value ?? []),
                  tooltip: 'Print All Bills (PDF)',
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(billsListProvider),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Bills List
          Expanded(
            child: billsAsync.when(
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
              data: (bills) {
                final filteredBills = _filterBills(bills);

                if (filteredBills.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No bills found'
                              : 'No matching bills',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Create your first bill to get started'
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
                  itemCount: filteredBills.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final bill = filteredBills[index];
                    return _buildBillCard(context, bill);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, Map<String, dynamic> bill) {
    final billNumber = bill['bill_number'] as String;
    final customerName = bill['customer_name'] as String? ?? 'Unknown Customer';
    final totalAmount = (bill['total_amount'] as num).toDouble();
    final paidAmount = (bill['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final paymentStatus = bill['payment_status'] as String? ?? 'unpaid';
    final pendingRefunds = (bill['pending_refunds'] as num?)?.toDouble() ?? 0.0;
    final totalReturned = (bill['total_returned'] as num?)?.toDouble() ?? 0.0;

    // Calculate net remaining after returns
    // When products are returned, the bill amount is reduced by return value
    final billRemaining = totalAmount - paidAmount;
    final netRemaining = billRemaining - totalReturned;

    // If product is fully or mostly returned (return >= bill total - 0.01 tolerance),
    // no payment should be collected
    final isFullyReturned = totalReturned >= (totalAmount - 0.01);

    // Remaining amount is net remaining (considering returns)
    // But if fully returned or customer overpaid (negative), show 0
    final remainingAmount = (!isFullyReturned && netRemaining > 0.01)
        ? netRemaining
        : 0.0;

    final createdAt = DateTime.parse(bill['created_at'] as String);

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
      padding: const EdgeInsets.all(16),
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
              builder: (context) =>
                  BillDetailsScreen(billId: bill['id'] as int),
            ),
          );
          // Refresh bills list when returning from bill details
          ref.invalidate(billsListProvider);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First line: Bill number with status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    billNumber,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
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
              ],
            ),
            const SizedBox(height: 8),
            // Customer name and date
            Row(
              children: [
                Expanded(
                  child: Text(
                    customerName,
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
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Payment info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (paymentStatus != 'unpaid')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paid',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${paidAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                if (paymentStatus == 'partial' && remainingAmount > 0.01)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${remainingAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            // Show pending refunds chip if any
            if (pendingRefunds > 0.01) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pending Refund: ₹${pendingRefunds.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Action buttons row
            const SizedBox(height: 12),
            Row(
              children: [
                // Print Button (always visible)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPrintDialog(context, billNumber),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                // Add Payment button - only show if:
                // 1. Not fully paid
                // 2. Effective remaining > 0
                // 3. NO pending refunds (customer should settle refund first)
                if (paymentStatus != 'paid' &&
                    remainingAmount > 0.01 &&
                    pendingRefunds <= 0.01) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _showAddPaymentDialog(context, bill);
                      },
                      icon: const Icon(Icons.payment, size: 18),
                      label: Text(
                        paymentStatus == 'unpaid'
                            ? 'Add Payment'
                            : 'Add More Payment',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
                // Show message if there are pending refunds blocking payment
                if (pendingRefunds > 0.01 &&
                    paymentStatus != 'paid' &&
                    billRemaining > 0.01) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Settle refund first',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Show message if products are fully returned
                if (isFullyReturned &&
                    paymentStatus != 'paid' &&
                    billRemaining > 0.01) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_return,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Fully Returned',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPaymentDialog(
    BuildContext context,
    Map<String, dynamic> bill,
  ) async {
    final billId = bill['id'] as int;
    final totalAmount = (bill['total_amount'] as num).toDouble();
    final paidAmount = (bill['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final totalReturned = (bill['total_returned'] as num?)?.toDouble() ?? 0.0;

    // Calculate net remaining after returns
    final billRemaining = totalAmount - paidAmount;
    final netRemaining = billRemaining - totalReturned;
    final remainingAmount = netRemaining > 0 ? netRemaining : 0.0;

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
      final repository = BillRepository(db);

      await repository.addPayment(
        billId: billId,
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

      // Refresh bills list
      ref.invalidate(billsListProvider);
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

  // Show print dialog for single bill
  void _showPrintDialog(BuildContext context, String billNumber) {
    showDialog(
      context: context,
      builder: (context) => BillPrintDialog(billNumber: billNumber),
    );
  }

  // Show bulk print dialog for all bills in date range
  Future<void> _showBulkPrintDialog(List<Map<String, dynamic>> bills) async {
    if (bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bills to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Print Bills'),
        content: Text(
          'Print all ${bills.length} bills from the selected date range?\n\nThis will generate a PDF with all bills.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Print All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating bulk PDF...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final db = await ref.read(databaseProvider);
      final companyInfoAsync = ref.read(companyInfoForPrintProvider);
      final companyInfo = companyInfoAsync.value;

      // Generate PDF with all bills
      final pdf = pw.Document();

      for (final bill in bills) {
        final billNumber = bill['bill_number'] as String;

        // Fetch bill details
        final billResult = await db.rawQuery(
          '''SELECT b.*, c.name as customer_name, c.legal_name as customer_legal_name,
               c.phone as customer_phone, c.gst_number as customer_gst,
               c.address_line1, c.city, c.state
               FROM bills b
               LEFT JOIN customers c ON b.customer_id = c.id
               WHERE b.bill_number = ? AND b.is_deleted = 0''',
          [billNumber],
        );

        if (billResult.isEmpty) continue;

        final billData = billResult.first;

        // Fetch bill items
        final itemsResult = await db.rawQuery(
          '''SELECT bi.*, p.name as product_name, p.part_number
               FROM bill_items bi
               LEFT JOIN products p ON bi.product_id = p.id
               WHERE bi.bill_id = ?
               ORDER BY bi.id''',
          [billData['id']],
        );

        // Add page for this bill
        pdf.addPage(
          await _generateBillPage(companyInfo, billData, itemsResult),
        );
      }

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show print preview
      if (mounted) {
        await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Generate a single bill page for PDF
  Future<pw.Page> _generateBillPage(
    CompanyInfo? companyInfo,
    Map<String, dynamic> billData,
    List<Map<String, dynamic>> items,
  ) async {
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
    final createdAt = DateTime.parse(billData['created_at'] as String);
    final formattedDate =
        '${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year}';

    // Customer details
    final customerName = billData['customer_name'] as String? ?? 'N/A';
    final customerPhone = billData['customer_phone'] as String? ?? '';
    final customerGst = billData['customer_gst'] as String? ?? '';
    final customerAddress1 = billData['address_line1'] as String? ?? '';
    final customerCity = billData['city'] as String? ?? '';
    final customerState = billData['state'] as String? ?? '';

    return pw.Page(
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
                        'GSTIN: $gstNumber',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              // Invoice Title (Right)
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
                    'Bill: ${billData['bill_number']}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
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
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILL TO:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  customerName,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (customerPhone.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Phone: $customerPhone',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
                if (customerGst.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'GSTIN: $customerGst',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
                if (customerAddress1.isNotEmpty || customerCity.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    [
                      customerAddress1,
                      customerCity,
                      customerState,
                    ].where((s) => s.isNotEmpty).join(', '),
                    style: const pw.TextStyle(fontSize: 11),
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
              5: const pw.FlexColumnWidth(0.7), // Qty
              6: const pw.FlexColumnWidth(1.5), // Rate Per Unit
              7: const pw.FlexColumnWidth(1.3), // Value
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
                final sellingPrice = (item['selling_price'] as num).toDouble();

                // Calculate values
                final value = quantity * sellingPrice;
                final cgstRate = (item['cgst_rate'] as num?)?.toDouble() ?? 0.0;
                final sgstRate = (item['sgst_rate'] as num?)?.toDouble() ?? 0.0;
                final igstRate = (item['igst_rate'] as num?)?.toDouble() ?? 0.0;
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
                    _buildTableCell('${index + 1}', align: pw.TextAlign.center),
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
                      (billData['subtotal'] as num).toDouble().toStringAsFixed(
                        2,
                      ),
                    ),
                    if ((billData['tax_amount'] as num?)?.toDouble() != null &&
                        (billData['tax_amount'] as num).toDouble() > 0)
                      _buildTotalRow(
                        'Tax:',
                        (billData['tax_amount'] as num)
                            .toDouble()
                            .toStringAsFixed(2),
                      ),
                    pw.Divider(thickness: 1.5),
                    _buildTotalRow(
                      'TOTAL:',
                      (billData['total_amount'] as num)
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
    );
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
}
