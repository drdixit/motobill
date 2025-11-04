import 'package:flutter/material.dart';
import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/providers/database_provider.dart';
import '../../model/manufacturer.dart';
import '../../repository/manufacturer_repository.dart';

class ProductUploadScreen extends ConsumerStatefulWidget {
  const ProductUploadScreen({super.key});

  @override
  ConsumerState<ProductUploadScreen> createState() =>
      _ProductUploadScreenState();
}

class _ProductProposal {
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

  _ProductProposal({
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

class _ProductUploadScreenState extends ConsumerState<ProductUploadScreen> {
  String? _fileName;
  String? _uploadedFilePath; // Store original file path for copying after apply
  final Map<String, List<List<String>>> _sheets = {};
  final List<_ProductProposal> _proposals = [];
  bool _isProcessing = false;
  double _progress = 0.0;
  String _progressMessage = '';

  // Manufacturer dropdown state
  List<Manufacturer> _manufacturers = [];
  int _selectedDefaultManufacturerId = 1;

  @override
  void initState() {
    super.initState();
    _loadManufacturers();
  }

  Future<void> _loadManufacturers() async {
    try {
      final db = await ref.read(databaseProvider);
      final repository = ManufacturerRepository(db);
      final manufacturers = await repository.getAllManufacturers();
      setState(() {
        _manufacturers = manufacturers;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  // Helper method to resolve manufacturer ID from Excel name or use dropdown default
  int _resolveManufacturerId(String manufacturerNameFromExcel) {
    // If Excel has no manufacturer name, use dropdown default
    if (manufacturerNameFromExcel.isEmpty) {
      return _selectedDefaultManufacturerId;
    }

    // Try to match manufacturer case-insensitively
    final matchedManufacturer = _manufacturers
        .where(
          (m) =>
              m.name.toLowerCase() == manufacturerNameFromExcel.toLowerCase(),
        )
        .firstOrNull;

    if (matchedManufacturer != null) {
      // Found a match, use it
      return matchedManufacturer.id ?? _selectedDefaultManufacturerId;
    }

    // No match found, use dropdown default
    return _selectedDefaultManufacturerId;
  }

  Future<void> _downloadTemplate() async {
    try {
      // Load the template from assets
      final byteData = await rootBundle.load('assets/products.xlsx');
      final bytes = byteData.buffer.asUint8List();

      // Let user pick a save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Product Template',
        fileName: 'product_template.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) return;

      // Write the file
      final file = File(result);
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template downloaded to: ${path.basename(result)}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download template: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    try {
      final bytes = File(path).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Validate I1 (column I, row 1) of the first sheet: it MUST contain
      // exactly four space characters ("    "). If not, reject the file and
      // show an error message. Product Upload uses I1 as the sentinel.
      if (excel.tables.isNotEmpty) {
        final firstKey = excel.tables.keys.first;
        final firstTable = excel.tables[firstKey];
        if (firstTable != null && firstTable.rows.isNotEmpty) {
          final firstRow = firstTable.rows.first;
          String h1Val = '';
          // Column I is index 8 (0-based)
          if (firstRow.length > 8 && firstRow[8] != null) {
            final v = firstRow[8]?.value;
            h1Val = v == null ? '' : v.toString();
          }

          if (h1Val != '    ') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Invalid Uploaded Excel File Please Use Official Template',
                  ),
                ),
              );
            }
            return;
          }
        }
      }

      final Map<String, List<List<String>>> parsed = {};
      for (final sheetName in excel.tables.keys) {
        final table = excel.tables[sheetName];
        if (table == null) continue;
        final rows = <List<String>>[];
        for (final row in table.rows) {
          final cells = row
              .map((cell) {
                if (cell == null) return '';
                final val = cell.value;
                return val == null ? '' : val.toString();
              })
              .toList(growable: false);
          rows.add(cells);
        }
        parsed[sheetName] = rows;
      }

      setState(() {
        _sheets
          ..clear()
          ..addAll(parsed);
        _fileName = result.files.single.name;
        _uploadedFilePath = path; // Store path for copying after apply
      });
      // Prepare proposals for preview
      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _progressMessage = 'Analyzing products...';
      });
      await _prepareProductProposalsFromLoaded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read Excel file: $e')),
        );
      }
    }
  }

  // product proposals prepared from uploaded sheet

  Future<void> _prepareProductProposalsFromLoaded() async {
    _proposals.clear();
    if (_sheets.isEmpty) return;
    final first = _sheets.entries.first.value;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressMessage = 'Analyzing products...';
    });

    // Pre-load all manufacturers once instead of querying in loop
    final db = await ref.read(databaseProvider);
    final manufacturerMap = <int, String>{};
    try {
      final manufacturerRows = await db.rawQuery(
        'SELECT id, name FROM manufacturers WHERE is_deleted = 0',
      );
      for (final row in manufacturerRows) {
        manufacturerMap[row['id'] as int] = row['name'] as String;
      }
    } catch (_) {
      // Ignore manufacturer loading errors
    }

    // Pre-load all HSN codes once to avoid repeated queries
    final hsnMap = <String, int>{};
    try {
      final hsnRows = await db.rawQuery(
        'SELECT id, code FROM hsn_codes WHERE is_deleted = 0',
      );
      for (final row in hsnRows) {
        hsnMap[row['code'] as String] = row['id'] as int;
      }
    } catch (_) {
      // Ignore HSN loading errors
    }

    // Pre-load all GST rates once
    final gstRatesMap = <int, Map<String, dynamic>>{};
    try {
      final gstRows = await db.rawQuery(
        '''SELECT hsn_code_id, cgst, sgst, igst, utgst
           FROM gst_rates
           WHERE is_deleted = 0 AND effective_to IS NULL
           ORDER BY effective_from DESC''',
      );
      for (final row in gstRows) {
        final hsnCodeId = row['hsn_code_id'] as int;
        if (!gstRatesMap.containsKey(hsnCodeId)) {
          gstRatesMap[hsnCodeId] = row;
        }
      }
    } catch (_) {
      // Ignore GST rates loading errors
    }

    // Pre-load all existing products by part_number for quick lookups
    final existingProductsMap = <String, Map<String, dynamic>>{};
    try {
      final productRows = await db.rawQuery(
        'SELECT * FROM products WHERE is_deleted = 0',
      );
      for (final row in productRows) {
        final partNumber = row['part_number'] as String?;
        if (partNumber != null && partNumber.isNotEmpty) {
          existingProductsMap[partNumber.toLowerCase()] = row;
        }
      }
    } catch (_) {
      // Ignore product loading errors
    }

    // Pre-load all UQC codes for quick lookups
    final uqcMap = <int, String>{};
    try {
      final uqcRows = await db.rawQuery(
        'SELECT id, code FROM uqcs WHERE is_deleted = 0',
      );
      for (final row in uqcRows) {
        uqcMap[row['id'] as int] = row['code'] as String;
      }
    } catch (_) {
      // Ignore UQC loading errors
    }

    // Pre-load sub-category names for display
    final subCategoryMap = <int, String>{};
    try {
      final subCatRows = await db.rawQuery(
        'SELECT id, name FROM sub_categories WHERE is_deleted = 0',
      );
      for (final row in subCatRows) {
        subCategoryMap[row['id'] as int] = row['name'] as String;
      }
    } catch (_) {
      // Ignore sub-category loading errors
    }

    final totalRows = first.length;
    final batchSize = 1000; // Increased batch size for better performance

    for (var rowIndex = 0; rowIndex < first.length; rowIndex++) {
      // Update progress every batch
      if (rowIndex % batchSize == 0) {
        setState(() {
          _progress = rowIndex / totalRows;
          _progressMessage = 'Analyzing products... ($rowIndex/$totalRows)';
        });
        // Allow UI to update
        await Future.delayed(const Duration(milliseconds: 5));
      }

      final row = first[rowIndex];
      // first row is header; skip it
      if (rowIndex == 0) continue;
      if (row.isEmpty) continue;
      final name = row.length > 0 ? row[0].trim() : '';
      final part = row.length > 1 ? row[1].trim() : '';
      final hsn = row.length > 2 ? row[2].trim() : '';
      double parseDouble(dynamic v) {
        if (v == null) return 0.0;
        final s = v.toString().trim();
        if (s.isEmpty) return 0.0;
        return double.tryParse(s) ?? 0.0;
      }

      final cost = parseDouble(row.length > 3 ? row[3] : null);
      final sell = parseDouble(row.length > 4 ? row[4] : null);
      final includeRaw = row.length > 5 ? row[5] : null;
      final includeStr = includeRaw == null ? '' : includeRaw.toString().trim();
      final includeProvided = includeStr.isNotEmpty;
      // Parse include_tax: YES/Yes/yes/Y/y = true, NO/No/no/N/n = false
      final includeTax =
          includeProvided &&
          (includeStr.toLowerCase() == 'yes' ||
              includeStr.toLowerCase() == 'y' ||
              includeStr.toLowerCase() == '1' ||
              includeStr.toLowerCase() == 'true');
      final mrpValue = row.length > 6 ? parseDouble(row[6]) : null;
      final mrp = (mrpValue != null && mrpValue > 0) ? mrpValue : null;
      // Read manufacturer name from column H (index 7)
      final manufacturerName = row.length > 7 ? row[7].trim() : '';

      // require name and hsn (part_number is optional)
      if (name.isEmpty || hsn.isEmpty) {
        // still add but mark invalid; keep part optional
        final p = _ProductProposal(
          name: name,
          partNumber: part,
          hsnCode: hsn,
          costPrice: cost,
          sellingPrice: sell,
          mrp: mrp,
          includeTax: includeTax,
          manufacturerNameFromExcel: manufacturerName,
        );
        // ensure computed values default to provided values so UI is consistent
        p.computedCostExcl = p.costPrice;
        p.computedSellingExcl = p.sellingPrice;
        p.valid = false;
        // craft a concise missing/invalid message (show only field names)
        final missing = <String>[];
        if (name.isEmpty) missing.add('name');
        if (hsn.isEmpty) missing.add('hsn_code');
        p.invalidReason = missing.join(', ');
        // set planned defaults so UI doesn't show nulls
        const defaultSubCategoryId = 1;
        const defaultUqcId = 9;
        const defaultIsTaxable = 0;
        const defaultIsEnabled = 1;
        const defaultNegativeAllow = 0;
        p.plannedSubCategoryId = defaultSubCategoryId;
        p.plannedManufacturerId = _resolveManufacturerId(manufacturerName);
        p.plannedUqcId = defaultUqcId;
        p.plannedIsTaxable = defaultIsTaxable;
        p.plannedIsEnabled = defaultIsEnabled;
        p.plannedNegativeAllow = defaultNegativeAllow;
        p.includeProvided = includeProvided;

        // Use pre-loaded manufacturer name
        if (p.plannedManufacturerId != null) {
          p.plannedManufacturerName = manufacturerMap[p.plannedManufacturerId];
        }

        _proposals.add(p);
        continue;
      }

      // require cost and selling provided
      if (cost <= 0 || sell <= 0) {
        final p = _ProductProposal(
          name: name,
          partNumber: part,
          hsnCode: hsn,
          costPrice: cost,
          sellingPrice: sell,
          mrp: mrp,
          includeTax: includeTax,
          manufacturerNameFromExcel: manufacturerName,
        );
        p.includeProvided = includeProvided;
        // keep provided values visible
        p.computedCostExcl = p.costPrice;
        p.computedSellingExcl = p.sellingPrice;
        p.valid = false;
        // Show concise field names for what's missing/invalid
        final missingPrice = <String>[];
        if (cost <= 0) missingPrice.add('cost_price');
        if (sell <= 0) missingPrice.add('selling_price');
        p.invalidReason = missingPrice.join(', ');
        // set planned defaults to avoid nulls in UI
        const defaultSubCategoryId = 1;
        const defaultUqcId = 9;
        const defaultIsTaxable = 0;
        const defaultIsEnabled = 1;
        const defaultNegativeAllow = 0;
        p.plannedSubCategoryId = defaultSubCategoryId;
        p.plannedManufacturerId = _resolveManufacturerId(manufacturerName);
        p.plannedUqcId = defaultUqcId;
        p.plannedIsTaxable = defaultIsTaxable;
        p.plannedIsEnabled = defaultIsEnabled;
        p.plannedNegativeAllow = defaultNegativeAllow;

        // Use pre-loaded manufacturer name
        if (p.plannedManufacturerId != null) {
          p.plannedManufacturerName = manufacturerMap[p.plannedManufacturerId];
        }

        _proposals.add(p);
        continue;
      }

      // include_tax is required
      if (!includeProvided) {
        final p = _ProductProposal(
          name: name,
          partNumber: part,
          hsnCode: hsn,
          costPrice: cost,
          sellingPrice: sell,
          mrp: mrp,
          includeTax: includeTax,
          manufacturerNameFromExcel: manufacturerName,
        );
        p.includeProvided = includeProvided;
        p.computedCostExcl = p.costPrice;
        p.computedSellingExcl = p.sellingPrice;
        p.valid = false;
        // concise invalid reason
        p.invalidReason = 'include_tax';
        // set planned defaults to avoid null UI values
        const defaultSubCategoryId = 1;
        const defaultUqcId = 9;
        const defaultIsTaxable = 0;
        const defaultIsEnabled = 1;
        const defaultNegativeAllow = 0;
        p.plannedSubCategoryId = defaultSubCategoryId;
        p.plannedManufacturerId = _resolveManufacturerId(manufacturerName);
        p.plannedUqcId = defaultUqcId;
        p.plannedIsTaxable = defaultIsTaxable;
        p.plannedIsEnabled = defaultIsEnabled;
        p.plannedNegativeAllow = defaultNegativeAllow;

        // Use pre-loaded manufacturer name
        if (p.plannedManufacturerId != null) {
          p.plannedManufacturerName = manufacturerMap[p.plannedManufacturerId];
        }

        _proposals.add(p);
        continue;
      }

      final p = _ProductProposal(
        name: name,
        partNumber: part,
        hsnCode: hsn,
        costPrice: cost,
        sellingPrice: sell,
        mrp: mrp,
        includeTax: includeTax,
        manufacturerNameFromExcel: manufacturerName,
      );
      p.includeProvided = includeProvided;

      // default to showing provided values unless we reverse-calc using HSN GST
      p.computedCostExcl = p.costPrice;
      p.computedSellingExcl = p.sellingPrice;

      try {
        // Lookup existing product by part_number using pre-loaded map
        final existingProduct = existingProductsMap[p.partNumber.toLowerCase()];
        if (existingProduct != null) {
          p.existingProductId = existingProduct['id'] as int;
          p.existingData = existingProduct;

          // Get UQC code for existing product using pre-loaded map
          final uqcId = existingProduct['uqc_id'];
          if (uqcId != null) {
            p.existingUqcCode = uqcMap[uqcId as int];
          }
        }

        // Use pre-loaded HSN code map
        p.hsnCodeId = hsnMap[p.hsnCode];

        if (p.hsnCodeId != null) {
          // include_tax must be provided when HSN exists
          if (!includeProvided) {
            p.valid = false;
            // concise invalid reason
            p.invalidReason = 'include_tax';
            _proposals.add(p);
            continue;
          }

          // Use pre-loaded GST rates
          final active = gstRatesMap[p.hsnCodeId];

          if (active != null) {
            final cgst = (active['cgst'] as num?)?.toDouble() ?? 0.0;
            final sgst = (active['sgst'] as num?)?.toDouble() ?? 0.0;
            final igst = (active['igst'] as num?)?.toDouble() ?? 0.0;
            double totalTax = 0.0;
            if (cgst > 0 || sgst > 0)
              totalTax = cgst + sgst;
            else if (igst > 0)
              totalTax = igst;

            if (totalTax <= 0) {
              p.valid = false;
              p.invalidReason =
                  'HSN has no GST rate to compute tax percentages';
            } else {
              // Determine final cost/sell excluding tax
              double computeExcl(double incl) {
                if (incl <= 0) return 0.0;
                return incl / (1 + totalTax / 100.0);
              }

              if (p.includeTax) {
                p.computedCostExcl = computeExcl(p.costPrice);
                p.computedSellingExcl = computeExcl(p.sellingPrice);
                p.suggestion = 'Reversed tax ${totalTax}% from included prices';
              } else {
                p.computedCostExcl = p.costPrice;
                p.computedSellingExcl = p.sellingPrice;
              }
            }
          } else {
            p.valid = false;
            p.invalidReason = 'No GST rates found for HSN code ${p.hsnCode}';
          }
        } else {
          // HSN not present -> mark invalid (show a clear HSN problem message)
          p.valid = false;
          p.invalidReason =
              'Problem with HSN code: ${p.hsnCode} not found in DB';
        }
        // For display: planned DB values for new inserts or existing values
        const defaultSubCategoryId = 1;
        const defaultUqcId = 9;
        const defaultIsTaxable = 0;
        const defaultIsEnabled = 1;
        const defaultNegativeAllow = 0;

        if (p.existingData != null) {
          // fill planned display values from existing product row
          p.plannedSubCategoryId =
              (p.existingData!['sub_category_id'] as num?)?.toInt() ??
              defaultSubCategoryId;
          // For existing products: Use Excel manufacturer if provided and valid,
          // otherwise use dropdown default (don't keep old manufacturer)
          p.plannedManufacturerId = _resolveManufacturerId(
            p.manufacturerNameFromExcel,
          );
          p.plannedUqcId =
              (p.existingData!['uqc_id'] as num?)?.toInt() ?? defaultUqcId;
          p.plannedIsTaxable =
              (p.existingData!['is_taxable'] as num?)?.toInt() ??
              defaultIsTaxable;
          p.plannedIsEnabled =
              (p.existingData!['is_enabled'] as num?)?.toInt() ??
              defaultIsEnabled;
          p.plannedNegativeAllow =
              (p.existingData!['negative_allow'] as num?)?.toInt() ??
              defaultNegativeAllow;
        } else {
          // use defaults for new inserts
          p.plannedSubCategoryId = defaultSubCategoryId;
          // Match manufacturer from Excel or use dropdown default
          p.plannedManufacturerId = _resolveManufacturerId(
            p.manufacturerNameFromExcel,
          );
          p.plannedUqcId = defaultUqcId;
          p.plannedIsTaxable = defaultIsTaxable;
          p.plannedIsEnabled = defaultIsEnabled;
          p.plannedNegativeAllow = defaultNegativeAllow;
        }

        // Try to fetch names for subcategory/manufacturer/uqc (best-effort)
        try {
          // Use pre-loaded sub-category name
          if (p.plannedSubCategoryId != null) {
            p.plannedSubCategoryName = subCategoryMap[p.plannedSubCategoryId];
          }
          // Use pre-loaded manufacturer name
          if (p.plannedManufacturerId != null) {
            p.plannedManufacturerName =
                manufacturerMap[p.plannedManufacturerId];
          }
          // Use pre-loaded UQC code
          if (p.plannedUqcId != null) {
            p.plannedUqcName = uqcMap[p.plannedUqcId];
          }
        } catch (_) {
          // ignore lookup failures - display IDs if names not found
        }
      } catch (e) {
        p.valid = false;
        p.invalidReason = 'DB error: $e';
      }

      _proposals.add(p);
    }

    setState(() {
      _isProcessing = false;
      _progress = 1.0;
      _progressMessage = '';
    });
  }

  // Update manufacturer names for all proposals
  Future<void> _updateManufacturerNames() async {
    if (_proposals.isEmpty) return;

    try {
      final db = await ref.read(databaseProvider);
      // Pre-load manufacturer names
      final manufacturerMap = <int, String>{};
      final manufacturerRows = await db.rawQuery(
        'SELECT id, name FROM manufacturers WHERE is_deleted = 0',
      );
      for (final row in manufacturerRows) {
        manufacturerMap[row['id'] as int] = row['name'] as String;
      }

      for (final p in _proposals) {
        // Re-resolve manufacturer ID for ALL products (new and existing)
        // Use Excel manufacturer if valid, otherwise use dropdown default
        p.plannedManufacturerId = _resolveManufacturerId(
          p.manufacturerNameFromExcel,
        );

        // Use pre-loaded manufacturer name
        if (p.plannedManufacturerId != null) {
          p.plannedManufacturerName = manufacturerMap[p.plannedManufacturerId];
        }
      }
      setState(() {}); // Trigger UI update
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _applySelectedProductProposals() async {
    final rawToApply = _proposals.where((p) => p.approved && p.valid).toList();
    // Ensure at most one proposal per product is applied (defensive).
    // Prefer deduping by part_number (case-insensitive) if present, otherwise by name.
    final Map<String, _ProductProposal> uniqueByKey = {};
    for (final p in rawToApply) {
      final part = p.partNumber.trim();
      final key = part.isNotEmpty ? part.toLowerCase() : p.name.toLowerCase();
      if (!uniqueByKey.containsKey(key)) uniqueByKey[key] = p;
    }
    final toApply = uniqueByKey.values.toList();

    // Check if there are any selected products BEFORE setting processing state
    if (toApply.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one valid product to apply'),
            backgroundColor: Colors.grey,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressMessage = 'Preparing to save products...';
    });

    final db = await ref.read(databaseProvider);
    try {
      final totalToApply = toApply.length;
      await db.transaction((txn) async {
        for (var i = 0; i < toApply.length; i++) {
          // Update progress every 20 products
          if (i % 20 == 0) {
            setState(() {
              _progress = i / totalToApply;
              _progressMessage = 'Saving products... ($i/$totalToApply)';
            });
          }

          final p = toApply[i];
          // Require HSN to exist (we do not auto-create HSNs during product import)
          if (p.hsnCodeId == null) {
            throw Exception('HSN code missing for product ${p.partNumber}');
          }
          final hsnId = p.hsnCodeId!;

          // Defaults per user instructions
          const defaultSubCategoryId = 1; // assumption: exists
          const defaultUqcId = 9; // as requested
          const defaultIsTaxable = 0; // 0
          const defaultIsEnabled = 1;

          // Use planned manufacturer ID (resolved from Excel or dropdown)
          final manufacturerId = p.plannedManufacturerId ?? 1;

          final existing = await txn.rawQuery(
            'SELECT * FROM products WHERE LOWER(part_number) = LOWER(?) AND is_deleted = 0 LIMIT 1',
            [p.partNumber],
          );
          if (existing.isNotEmpty) {
            final id = existing.first['id'] as int;
            // round prices to 2 decimal places before storing
            final costToStore = double.parse(
              p.computedCostExcl.toStringAsFixed(2),
            );
            final sellToStore = double.parse(
              p.computedSellingExcl.toStringAsFixed(2),
            );
            final mrpToStore = p.mrp != null
                ? double.parse(p.mrp!.toStringAsFixed(2))
                : null;
            await txn.rawUpdate(
              '''
              UPDATE products SET
                name = ?, hsn_code_id = ?, uqc_id = ?, cost_price = ?, selling_price = ?, mrp = ?, sub_category_id = ?, manufacturer_id = ?, is_taxable = ?, updated_at = datetime('now')
              WHERE id = ?
              ''',
              [
                p.name,
                hsnId,
                defaultUqcId,
                costToStore,
                sellToStore,
                mrpToStore,
                defaultSubCategoryId,
                manufacturerId,
                defaultIsTaxable,
                id,
              ],
            );
          } else {
            // round prices to 2 decimal places before storing
            final costToStore = double.parse(
              p.computedCostExcl.toStringAsFixed(2),
            );
            final sellToStore = double.parse(
              p.computedSellingExcl.toStringAsFixed(2),
            );
            final mrpToStore = p.mrp != null
                ? double.parse(p.mrp!.toStringAsFixed(2))
                : null;
            await txn.rawInsert(
              '''
              INSERT INTO products (name, part_number, hsn_code_id, uqc_id, cost_price, selling_price, mrp, sub_category_id, manufacturer_id, is_taxable, is_enabled, negative_allow, is_deleted, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, datetime('now'), datetime('now'))
              ''',
              [
                p.name,
                p.partNumber,
                hsnId,
                defaultUqcId,
                costToStore,
                sellToStore,
                mrpToStore,
                defaultSubCategoryId,
                manufacturerId,
                defaultIsTaxable,
                defaultIsEnabled,
                0, // negative_allow default false
              ],
            );
          }
        }
      });

      // Copy Excel file to storage directory after successful database transaction
      if (_uploadedFilePath != null) {
        try {
          final timestamp = DateTime.now();
          final formattedTimestamp =
              '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_'
              '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';

          final fileName = 'products_$formattedTimestamp.xlsx';
          final destinationPath = path.join(
            'C:',
            'motobill',
            'database',
            'excel_files',
            fileName,
          );

          // Copy the file
          final sourceFile = File(_uploadedFilePath!);
          await sourceFile.copy(destinationPath);

          // Insert record into excel_uploads table
          final createdAt = timestamp.toIso8601String();
          await db.rawInsert(
            'INSERT INTO excel_uploads (file_name, file_type, created_at, updated_at) VALUES (?, ?, ?, ?)',
            [fileName, 'products', createdAt, createdAt],
          );
        } catch (e) {
          // Log error but don't fail the operation
          debugPrint('Failed to copy Excel file: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Applied selected product proposals')),
        );
        // Clear UI state after successful apply as requested
        setState(() {
          _fileName = null;
          _uploadedFilePath = null; // Clear stored path
          _sheets.clear();
          _proposals.clear();
          _isProcessing = false;
          _progress = 0.0;
          _progressMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _progress = 0.0;
        _progressMessage = '';
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply products: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: AppSizes.paddingM,
        left: AppSizes.paddingL,
        right: AppSizes.paddingL,
        bottom: AppSizes.paddingL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Product Upload',
                style: TextStyle(
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload .xlsx'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  if (_sheets.isNotEmpty)
                    ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () {
                              setState(() {
                                _fileName = null;
                                _sheets.clear();
                                _proposals.clear();
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),
          if (_isProcessing)
            Card(
              color: AppColors.white,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.border, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _progressMessage,
                                style: TextStyle(
                                  fontSize: AppSizes.fontM,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSizes.paddingS),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _progress,
                                  minHeight: 8,
                                  backgroundColor: AppColors.border,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Text(
                          '${(_progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: AppSizes.fontM,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_isProcessing) const SizedBox(height: AppSizes.paddingL),
          if (_sheets.isNotEmpty)
            // Show first sheet content in a scrollable DataTable and proposals
            // Make this card take the remaining available height so the
            // proposals list can expand and scroll as needed.
            Expanded(
              child: Card(
                color: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.border, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Purposed changes: ${_fileName ?? ""}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: AppSizes.fontL,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Valid: ${_proposals.where((p) => p.valid).length}  Invalid: ${_proposals.where((p) => !p.valid).length}  Selected: ${_proposals.where((p) => p.approved && p.valid).length}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppSizes.fontM,
                            ),
                          ),
                          // Show manufacturer dropdown only if Excel is uploaded
                          if (_sheets.isNotEmpty) ...[
                            const SizedBox(width: AppSizes.paddingL),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.paddingM,
                                vertical: AppSizes.paddingXS,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Default OEM:',
                                    style: TextStyle(
                                      fontSize: AppSizes.fontM,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.paddingS),
                                  DropdownButton<int>(
                                    value: _selectedDefaultManufacturerId,
                                    underline: const SizedBox(),
                                    items: _isProcessing
                                        ? []
                                        : _manufacturers.map((manufacturer) {
                                            return DropdownMenuItem<int>(
                                              value: manufacturer.id,
                                              child: Text(manufacturer.name),
                                            );
                                          }).toList(),
                                    onChanged: _isProcessing
                                        ? null
                                        : (value) async {
                                            if (value != null) {
                                              setState(() {
                                                _selectedDefaultManufacturerId =
                                                    value;
                                              });
                                              // Update all proposals with new default manufacturer
                                              await _updateManufacturerNames();
                                            }
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () {
                                        // Approve all valid proposals but ensure at most one per name
                                        // (case-insensitive). When one proposal for a name is
                                        // approved, other proposals with the same name are left
                                        // unapproved and disabled for selection.
                                        final approvedFor = <String, bool>{};
                                        setState(() {
                                          // reset approvals
                                          for (final p in _proposals) {
                                            p.approved = false;
                                          }
                                          // Approve first valid proposal per name AND per part-number (case-insensitive)
                                          final approvedForPart =
                                              <String, bool>{};
                                          for (final p in _proposals) {
                                            if (!p.valid) continue;
                                            final nameKey = p.name
                                                .toLowerCase();
                                            final partKey =
                                                p.partNumber.trim().isNotEmpty
                                                ? p.partNumber.toLowerCase()
                                                : null;
                                            if (approvedFor[nameKey] == true)
                                              continue;
                                            if (partKey != null &&
                                                approvedForPart[partKey] ==
                                                    true)
                                              continue;
                                            p.approved = true;
                                            approvedFor[nameKey] = true;
                                            if (partKey != null)
                                              approvedForPart[partKey] = true;
                                          }
                                        });
                                      },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text('Approve All (valid only)'),
                              ),
                              const SizedBox(width: AppSizes.paddingM),
                              ElevatedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : _applySelectedProductProposals,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text('Apply Selected'),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSizes.paddingS),

                      // List proposals - take available vertical space and show tabular expandable UI
                      if (_proposals.isEmpty)
                        const Text('No proposals prepared yet.')
                      else
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header row (tabular look)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.paddingM,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSizes.paddingS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                      ), // Leading padding
                                      const SizedBox(
                                        width: 40,
                                      ), // Checkbox space
                                      const SizedBox(
                                        width: 16,
                                      ), // Space between leading and title
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Name (Part#)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'HSN',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Provided Cost',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Provided Sell',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Tax',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Store Cost',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Store Sell',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Excel Mfr',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'DB Mfr',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 16),
                                          child: Text(
                                            'Status',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 16,
                                      ), // Trailing padding
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSizes.paddingXS),
                              Expanded(
                                child: _isProcessing
                                    ? const Center(
                                        child: Text(
                                          'Please wait while analyzing...',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _proposals.length,
                                        // Performance optimizations for large lists
                                        cacheExtent: 1000,
                                        addAutomaticKeepAlives: false,
                                        addRepaintBoundaries: true,
                                        itemBuilder: (context, index) {
                                          final p = _proposals[index];
                                          return RepaintBoundary(
                                            child: Card(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    vertical: AppSizes.paddingS,
                                                  ),
                                              color: AppColors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                side: BorderSide.none,
                                              ),
                                              child: ExpansionTile(
                                                initiallyExpanded: false,
                                                backgroundColor:
                                                    AppColors.white,
                                                collapsedBackgroundColor:
                                                    AppColors.white,
                                                tilePadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal:
                                                          AppSizes.paddingM,
                                                    ),
                                                trailing:
                                                    const SizedBox.shrink(),
                                                leading: Checkbox(
                                                  value: p.approved,
                                                  onChanged: p.valid
                                                      ? (v) {
                                                          setState(() {
                                                            if (v == true) {
                                                              // selecting one variant unselects others with same name
                                                              // or same part-number (case-insensitive)
                                                              for (final other
                                                                  in _proposals) {
                                                                final sameName =
                                                                    other.name
                                                                        .toLowerCase() ==
                                                                    p.name
                                                                        .toLowerCase();
                                                                final bothPartsPresent =
                                                                    other
                                                                        .partNumber
                                                                        .trim()
                                                                        .isNotEmpty &&
                                                                    p.partNumber
                                                                        .trim()
                                                                        .isNotEmpty;
                                                                final samePart =
                                                                    bothPartsPresent &&
                                                                    other.partNumber
                                                                            .toLowerCase() ==
                                                                        p.partNumber
                                                                            .toLowerCase();
                                                                if (sameName ||
                                                                    samePart) {
                                                                  other.approved =
                                                                      false;
                                                                }
                                                              }
                                                              p.approved = true;
                                                            } else {
                                                              p.approved =
                                                                  false;
                                                            }
                                                          });
                                                        }
                                                      : null,
                                                  activeColor:
                                                      AppColors.primary,
                                                  checkColor: AppColors.white,
                                                ),
                                                title: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 2,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '${p.name} (${p.partNumber})',
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          if (!p.valid &&
                                                              p.invalidReason !=
                                                                  null)
                                                            Text(
                                                              p.invalidReason!,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        p.hsnCode,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        p.costPrice > 0
                                                            ? p.costPrice
                                                                  .toStringAsFixed(
                                                                    2,
                                                                  )
                                                            : '',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        p.sellingPrice > 0
                                                            ? p.sellingPrice
                                                                  .toStringAsFixed(
                                                                    2,
                                                                  )
                                                            : '',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        p.includeProvided
                                                            ? (p.includeTax
                                                                  ? 'YES'
                                                                  : 'NO')
                                                            : '',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        p.computedCostExcl > 0
                                                            ? p.computedCostExcl
                                                                  .toStringAsFixed(
                                                                    2,
                                                                  )
                                                            : '',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        p.computedSellingExcl >
                                                                0
                                                            ? p.computedSellingExcl
                                                                  .toStringAsFixed(
                                                                    2,
                                                                  )
                                                            : '',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        p
                                                                .manufacturerNameFromExcel
                                                                .isNotEmpty
                                                            ? p.manufacturerNameFromExcel
                                                            : '-',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        p.plannedManufacturerName ??
                                                            (p.plannedManufacturerId
                                                                    ?.toString() ??
                                                                '-'),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 80,
                                                      child: Text(
                                                        p.valid
                                                            ? (p.existingProductId !=
                                                                      null
                                                                  ? 'Existing'
                                                                  : 'New')
                                                            : 'Invalid',
                                                        style: TextStyle(
                                                          color: p.valid
                                                              ? AppColors
                                                                    .textSecondary
                                                              : Colors.red,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                children: [
                                                  Container(
                                                    color: AppColors.white,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          AppSizes.paddingM,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Wrap(
                                                          spacing:
                                                              AppSizes.paddingM,
                                                          runSpacing: AppSizes
                                                              .paddingXS,
                                                          children: [
                                                            Text(
                                                              'Store Cost (excl): ${p.computedCostExcl.toStringAsFixed(2)}',
                                                              style: TextStyle(
                                                                fontSize:
                                                                    AppSizes
                                                                        .fontM,
                                                                color: AppColors
                                                                    .textPrimary,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Store Sell (excl): ${p.computedSellingExcl.toStringAsFixed(2)}',
                                                              style: TextStyle(
                                                                fontSize:
                                                                    AppSizes
                                                                        .fontM,
                                                                color: AppColors
                                                                    .textPrimary,
                                                              ),
                                                            ),
                                                            if (p.mrp != null)
                                                              Text(
                                                                'MRP: ${p.mrp!.toStringAsFixed(2)}',
                                                                style: TextStyle(
                                                                  fontSize:
                                                                      AppSizes
                                                                          .fontM,
                                                                  color: AppColors
                                                                      .textPrimary,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height:
                                                              AppSizes.paddingS,
                                                        ),
                                                        if (!p.valid &&
                                                            p.invalidReason !=
                                                                null)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  AppSizes
                                                                      .paddingS,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: AppColors
                                                                  .error
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6,
                                                                  ),
                                                              border: Border.all(
                                                                color: AppColors
                                                                    .error
                                                                    .withOpacity(
                                                                      0.3,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              p.invalidReason!,
                                                              style: TextStyle(
                                                                color: AppColors
                                                                    .error,
                                                                fontSize:
                                                                    AppSizes
                                                                        .fontM,
                                                              ),
                                                            ),
                                                          ),
                                                        if (p.suggestion !=
                                                            null)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  top: AppSizes
                                                                      .paddingS,
                                                                ),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    AppSizes
                                                                        .paddingS,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: AppColors
                                                                    .info
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                p.suggestion!,
                                                                style: TextStyle(
                                                                  color: AppColors
                                                                      .textSecondary,
                                                                  fontSize:
                                                                      AppSizes
                                                                          .fontM,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        const SizedBox(
                                                          height:
                                                              AppSizes.paddingM,
                                                        ),
                                                        Divider(
                                                          color:
                                                              AppColors.border,
                                                        ),
                                                        const SizedBox(
                                                          height:
                                                              AppSizes.paddingS,
                                                        ),
                                                        Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            // Planned DB values - Left side
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'Planned DB values',
                                                                    style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          AppSizes
                                                                              .fontL,
                                                                      color: AppColors
                                                                          .textPrimary,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: AppSizes
                                                                        .paddingS,
                                                                  ),
                                                                  Container(
                                                                    padding: const EdgeInsets.all(
                                                                      AppSizes
                                                                          .paddingM,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: AppColors
                                                                          .backgroundSecondary,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            6,
                                                                          ),
                                                                    ),
                                                                    child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          'Sub-category: ${p.plannedSubCategoryName ?? p.plannedSubCategoryId}',
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                AppSizes.fontM,
                                                                            color:
                                                                                AppColors.textPrimary,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              AppSizes.paddingXS,
                                                                        ),
                                                                        Text(
                                                                          'Manufacturer: ${p.plannedManufacturerName ?? p.plannedManufacturerId}',
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                AppSizes.fontM,
                                                                            color:
                                                                                AppColors.textPrimary,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              AppSizes.paddingXS,
                                                                        ),
                                                                        Text(
                                                                          'UQC Code: ${p.plannedUqcName ?? p.plannedUqcId}',
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                AppSizes.fontM,
                                                                            color:
                                                                                AppColors.textPrimary,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              AppSizes.paddingXS,
                                                                        ),
                                                                        if (p.mrp !=
                                                                            null)
                                                                          Text(
                                                                            'MRP: ${p.mrp!.toStringAsFixed(2)}',
                                                                            style: TextStyle(
                                                                              fontSize: AppSizes.fontM,
                                                                              color: AppColors.textPrimary,
                                                                            ),
                                                                          ),
                                                                        if (p.mrp !=
                                                                            null)
                                                                          const SizedBox(
                                                                            height:
                                                                                AppSizes.paddingXS,
                                                                          ),
                                                                        Text(
                                                                          'isTaxable: ${p.plannedIsTaxable}  isEnabled: ${p.plannedIsEnabled}  negativeAllow: ${p.plannedNegativeAllow}',
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                AppSizes.fontM,
                                                                            color:
                                                                                AppColors.textPrimary,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            // Spacing between columns
                                                            if (p.existingData !=
                                                                null)
                                                              const SizedBox(
                                                                width: AppSizes
                                                                    .paddingM,
                                                              ),
                                                            // Existing product data - Right side
                                                            if (p.existingData !=
                                                                null)
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      'Existing product data (DB)',
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        fontSize:
                                                                            AppSizes.fontL,
                                                                        color: AppColors
                                                                            .textPrimary,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: AppSizes
                                                                          .paddingS,
                                                                    ),
                                                                    Container(
                                                                      padding: const EdgeInsets.all(
                                                                        AppSizes
                                                                            .paddingM,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: AppColors
                                                                            .backgroundTertiary,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              6,
                                                                            ),
                                                                      ),
                                                                      child: Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          for (final entry
                                                                              in p.existingData!.entries)
                                                                            if (entry.key !=
                                                                                'uqc_id')
                                                                              Padding(
                                                                                padding: const EdgeInsets.only(
                                                                                  bottom: AppSizes.paddingXS,
                                                                                ),
                                                                                child: Text(
                                                                                  '${entry.key}: ${entry.value}',
                                                                                  style: TextStyle(
                                                                                    fontSize: AppSizes.fontM,
                                                                                    color: AppColors.textPrimary,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                          if (p.existingUqcCode !=
                                                                              null)
                                                                            Padding(
                                                                              padding: const EdgeInsets.only(
                                                                                bottom: AppSizes.paddingXS,
                                                                              ),
                                                                              child: Text(
                                                                                'uqc_code: ${p.existingUqcCode}',
                                                                                style: TextStyle(
                                                                                  fontSize: AppSizes.fontM,
                                                                                  color: AppColors.textPrimary,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                        ],
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
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
