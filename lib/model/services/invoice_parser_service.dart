import 'dart:convert';
import '../apis/parsed_invoice.dart';

class InvoiceParserService {
  /// Parse Azure Form Recognizer invoice response JSON
  static ParsedInvoice? parseInvoiceResponse(String jsonResponse) {
    try {
      // Extract JSON body from formatted response
      String cleanJson = jsonResponse;

      // Check if response contains formatting headers
      if (jsonResponse.contains('--- Body ---')) {
        // Extract content after "--- Body ---"
        final bodyIndex = jsonResponse.indexOf('--- Body ---');
        if (bodyIndex != -1) {
          cleanJson = jsonResponse.substring(bodyIndex + 13).trim();
        }
      }

      // Remove large response placeholder line
      // Example: "[Large response: 379798 bytes]"
      if (cleanJson.startsWith('[Large response:')) {
        final newlineIndex = cleanJson.indexOf('\n');
        if (newlineIndex != -1) {
          cleanJson = cleanJson.substring(newlineIndex + 1).trim();
        }
      }

      // Remove truncation marker if present
      if (cleanJson.contains('[...truncated]')) {
        final truncIndex = cleanJson.indexOf('[...truncated]');
        if (truncIndex != -1) {
          cleanJson = cleanJson.substring(0, truncIndex).trim();
        }
      }

      final data = jsonDecode(cleanJson);

      // Extract invoice details - handle both response formats
      // Format 1: { "analyzeResult": { "documents": [...] } }
      // Format 2: { "documents": [...] } (direct)
      var documents = data['analyzeResult']?['documents'];

      // If not found in analyzeResult, check root level
      if (documents == null) {
        documents = data['documents'];
      }

      if (documents == null || documents.isEmpty) {
        print('ERROR: No documents found in response');
        print('Available keys in data: ${data.keys.toList()}');
        if (data['analyzeResult'] != null) {
          print(
            'Available keys in analyzeResult: ${data['analyzeResult'].keys.toList()}',
          );
        }
        return null;
      }

      final doc = documents[0];
      final fields = doc['fields'];

      if (fields == null) {
        print('ERROR: No fields found in document');
        print('Available keys in document: ${doc.keys.toList()}');
        return null;
      }

      // Log available field names for debugging
      print('Available fields in invoice: ${fields.keys.toList()}');

      // Extract invoice number and date
      final invoiceNumber =
          fields['InvoiceId']?['content'] ??
          fields['InvoiceNumber']?['content'] ??
          fields['invoiceId']?['content'] ??
          fields['invoiceNumber']?['content'] ??
          '';
      final invoiceDate =
          fields['InvoiceDate']?['content'] ??
          fields['invoiceDate']?['content'] ??
          '';

      // Extract vendor info (VendorName, VendorAddress, VendorAddressRecipient)
      final vendorName =
          fields['VendorName']?['content'] ??
          fields['vendorName']?['content'] ??
          fields['SellerName']?['content'] ??
          '';

      // Try multiple field name variants for GSTIN
      String vendorGstin = _extractGSTIN(fields, 'Vendor');
      if (vendorGstin.isEmpty) {
        vendorGstin = _extractGSTIN(fields, 'Seller');
      }
      if (vendorGstin.isEmpty) {
        vendorGstin = _extractGSTIN(fields, 'VendorTaxId');
      }

      final vendorAddress =
          fields['VendorAddress']?['content'] ??
          fields['vendorAddress']?['content'] ??
          fields['SellerAddress']?['content'] ??
          '';
      final vendorCity = _extractCity(vendorAddress);
      final vendorState = _extractState(vendorAddress);

      // Extract line items
      final items = <ParsedInvoiceItem>[];

      // Handle both response formats:
      // Format 1: valueArray with valueObject
      // Format 2: valueList with valueDictionary
      var itemsList =
          fields['Items']?['valueArray'] ??
          fields['items']?['valueArray'] ??
          fields['Items']?['valueList'] ??
          fields['items']?['valueList'] ??
          [];

      if (itemsList.isEmpty) {
        print(
          'WARNING: No line items found. Available fields: ${fields.keys.toList()}',
        );
      }

      for (var item in itemsList) {
        // Try both valueObject and valueDictionary
        final itemFields = item['valueObject'] ?? item['valueDictionary'];
        if (itemFields == null) continue;

        // Log fields in first item for debugging
        if (items.isEmpty) {
          print('First item fields: ${itemFields.keys.toList()}');
        }

        // Try multiple field name variants for each item property
        final description =
            itemFields['Description']?['content'] ??
            itemFields['description']?['content'] ??
            itemFields['ItemDescription']?['content'] ??
            itemFields['ProductDescription']?['content'] ??
            '';

        // ProductCode in Azure invoice is the part number (e.g., "52DJ1617", "DK181086")
        final partNumber =
            itemFields['ProductCode']?['content'] ??
            itemFields['productCode']?['content'] ??
            itemFields['PartNumber']?['content'] ??
            itemFields['partNumber']?['content'] ??
            itemFields['ItemCode']?['content'] ??
            _extractPartNumber(
              description,
            ); // Fallback to extracting from description

        // HSN code is separate from ProductCode
        final hsnCode =
            itemFields['HSNCode']?['content'] ??
            itemFields['hsnCode']?['content'] ??
            itemFields['HSN']?['content'] ??
            itemFields['hsn']?['content'] ??
            '';

        // For Quantity, prefer valueNumber over content (content may include unit like "1 Nos")
        final quantityValue =
            itemFields['Quantity']?['valueNumber'] ??
            itemFields['quantity']?['valueNumber'] ??
            itemFields['Qty']?['valueNumber'];

        final quantity = quantityValue != null
            ? (quantityValue is int
                  ? quantityValue
                  : (quantityValue as double).toInt())
            : _parseDouble(
                itemFields['Quantity']?['content'] ??
                    itemFields['quantity']?['content'] ??
                    itemFields['Qty']?['content'],
              ).toInt();

        final uqc =
            itemFields['Unit']?['content'] ??
            itemFields['unit']?['content'] ??
            itemFields['UOM']?['content'] ??
            itemFields['uom']?['content'] ??
            'NOS';
        final unitPrice = _parseDouble(
          itemFields['UnitPrice']?['content'] ??
              itemFields['unitPrice']?['content'] ??
              itemFields['Rate']?['content'] ??
              itemFields['rate']?['content'],
        );
        final amount = _parseDouble(
          itemFields['Amount']?['content'] ??
              itemFields['amount']?['content'] ??
              itemFields['Total']?['content'] ??
              itemFields['total']?['content'],
        );
        final taxRate = _parseDouble(
          itemFields['Tax']?['content'] ??
              itemFields['TaxRate']?['content'] ??
              itemFields['tax']?['content'] ??
              itemFields['taxRate']?['content'] ??
              itemFields['GST']?['content'] ??
              itemFields['gst']?['content'],
        );

        // Calculate CGST/SGST (split GST rate)
        final cgstRate = taxRate / 2;
        final sgstRate = taxRate / 2;

        // Calculate base amount (amount before tax)
        final baseAmount = amount / (1 + (taxRate / 100));
        final cgstAmount = baseAmount * (cgstRate / 100);
        final sgstAmount = baseAmount * (sgstRate / 100);

        items.add(
          ParsedInvoiceItem(
            partNumber: partNumber,
            description: description,
            hsnCode: hsnCode,
            quantity: quantity,
            uqc: uqc,
            rate: unitPrice,
            cgstRate: cgstRate,
            sgstRate: sgstRate,
            cgstAmount: cgstAmount,
            sgstAmount: sgstAmount,
            totalAmount: amount,
            isApproved: false,
            isTaxable: true,
          ),
        );
      }

      // Calculate totals
      double subtotal = 0;
      double cgstTotal = 0;
      double sgstTotal = 0;
      double grandTotal = 0;

      for (var item in items) {
        final baseAmount =
            item.totalAmount / (1 + ((item.cgstRate + item.sgstRate) / 100));
        subtotal += baseAmount;
        cgstTotal += item.cgstAmount;
        sgstTotal += item.sgstAmount;
        grandTotal += item.totalAmount;
      }

      // Validate critical fields and warn about missing data
      if (invoiceNumber.isEmpty) {
        print(
          'WARNING: Invoice number is missing. Tried fields: InvoiceId, InvoiceNumber, invoiceId, invoiceNumber',
        );
      }
      if (invoiceDate.isEmpty) {
        print(
          'WARNING: Invoice date is missing. Tried fields: InvoiceDate, invoiceDate',
        );
      }
      if (vendorName.isEmpty) {
        print(
          'WARNING: Vendor name is missing. Tried fields: VendorName, vendorName, SellerName',
        );
      }
      if (vendorGstin.isEmpty) {
        print(
          'WARNING: Vendor GSTIN is missing. Tried multiple prefix combinations (Vendor, Seller, VendorTaxId)',
        );
      }
      if (items.isEmpty) {
        print('ERROR: No line items were parsed from invoice!');
      }

      return ParsedInvoice(
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        vendor: ParsedVendorInfo(
          name: vendorName,
          gstin: vendorGstin,
          address: vendorAddress,
          city: vendorCity,
          state: vendorState,
        ),
        items: items,
        subtotal: subtotal,
        cgstAmount: cgstTotal,
        sgstAmount: sgstTotal,
        totalAmount: grandTotal,
      );
    } catch (e, stackTrace) {
      print('Error parsing invoice: $e');
      print('Stack trace: $stackTrace');
      // Print first 500 chars of response for debugging
      if (jsonResponse.length > 500) {
        print('Response start: ${jsonResponse.substring(0, 500)}');
      } else {
        print('Response: $jsonResponse');
      }
      return null;
    }
  }

