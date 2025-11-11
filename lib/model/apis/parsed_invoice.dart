class ParsedInvoice {
  final String invoiceNumber;
  final String invoiceDate;
  final ParsedVendorInfo vendor;
  final List<ParsedInvoiceItem> items;
  final double subtotal;
  final double cgstAmount;
  final double sgstAmount;
  final double totalAmount;

  ParsedInvoice({
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.vendor,
    required this.items,
    required this.subtotal,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.totalAmount,
  });
}

class ParsedVendorInfo {
  final String name;
  final String gstin;
  final String address;
  final String city;
  final String state;
  final String? phone;

  ParsedVendorInfo({
    required this.name,
    required this.gstin,
    required this.address,
    required this.city,
    required this.state,
    this.phone,
  });
}

class ParsedInvoiceItem {
  final String partNumber;
  final String description;
  final String hsnCode;
  final int quantity;
  final String uqc;
  final double rate;
  final double cgstRate;
  final double sgstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double totalAmount;
  bool isApproved;
  bool isTaxable;
  final bool
  isPriceFromBill; // Track if price is from bill (true) or database (false)

  ParsedInvoiceItem({
    required this.partNumber,
    required this.description,
    required this.hsnCode,
    required this.quantity,
    required this.uqc,
    required this.rate,
    required this.cgstRate,
    required this.sgstRate,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.totalAmount,
    this.isApproved = false,
    this.isTaxable = true,
    this.isPriceFromBill = true, // Default: assume price is from bill
  });

  ParsedInvoiceItem copyWith({
    bool? isApproved,
    bool? isTaxable,
    bool? isPriceFromBill,
    double? rate,
    double? cgstRate,
    double? sgstRate,
    double? cgstAmount,
    double? sgstAmount,
    double? totalAmount,
  }) {
    return ParsedInvoiceItem(
      partNumber: partNumber,
      description: description,
      hsnCode: hsnCode,
      quantity: quantity,
      uqc: uqc,
      rate: rate ?? this.rate,
      cgstRate: cgstRate ?? this.cgstRate,
      sgstRate: sgstRate ?? this.sgstRate,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      isApproved: isApproved ?? this.isApproved,
      isTaxable: isTaxable ?? this.isTaxable,
      isPriceFromBill: isPriceFromBill ?? this.isPriceFromBill,
    );
  }
}
