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
  });

  ParsedInvoiceItem copyWith({bool? isApproved, bool? isTaxable}) {
    return ParsedInvoiceItem(
      partNumber: partNumber,
      description: description,
      hsnCode: hsnCode,
      quantity: quantity,
      uqc: uqc,
      rate: rate,
      cgstRate: cgstRate,
      sgstRate: sgstRate,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      totalAmount: totalAmount,
      isApproved: isApproved ?? this.isApproved,
      isTaxable: isTaxable ?? this.isTaxable,
    );
  }
}
