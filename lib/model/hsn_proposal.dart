/// Represents a single HSN code proposal parsed from Excel
/// and the proposed database actions
class HsnProposal {
  final String hsnCode;
  String? description;
  double cgst;
  double sgst;
  double igst;
  double utgst;
  DateTime? effectiveFrom; // nullable - user may omit

  // Populated during analysis
  int? existingHsnId;
  List<Map<String, dynamic>> existingRates = [];
  bool valid = true;
  String? invalidReason;
  String? suggestion;
  String? warning;

  bool approved = false;
  bool selectable = true; // Only one proposal per HSN may be selectable

  HsnProposal({
    required this.hsnCode,
    this.description,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.utgst,
    this.effectiveFrom,
  });

  DateTime get effectiveFromOrToday => effectiveFrom ?? DateTime.now();
}
