import 'package:flutter/material.dart';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/providers/database_provider.dart';

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
  final bool includeTax; // whether provided prices include tax (YES/NO column)

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
    required this.includeTax,
  });
}

class _ProductUploadScreenState extends ConsumerState<ProductUploadScreen> {
  String? _fileName;
  final Map<String, List<List<String>>> _sheets = {};
  final List<_ProductProposal> _proposals = [];

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
      });
      // Prepare proposals for preview
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

    for (var rowIndex = 0; rowIndex < first.length; rowIndex++) {
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
      final includeTax =
          includeProvided &&
          (includeStr.toLowerCase() == 'yes' ||
              includeStr.toLowerCase().startsWith('y'));

      // require name and part_number and hsn
      if (name.isEmpty || part.isEmpty || hsn.isEmpty) {
        // still add but mark invalid
        final p = _ProductProposal(
          name: name,
          partNumber: part,
          hsnCode: hsn,
          costPrice: cost,
          sellingPrice: sell,
          includeTax: includeTax,
        );
        p.valid = false;
        p.invalidReason =
            'Missing required column(s): name, part_number, or hsn_code';
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
          includeTax: includeTax,
        );
        p.valid = false;
        p.invalidReason = 'Missing or invalid cost_price or selling_price';
        _proposals.add(p);
        continue;
      }

      // include_tax is required
      if (!includeStr.isNotEmpty) {
        final p = _ProductProposal(
          name: name,
          partNumber: part,
          hsnCode: hsn,
          costPrice: cost,
          sellingPrice: sell,
          includeTax: includeTax,
        );
        p.valid = false;
        p.invalidReason = 'include_tax column missing';
        _proposals.add(p);
        continue;
      }

      final p = _ProductProposal(
        name: name,
        partNumber: part,
        hsnCode: hsn,
        costPrice: cost,
        sellingPrice: sell,
        includeTax: includeTax,
      );

      // Lookup existing product by part_number
      try {
        final db = await ref.read(databaseProvider);
        final prodRows = await db.rawQuery(
          'SELECT * FROM products WHERE part_number = ? AND is_deleted = 0 LIMIT 1',
          [p.partNumber],
        );
        if (prodRows.isNotEmpty) {
          p.existingProductId = prodRows.first['id'] as int;
          p.existingData = prodRows.first.cast<String, dynamic>();
        }

        // find hsn code id
        final hsnRows = await db.rawQuery(
          'SELECT * FROM hsn_codes WHERE LOWER(code) = LOWER(?) AND is_deleted = 0 LIMIT 1',
          [p.hsnCode],
        );
        if (hsnRows.isNotEmpty) {
          p.hsnCodeId = hsnRows.first['id'] as int;
          // include_tax must be provided when HSN exists
          if (!includeProvided) {
            p.valid = false;
            p.invalidReason = 'include_tax column missing for HSN ${p.hsnCode}';
            _proposals.add(p);
            continue;
          }
          // load active gst rate for this hsn
          final rates = await db.rawQuery(
            'SELECT * FROM gst_rates WHERE hsn_code_id = ? AND is_deleted = 0 ORDER BY effective_from DESC',
            [p.hsnCodeId],
          );
          Map<String, dynamic>? active;
          for (final r in rates) {
            if (r['effective_to'] == null) {
              active = r;
              break;
            }
          }
          if (active == null && rates.isNotEmpty) active = rates.first;

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
          // HSN not present -> mark invalid (user asked show diff and error)
          p.valid = false;
          p.invalidReason = 'HSN code ${p.hsnCode} not found in DB';
        }
        // For display: planned DB values for new inserts or existing values
        const defaultSubCategoryId = 1;
        const defaultManufacturerId = 1;
        const defaultUqcId = 9;
        const defaultIsTaxable = 0;
        const defaultIsEnabled = 1;
        const defaultNegativeAllow = 0;

        if (p.existingData != null) {
          // fill planned display values from existing product row
          p.plannedSubCategoryId =
              (p.existingData!['sub_category_id'] as num?)?.toInt() ??
              defaultSubCategoryId;
          p.plannedManufacturerId =
              (p.existingData!['manufacturer_id'] as num?)?.toInt() ??
              defaultManufacturerId;
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
          p.plannedManufacturerId = defaultManufacturerId;
          p.plannedUqcId = defaultUqcId;
          p.plannedIsTaxable = defaultIsTaxable;
          p.plannedIsEnabled = defaultIsEnabled;
          p.plannedNegativeAllow = defaultNegativeAllow;
        }

        // Try to fetch names for subcategory/manufacturer/uqc (best-effort)
        try {
          if (p.plannedSubCategoryId != null) {
            final rows = await db.rawQuery(
              'SELECT name FROM sub_categories WHERE id = ? LIMIT 1',
              [p.plannedSubCategoryId],
            );
            if (rows.isNotEmpty)
              p.plannedSubCategoryName = rows.first['name']?.toString();
          }
          if (p.plannedManufacturerId != null) {
            final rows = await db.rawQuery(
              'SELECT name FROM manufacturers WHERE id = ? LIMIT 1',
              [p.plannedManufacturerId],
            );
            if (rows.isNotEmpty)
              p.plannedManufacturerName = rows.first['name']?.toString();
          }
          if (p.plannedUqcId != null) {
            final rows = await db.rawQuery(
              'SELECT name FROM uqcs WHERE id = ? LIMIT 1',
              [p.plannedUqcId],
            );
            if (rows.isNotEmpty)
              p.plannedUqcName = rows.first['name']?.toString();
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

    setState(() {});
  }

  Future<void> _applySelectedProductProposals() async {
    final rawToApply = _proposals.where((p) => p.approved && p.valid).toList();
    // Ensure at most one proposal per product name is applied (defensive).
    final Map<String, _ProductProposal> uniqueByName = {};
    for (final p in rawToApply) {
      final key = p.name.toLowerCase();
      if (!uniqueByName.containsKey(key)) uniqueByName[key] = p;
    }
    final toApply = uniqueByName.values.toList();
    if (toApply.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No proposals selected or valid')),
        );
      return;
    }

    final db = await ref.read(databaseProvider);
    try {
      await db.transaction((txn) async {
        for (final p in toApply) {
          // Require HSN to exist (we do not auto-create HSNs during product import)
          if (p.hsnCodeId == null) {
            throw Exception('HSN code missing for product ${p.partNumber}');
          }
          final hsnId = p.hsnCodeId!;

          // Defaults per user instructions
          const defaultSubCategoryId = 1; // assumption: exists
          const defaultManufacturerId = 1; // assumption: exists
          const defaultUqcId = 9; // as requested
          const defaultIsTaxable = 0; // 0
          const defaultIsEnabled = 1;

          final existing = await txn.rawQuery(
            'SELECT * FROM products WHERE part_number = ? AND is_deleted = 0 LIMIT 1',
            [p.partNumber],
          );
          if (existing.isNotEmpty) {
            final id = existing.first['id'] as int;
            await txn.rawUpdate(
              '''
              UPDATE products SET
                name = ?, hsn_code_id = ?, uqc_id = ?, cost_price = ?, selling_price = ?, sub_category_id = ?, manufacturer_id = ?, is_taxable = ?, updated_at = datetime('now')
              WHERE id = ?
              ''',
              [
                p.name,
                hsnId,
                defaultUqcId,
                p.computedCostExcl,
                p.computedSellingExcl,
                defaultSubCategoryId,
                defaultManufacturerId,
                defaultIsTaxable,
                id,
              ],
            );
          } else {
            await txn.rawInsert(
              '''
              INSERT INTO products (name, part_number, hsn_code_id, uqc_id, cost_price, selling_price, sub_category_id, manufacturer_id, is_taxable, is_enabled, negative_allow, is_deleted, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, datetime('now'), datetime('now'))
              ''',
              [
                p.name,
                p.partNumber,
                hsnId,
                defaultUqcId,
                p.computedCostExcl,
                p.computedSellingExcl,
                defaultSubCategoryId,
                defaultManufacturerId,
                defaultIsTaxable,
                defaultIsEnabled,
                0, // negative_allow default false
              ],
            );
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Applied selected product proposals')),
        );
        // refresh proposals
        await _prepareProductProposalsFromLoaded();
      }
    } catch (e) {
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
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Product Upload',
            style: TextStyle(
              fontSize: AppSizes.fontXXL,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            _fileName == null
                ? 'Upload a product .xlsx file to import products'
                : 'Selected: $_fileName',
            style: TextStyle(
              fontSize: AppSizes.fontM,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload .xlsx'),
              ),
              const SizedBox(width: AppSizes.paddingM),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _fileName = null;
                    _sheets.clear();
                  });
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),
          if (_sheets.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Text(
                      'This screen is a placeholder for the Product Upload flow.',
                    ),
                    SizedBox(height: AppSizes.paddingS),
                    Text(
                      'You can upload an .xlsx, preview parsed rows, validate, and apply changes to DB.',
                    ),
                  ],
                ),
              ),
            )
          else
            // Show first sheet content in a scrollable DataTable and proposals
            // Make this card take the remaining available height so the
            // proposals list can expand and scroll as needed.
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Proposals prepared from sheet(s): ${_sheets.keys.join(', ')}',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSizes.paddingS),

                      // Actions for proposals
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
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
                                // Approve first valid proposal per name (case-insensitive)
                                for (final p in _proposals) {
                                  if (!p.valid) continue;
                                  final key = p.name.toLowerCase();
                                  if (approvedFor[key] == true) continue;
                                  p.approved = true;
                                  approvedFor[key] = true;
                                }
                              });
                            },
                            child: const Text('Approve All (valid only)'),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          ElevatedButton(
                            onPressed: _applySelectedProductProposals,
                            child: const Text('Apply Selected'),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Text(
                            'Valid: ${_proposals.where((p) => p.valid).length}  Selected: ${_proposals.where((p) => p.approved && p.valid).length}',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSizes.paddingS),

                      // List proposals - take available vertical space and scroll
                      if (_proposals.isEmpty)
                        const Text('No proposals prepared yet.')
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: _proposals.length,
                            itemBuilder: (context, index) {
                              final p = _proposals[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: AppSizes.paddingS,
                                ),
                                child: ExpansionTile(
                                  initiallyExpanded: false,
                                  leading: Checkbox(
                                    value: p.approved,
                                    onChanged: p.valid
                                        ? (v) {
                                            setState(() {
                                              if (v == true) {
                                                // selecting one variant unselects others with same name
                                                for (final other
                                                    in _proposals) {
                                                  if (other.name
                                                          .toLowerCase() ==
                                                      p.name.toLowerCase()) {
                                                    other.approved = false;
                                                  }
                                                }
                                                p.approved = true;
                                              } else {
                                                p.approved = false;
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${p.name}  (${p.partNumber})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        p.existingProductId != null
                                            ? 'Existing'
                                            : 'New',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'HSN: ${p.hsnCode} • Provided: ${p.costPrice.toStringAsFixed(2)}/${p.sellingPrice.toStringAsFixed(2)} • Included Tax: ${p.includeTax ? 'YES' : 'NO'}',
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(
                                        AppSizes.paddingM,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: AppSizes.paddingM,
                                            children: [
                                              Text(
                                                'Store Cost (excl): ${p.computedCostExcl.toStringAsFixed(2)}',
                                              ),
                                              Text(
                                                'Store Sell (excl): ${p.computedSellingExcl.toStringAsFixed(2)}',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                            height: AppSizes.paddingS,
                                          ),
                                          if (!p.valid &&
                                              p.invalidReason != null)
                                            Text(
                                              p.invalidReason!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          if (p.suggestion != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: AppSizes.paddingS,
                                              ),
                                              child: Text(
                                                p.suggestion!,
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          const Divider(),
                                          Text(
                                            'Planned DB values',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: AppSizes.paddingXS,
                                          ),
                                          Text(
                                            'Sub-category: ${p.plannedSubCategoryName ?? p.plannedSubCategoryId}',
                                          ),
                                          Text(
                                            'Manufacturer: ${p.plannedManufacturerName ?? p.plannedManufacturerId}',
                                          ),
                                          Text(
                                            'UQC: ${p.plannedUqcName ?? p.plannedUqcId}',
                                          ),
                                          Text(
                                            'isTaxable: ${p.plannedIsTaxable}  isEnabled: ${p.plannedIsEnabled}  negativeAllow: ${p.plannedNegativeAllow}',
                                          ),
                                          if (p.existingData != null) ...[
                                            const Divider(),
                                            Text(
                                              'Existing product data (DB)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: AppSizes.paddingXS,
                                            ),
                                            for (final entry
                                                in p.existingData!.entries)
                                              Text(
                                                '${entry.key}: ${entry.value}',
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
