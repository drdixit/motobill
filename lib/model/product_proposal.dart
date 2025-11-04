class ProductProposal {
  final String name;
  final String partNumber;
  final String hsnCode;
  final double costPrice; // provided in sheet
  final double sellingPrice; // provided in sheet
  final double? mrp; // provided in sheet (optional)
  final bool includeTax; // whether provided prices include tax (YES/NO column)
  bool includeProvided =
      false; // whether include_tax column was provided in the sheet
  final String manufacturerNameFromExcel; // manufacturer name from Excel

  // computed
  int? existingProductId;
  int? hsnCodeId;
  double computedCostExcl = 0.0; // what we'll store in DB
  double computedSellingExcl = 0.0;
  bool valid = true;
  String? invalidReason;
  String? suggestion;

  bool approved = false;
  // display fields for DB / planned values
  Map<String, dynamic>? existingData;
  String? existingUqcCode; // Store UQC code for existing product display
  int? plannedSubCategoryId;
  String? plannedSubCategoryName;
  int? plannedManufacturerId;
  String? plannedManufacturerName;
  int? plannedUqcId;
  String? plannedUqcName;
  int? plannedIsTaxable;
  int? plannedIsEnabled;
  int? plannedNegativeAllow;

  ProductProposal({
    required this.name,
    required this.partNumber,
    required this.hsnCode,
    required this.costPrice,
    required this.sellingPrice,
    this.mrp,
    required this.includeTax,
    this.manufacturerNameFromExcel = '',
  });
}