  static String _extractGSTIN(Map<String, dynamic> fields, String prefix) {
    // Try different field names for GSTIN
    final gstinField =
        fields['${prefix}TaxId']?['content'] ??
        fields['${prefix}GSTIN']?['content'] ??
        fields['${prefix}GSTNumber']?['content'] ??
        '';
    return gstinField;
  }

  static String _extractPartNumber(String description) {
    // Extract part number from description (usually the first part before description)
    final parts = description.split(' ');
    if (parts.isNotEmpty) {
      return parts[0];
    }
    return '';
  }

  static String _extractCity(String address) {
    // Extract city from address (simplified logic)
    final parts = address.split(',');
    if (parts.length >= 2) {
      return parts[parts.length - 2].trim();
    }
    return '';
  }

  static String _extractState(String address) {
    // Look for common state names in address
    final stateKeywords = [
      'Gujarat',
      'Maharashtra',
      'Karnataka',
      'Tamil Nadu',
      'Delhi',
      'Rajasthan',
      'Uttar Pradesh',
      'Punjab',
    ];

    for (var state in stateKeywords) {
      if (address.contains(state)) {
        return state;
      }
    }
    return '';
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Remove currency symbols, commas, and unit text (Nos, PCS, etc.)
      final cleaned = value
          .replaceAll(RegExp(r'[₹,\s]'), '')
          .replaceAll(RegExp(r'[A-Za-z]+'), ''); // Remove alphabetic characters
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }
}
