import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/providers/database_provider.dart';

// Represents a single row parsed from Excel and the proposed DB actions
class _Proposal {
  final String hsnCode;
  final String? description;
  final double cgst;
  final double sgst;
  final double igst;
  final double utgst;
  final DateTime effectiveFrom;

  // populated during analysis
  int? existingHsnId;
  List<Map<String, dynamic>> existingRates = [];
  bool valid = true;
  String? invalidReason;

  bool approved = false;

  _Proposal({
    required this.hsnCode,
    this.description,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.utgst,
    required this.effectiveFrom,
  });
}

class TestingScreen extends ConsumerStatefulWidget {
  const TestingScreen({super.key});

  @override
  ConsumerState<TestingScreen> createState() => _TestingScreenState();
}

class _TestingScreenState extends ConsumerState<TestingScreen> {
  // Map of sheetName -> rows (each row is List<String>)
  final Map<String, List<List<String>>> _sheets = {};
  String? _fileName;

  Future<void> _pickAndLoadExcel() async {
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
      // After loading raw sheets, prepare proposals from first sheet rows
      await _prepareProposalsFromLoaded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read Excel file: $e')),
        );
      }
    }
  }

  // Represents a single row parsed from Excel and the proposed DB actions

  final List<_Proposal> _proposals = [];

  Future<void> _prepareProposalsFromLoaded() async {
    _proposals.clear();
    // Read rows from first sheet if available
    if (_sheets.isEmpty) return;
    final first = _sheets.entries.first.value;
    for (final row in first) {
      // Expect at least 7 columns per spec, but be defensive
      if (row.isEmpty) continue;
      final hsn = row.length > 0 ? row[0].trim() : '';
      if (hsn.isEmpty) continue;
      final desc = row.length > 1 ? row[1] : null;
      double parseDouble(dynamic v) {
        if (v == null || v.toString().trim().isEmpty) return 0.0;
        return double.tryParse(v.toString()) ?? 0.0;
      }

      final cgst = parseDouble(row.length > 2 ? row[2] : null);
      final sgst = parseDouble(row.length > 3 ? row[3] : null);
      final igst = parseDouble(row.length > 4 ? row[4] : null);
      final utgst = parseDouble(row.length > 5 ? row[5] : null);
      DateTime? parseDate(dynamic v) {
        if (v == null) return null;
        try {
          final s = v.toString().trim();
          // Try common formats: yyyy-MM-dd or dd/MM/yyyy
          if (RegExp(r"^\d{4}-\d{2}-\d{2}").hasMatch(s)) {
            return DateTime.parse(s);
          }
          if (RegExp(r"^\d{2}/\d{2}/\d{4}").hasMatch(s)) {
            final parts = s.split('/');
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
          // Try parse fallback
          return DateTime.parse(s);
        } catch (_) {
          return null;
        }
      }

      final eff = parseDate(row.length > 6 ? row[6] : null);
      if (eff == null) continue; // skip rows without valid date
      _proposals.add(
        _Proposal(
          hsnCode: hsn,
          description: desc,
          cgst: cgst,
          sgst: sgst,
          igst: igst,
          utgst: utgst,
          effectiveFrom: eff,
        ),
      );
    }

    // Analyze each proposal against DB
    final db = await ref.read(databaseProvider);
    for (final p in _proposals) {
      try {
        final hsnRows = await db.rawQuery(
          'SELECT * FROM hsn_codes WHERE LOWER(code)=LOWER(?) AND is_deleted = 0 LIMIT 1',
          [p.hsnCode],
        );
        if (hsnRows.isNotEmpty) {
          p.existingHsnId = hsnRows.first['id'] as int;
          // load existing gst rates for this hsn
          final rates = await db.rawQuery(
            'SELECT * FROM gst_rates WHERE hsn_code_id = ? AND is_deleted = 0 ORDER BY effective_from',
            [p.existingHsnId],
          );
          p.existingRates = rates;
          // validate no overlap: new effectiveFrom must not fall within any existing effective_from..effective_to (inclusive)
          for (final r in rates) {
            final from = DateTime.parse(r['effective_from'] as String);
            final to = r['effective_to'] != null
                ? DateTime.parse(r['effective_to'] as String)
                : null;
            if ((p.effectiveFrom.isAtSameMomentAs(from) ||
                    p.effectiveFrom.isAfter(from)) &&
                (to == null ||
                    p.effectiveFrom.isBefore(to) ||
                    p.effectiveFrom.isAtSameMomentAs(to))) {
              p.valid = false;
              p.invalidReason =
                  'Effective date overlaps existing rate ${r['id']} (${r['effective_from']}${to != null ? ' - ${r['effective_to']}' : ' - NULL'})';
              break;
            }
          }
        } else {
          p.existingHsnId = null;
        }
      } catch (e) {
        p.valid = false;
        p.invalidReason = 'DB error: $e';
      }
    }

    setState(() {});
  }

  Future<void> _applySelectedProposals() async {
    final toApply = _proposals.where((p) => p.approved && p.valid).toList();
    if (toApply.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No proposals selected or valid')),
      );
      return;
    }

    final db = await ref.read(databaseProvider);
    try {
      await db.transaction((txn) async {
        for (final p in toApply) {
          int hsnId;
          if (p.existingHsnId == null) {
            // create hsn
            hsnId = await txn.rawInsert(
              """
              INSERT INTO hsn_codes (code, description, is_enabled, is_deleted, created_at, updated_at)
              VALUES (?, ?, 1, 0, datetime('now'), datetime('now'))
            """,
              [p.hsnCode, p.description],
            );
          } else {
            hsnId = p.existingHsnId!;
            // Optionally update description if different
            if (p.description != null) {
              await txn.rawUpdate(
                'UPDATE hsn_codes SET description = ?, updated_at = datetime(\'now\') WHERE id = ?',
                [p.description, hsnId],
              );
            }
          }

          // Find any existing rate that needs closing: the one with effective_to IS NULL or effective_to >= newFrom
          final existingRates = await txn.rawQuery(
            'SELECT * FROM gst_rates WHERE hsn_code_id = ? AND is_deleted = 0 ORDER BY effective_from',
            [hsnId],
          );
          // If there is a rate where effective_from <= newFrom <= (effective_to or NULL) it's invalid; we validated earlier
          // Find the rate with effective_to IS NULL (active) and set its effective_to to newFrom - 1 day if exists and its effective_from < newFrom
          for (final r in existingRates) {
            final int id = r['id'] as int;
            final from = DateTime.parse(r['effective_from'] as String);
            final to = r['effective_to'] != null
                ? DateTime.parse(r['effective_to'] as String)
                : null;
            if (to == null && from.isBefore(p.effectiveFrom)) {
              final newTo = p.effectiveFrom.subtract(const Duration(days: 1));
              await txn.rawUpdate(
                'UPDATE gst_rates SET effective_to = ?, updated_at = datetime(\'now\') WHERE id = ?',
                [newTo.toIso8601String().split('T')[0], id],
              );
              break;
            }
            if (to != null &&
                to.isAfter(p.effectiveFrom.subtract(const Duration(days: 1))) &&
                from.isBefore(p.effectiveFrom)) {
              // overlapping handled earlier - should not happen
            }
          }

          // Insert new gst_rate
          await txn.rawInsert(
            '''
            INSERT INTO gst_rates (hsn_code_id, cgst, sgst, igst, utgst, effective_from, effective_to, is_enabled, is_deleted, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, datetime('now'), datetime('now'))
          ''',
            [
              hsnId,
              p.cgst,
              p.sgst,
              p.igst,
              p.utgst,
              p.effectiveFrom.toIso8601String().split('T')[0],
              null,
            ],
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applied selected proposals')),
      );
      // Refresh proposals and sheets
      await _prepareProposalsFromLoaded();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to apply changes: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Testing',
                style: TextStyle(
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.paddingS),
              Text(
                _fileName == null
                    ? 'Upload an .xlsx file to display its contents'
                    : 'Showing: $_fileName',
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAndLoadExcel,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload .xlsx'),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  if (_sheets.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _sheets.clear();
                          _fileName = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingL),
              Expanded(
                child: _sheets.isEmpty
                    ? Center(
                        child: Text(
                          'No data loaded',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView(
                        children: _sheets.entries.map((entry) {
                          final sheetName = entry.key;
                          final rows = entry.value;
                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: AppSizes.paddingM,
                            ),
                            child: ExpansionTile(
                              title: Text(sheetName),
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Builder(
                                    builder: (context) {
                                      // Determine maximum number of columns across all rows
                                      final maxCols = rows.fold<int>(
                                        0,
                                        (prev, row) => row.length > prev
                                            ? row.length
                                            : prev,
                                      );
                                      final cols = maxCols > 0 ? maxCols : 1;

                                      final columnWidgets =
                                          List<DataColumn>.generate(
                                            cols,
                                            (i) => DataColumn(
                                              label: Text('C${i + 1}'),
                                            ),
                                          );

                                      if (columnWidgets.isEmpty) {
                                        // Defensive fallback: show a placeholder instead of an empty DataTable
                                        return Container(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            'No columns available to display',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        );
                                      }

                                      final dataRows = rows.map((r) {
                                        // Pad missing cells with empty strings so every row has `cols` cells
                                        return DataRow(
                                          cells: List<DataCell>.generate(cols, (
                                            i,
                                          ) {
                                            final value = i < r.length
                                                ? r[i]
                                                : '';
                                            return DataCell(Text(value));
                                          }),
                                        );
                                      }).toList();

                                      return DataTable(
                                        columns: columnWidgets,
                                        rows: dataRows,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              if (_proposals.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Proposed changes (${_proposals.length})',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      for (final p in _proposals) {
                                        p.approved = true;
                                      }
                                    });
                                  },
                                  child: const Text('Approve All'),
                                ),
                                const SizedBox(width: AppSizes.paddingS),
                                ElevatedButton(
                                  onPressed: _applySelectedProposals,
                                  child: const Text('Apply Selected'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.paddingM),
                        ..._proposals.map((p) {
                          return ListTile(
                            leading: Checkbox(
                              value: p.approved,
                              onChanged: p.valid
                                  ? (v) {
                                      setState(() {
                                        p.approved = v ?? false;
                                      });
                                    }
                                  : null,
                            ),
                            title: Text(
                              '${p.hsnCode} → ${p.effectiveFrom.toIso8601String().split('T')[0]}',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (p.existingHsnId == null)
                                  Text('HSN will be created'),
                                if (p.existingHsnId != null)
                                  Text('HSN exists (id=${p.existingHsnId})'),
                                Text(
                                  'Rates: CGST ${p.cgst}, SGST ${p.sgst}, IGST ${p.igst}, UTGST ${p.utgst}',
                                ),
                                if (!p.valid && p.invalidReason != null)
                                  Text(
                                    'Invalid: ${p.invalidReason}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
