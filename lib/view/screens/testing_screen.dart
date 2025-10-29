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
  String? description;
  double cgst;
  double sgst;
  double igst;
  double utgst;
  DateTime? effectiveFrom; // nullable - user may omit

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
    this.effectiveFrom,
  });

  DateTime get effectiveFromOrToday => effectiveFrom ?? DateTime.now();
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
    for (var rowIndex = 0; rowIndex < first.length; rowIndex++) {
      final row = first[rowIndex];
      // skip header row if it looks like one (contains hsn/hsn code/cgst/sgst/etc)
      if (rowIndex == 0 && row.isNotEmpty) {
        final joined = row.join(' ').toLowerCase();
        if (joined.contains('hsn') ||
            joined.contains('hsn code') ||
            joined.contains('cgst') ||
            joined.contains('sgst') ||
            joined.contains('igst') ||
            joined.contains('utgst') ||
            joined.contains('effective')) {
          continue;
        }
      }
      // Expect at least 7 columns per spec, but be defensive
      if (row.isEmpty) continue;
      final hsn = row.isNotEmpty ? row[0].trim() : '';
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
      // allow missing effectiveFrom (user may choose to update active rate)
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
          // validate no overlap only when effectiveFrom is provided
          if (p.effectiveFrom != null) {
            final newFrom = p.effectiveFrom!;
            for (final r in rates) {
              final from = DateTime.parse(r['effective_from'] as String);
              final to = r['effective_to'] != null
                  ? DateTime.parse(r['effective_to'] as String)
                  : null;
              if (to == null) {
                // existing active interval [from .. NULL]
                // allow newFrom only if strictly after 'from' (we will close the active to newFrom - 1)
                if (newFrom.isAtSameMomentAs(from) || newFrom.isBefore(from)) {
                  p.valid = false;
                  p.invalidReason =
                      'Effective date ${newFrom.toIso8601String().split('T')[0]} conflicts with active DB rate starting ${from.toIso8601String().split('T')[0]}';
                  break;
                }
              } else {
                // closed interval [from .. to] - newFrom must not fall inside this interval (inclusive)
                if (!newFrom.isBefore(from) && !newFrom.isAfter(to)) {
                  p.valid = false;
                  p.invalidReason =
                      'Effective date ${newFrom.toIso8601String().split('T')[0]} falls inside existing DB interval ${from.toIso8601String().split('T')[0]} - ${to.toIso8601String().split('T')[0]} (id=${r['id']})';
                  break;
                }
              }
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
    // Cross-proposal validation: detect conflicts within the imported set
    // Group proposals by HSN (case-insensitive)
    final Map<String, List<_Proposal>> byHsn = {};
    for (final p in _proposals) {
      final key = p.hsnCode.toLowerCase();
      byHsn.putIfAbsent(key, () => []).add(p);
    }

    for (final entry in byHsn.entries) {
      final List<_Proposal> group = entry.value;
      // Collect DB intervals from any proposal (they were populated earlier)
      final List<Map<String, dynamic>> dbIntervals = [];
      for (final p in group) {
        if (p.existingRates.isNotEmpty) {
          dbIntervals.addAll(p.existingRates);
        }
      }

      // If group contains both dated and undated proposals, mark undated as conflicting
      final dated = group.where((p) => p.effectiveFrom != null).toList();
      final undated = group.where((p) => p.effectiveFrom == null).toList();
      if (dated.isNotEmpty && undated.isNotEmpty) {
        for (final p in undated) {
          p.valid = false;
          p.invalidReason =
              'Conflicts with dated proposals for same HSN in this import. Provide effective_from or remove the dated rows.';
        }
      }

      // Validate dated proposals vs DB intervals
      if (dated.isNotEmpty) {
        // sort by effectiveFrom ascending
        dated.sort((a, b) => a.effectiveFrom!.compareTo(b.effectiveFrom!));
        // check duplicates and overlaps within proposals
        for (var i = 0; i < dated.length; i++) {
          final p = dated[i];
          p.valid = p
              .valid; // keep previous DB-based validity unless we find a new problem
          p.invalidReason = p.invalidReason;

          // duplicate effective_from within import
          for (var j = 0; j < dated.length; j++) {
            if (i == j) continue;
            final other = dated[j];
            if (p.effectiveFrom!.isAtSameMomentAs(other.effectiveFrom!)) {
              p.valid = false;
              p.invalidReason =
                  'Duplicate effective_from ${p.effectiveFrom!.toIso8601String().split('T')[0]} in import for same HSN';
              break;
            }
          }
          if (!p.valid) continue;

          // Check against DB intervals
          for (final r in dbIntervals) {
            try {
              final from = DateTime.parse(r['effective_from'] as String);
              final to = r['effective_to'] != null
                  ? DateTime.parse(r['effective_to'] as String)
                  : null;
              final newFrom = p.effectiveFrom!;

              if (to == null) {
                // existing active interval [from .. NULL]
                // allow newFrom only if strictly after 'from' (it will close the active)
                if (newFrom.isAtSameMomentAs(from) || newFrom.isBefore(from)) {
                  p.valid = false;
                  p.invalidReason =
                      'Effective_from ${newFrom.toIso8601String().split('T')[0]} conflicts with active DB rate starting ${from.toIso8601String().split('T')[0]}';
                  break;
                }
              } else {
                // closed interval [from .. to]
                if (!newFrom.isBefore(from) && !newFrom.isAfter(to)) {
                  // newFrom is within [from..to]
                  p.valid = false;
                  p.invalidReason =
                      'Effective_from ${newFrom.toIso8601String().split('T')[0]} falls inside existing DB interval ${from.toIso8601String().split('T')[0]} - ${to.toIso8601String().split('T')[0]} (id=${r['id']})';
                  break;
                }
              }
            } catch (e) {
              // parsing error - mark invalid
              p.valid = false;
              p.invalidReason = 'Invalid date in DB interval: $e';
              break;
            }
          }
        }
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

          // Apply using a unified approach: if proposal has no effectiveFrom, use today's date.
          // This treats missing effectiveFrom as a dated change starting today rather than an in-place update.
          final appliedFrom = p.effectiveFrom ?? DateTime.now();

          // Find existing active rate (if any)
          final active = await txn.rawQuery(
            'SELECT * FROM gst_rates WHERE hsn_code_id = ? AND is_deleted = 0 AND effective_to IS NULL ORDER BY effective_from DESC LIMIT 1',
            [hsnId],
          );

          if (active.isNotEmpty) {
            final r = active.first;
            final from = DateTime.parse(r['effective_from'] as String);

            if (appliedFrom.isAtSameMomentAs(from)) {
              // Same start date as active — update the active row in-place
              await txn.rawUpdate(
                'UPDATE gst_rates SET cgst = ?, sgst = ?, igst = ?, utgst = ?, updated_at = datetime(\'now\') WHERE id = ?',
                [p.cgst, p.sgst, p.igst, p.utgst, r['id']],
              );
            } else if (appliedFrom.isAfter(from)) {
              // Close the active to (appliedFrom - 1) and insert a new dated rate starting appliedFrom
              final newTo = appliedFrom.subtract(const Duration(days: 1));
              await txn.rawUpdate(
                'UPDATE gst_rates SET effective_to = ?, updated_at = datetime(\'now\') WHERE id = ?',
                [newTo.toIso8601String().split('T')[0], r['id']],
              );

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
                  appliedFrom.toIso8601String().split('T')[0],
                  null,
                ],
              );
            } else {
              // appliedFrom is before existing active start — this should have been caught in validation.
              // Fail the transaction to avoid creating inconsistent data.
              throw Exception(
                'Applied effective_from ${appliedFrom.toIso8601String().split('T')[0]} is before existing active rate start ${from.toIso8601String().split('T')[0]} for HSN ${p.hsnCode}',
              );
            }
          } else {
            // No active rate exists — insert new dated rate starting appliedFrom (today if none provided)
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
                appliedFrom.toIso8601String().split('T')[0],
                null,
              ],
            );
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Applied selected proposals')),
        );
        // Refresh proposals and sheets
        await _prepareProposalsFromLoaded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply changes: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // proposals area will expand to fill available space
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
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
                        _proposals.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingL),
            // Sheet preview removed — we only show proposals below. The uploaded file is parsed into proposals.
            const SizedBox.shrink(),
            const SizedBox(height: AppSizes.paddingL),
            if (_proposals.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: Card(
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
                                        if (p.valid) p.approved = true;
                                      }
                                    });
                                  },
                                  child: const Text('Approve All (valid only)'),
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
                        // Bounded proposals area to avoid unbounded height errors in nested Columns
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: SingleChildScrollView(
                            child: Column(
                              children: _proposals.map((p) {
                                // helper to render simple diff row
                                Widget diffRow(
                                  String label,
                                  String oldVal,
                                  String newVal,
                                ) {
                                  final changed = oldVal != newVal;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2.0,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            oldVal,
                                            style: TextStyle(
                                              color: changed
                                                  ? Colors.red
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Icon(Icons.arrow_right_alt),
                                        ),
                                        Expanded(
                                          child: Text(
                                            newVal,
                                            style: TextStyle(
                                              color: changed
                                                  ? Colors.green
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Card(
                                  margin: const EdgeInsets.only(
                                    bottom: AppSizes.paddingS,
                                  ),
                                  child: ExpansionTile(
                                    initiallyExpanded: false,
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
                                      '${p.hsnCode} → ${p.effectiveFrom != null ? p.effectiveFrom!.toIso8601String().split('T')[0] : '(none)'}',
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (p.existingHsnId == null)
                                          Text('HSN will be created'),
                                        if (p.existingHsnId != null)
                                          Text(
                                            'HSN exists (id=${p.existingHsnId})',
                                          ),
                                        if (!p.valid && p.invalidReason != null)
                                          Text(
                                            'Invalid: ${p.invalidReason}',
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                      ],
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(
                                          AppSizes.paddingM,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Wrap(
                                              spacing: AppSizes.paddingM,
                                              runSpacing: AppSizes.paddingS,
                                              children: [
                                                // Read-only display of values (no editing allowed in import flow)
                                                Wrap(
                                                  spacing: AppSizes.paddingM,
                                                  runSpacing: AppSizes.paddingS,
                                                  children: [
                                                    SizedBox(
                                                      width: 140,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'CGST',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          Text('${p.cgst}'),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 140,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'SGST',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          Text('${p.sgst}'),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 140,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'IGST',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          Text('${p.igst}'),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 140,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'UTGST',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          Text('${p.utgst}'),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 220,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Effective From',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          Text(
                                                            p.effectiveFrom !=
                                                                    null
                                                                ? p.effectiveFrom!
                                                                      .toIso8601String()
                                                                      .split(
                                                                        'T',
                                                                      )[0]
                                                                : '(none)',
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                              height: AppSizes.paddingM,
                                            ),
                                            if (p.existingRates.isNotEmpty) ...[
                                              const Text(
                                                'Existing GST rates',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: AppSizes.paddingS,
                                              ),
                                              SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: DataTable(
                                                  columns: const [
                                                    DataColumn(
                                                      label: Text('id'),
                                                    ),
                                                    DataColumn(
                                                      label: Text('cgst'),
                                                    ),
                                                    DataColumn(
                                                      label: Text('sgst'),
                                                    ),
                                                    DataColumn(
                                                      label: Text('igst'),
                                                    ),
                                                    DataColumn(
                                                      label: Text('utgst'),
                                                    ),
                                                    DataColumn(
                                                      label: Text('from'),
                                                    ),
                                                    DataColumn(
                                                      label: Text('to'),
                                                    ),
                                                  ],
                                                  rows: p.existingRates.map((
                                                    r,
                                                  ) {
                                                    String formatDate(
                                                      dynamic d,
                                                    ) {
                                                      if (d == null) return '-';
                                                      try {
                                                        final dt =
                                                            DateTime.parse(
                                                              d.toString(),
                                                            );
                                                        return dt
                                                            .toIso8601String()
                                                            .split('T')[0];
                                                      } catch (_) {
                                                        return d.toString();
                                                      }
                                                    }

                                                    return DataRow(
                                                      cells: [
                                                        DataCell(
                                                          Text('${r['id']}'),
                                                        ),
                                                        DataCell(
                                                          Text('${r['cgst']}'),
                                                        ),
                                                        DataCell(
                                                          Text('${r['sgst']}'),
                                                        ),
                                                        DataCell(
                                                          Text('${r['igst']}'),
                                                        ),
                                                        DataCell(
                                                          Text('${r['utgst']}'),
                                                        ),
                                                        DataCell(
                                                          Text(
                                                            formatDate(
                                                              r['effective_from'],
                                                            ),
                                                          ),
                                                        ),
                                                        DataCell(
                                                          Text(
                                                            r['effective_to'] !=
                                                                    null
                                                                ? formatDate(
                                                                    r['effective_to'],
                                                                  )
                                                                : '-',
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                              const SizedBox(
                                                height: AppSizes.paddingM,
                                              ),
                                            ],
                                            const Text(
                                              'Proposed diff',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: AppSizes.paddingS,
                                            ),
                                            // Show high-level action: whether this will create a new entry or update an existing one
                                            (() {
                                              String oldAction = '-';
                                              String newAction = '-';
                                              // existing HSN present?
                                              if (p.existingHsnId == null) {
                                                // no existing HSN
                                                oldAction = '-';
                                                if (p.effectiveFrom == null) {
                                                  newAction =
                                                      'Create new active rate (effective today)';
                                                } else {
                                                  newAction =
                                                      'Create new dated rate starting ${p.effectiveFrom!.toIso8601String().split('T')[0]}';
                                                }
                                              } else {
                                                // existing HSN
                                                // find active rate
                                                Map<String, dynamic>? active;
                                                for (final r
                                                    in p.existingRates) {
                                                  if (r['effective_to'] ==
                                                      null) {
                                                    active = r;
                                                    break;
                                                  }
                                                }
                                                if (p.effectiveFrom == null) {
                                                  if (active != null) {
                                                    oldAction =
                                                        'Active rate present';
                                                    newAction =
                                                        'Update existing active rate with new values';
                                                  } else {
                                                    oldAction = '-';
                                                    newAction =
                                                        'Create new active rate (no active present)';
                                                  }
                                                } else {
                                                  // dated proposal
                                                  final newFrom = p
                                                      .effectiveFrom!
                                                      .toIso8601String()
                                                      .split('T')[0];
                                                  if (active != null) {
                                                    try {
                                                      final afrom = DateTime.parse(
                                                        active['effective_from']
                                                            as String,
                                                      );
                                                      if (p.effectiveFrom!
                                                          .isAfter(afrom)) {
                                                        oldAction =
                                                            '${afrom.toIso8601String().split('T')[0]} - NULL';
                                                        final newTo = p
                                                            .effectiveFrom!
                                                            .subtract(
                                                              const Duration(
                                                                days: 1,
                                                              ),
                                                            );
                                                        newAction =
                                                            'Close active to ${newTo.toIso8601String().split('T')[0]} and insert new dated rate starting $newFrom';
                                                      } else {
                                                        oldAction =
                                                            'Active rate present';
                                                        newAction =
                                                            'Insert dated rate starting $newFrom (may conflict)';
                                                      }
                                                    } catch (_) {
                                                      oldAction =
                                                          'Active rate present';
                                                      newAction =
                                                          'Insert dated rate starting $newFrom';
                                                    }
                                                  } else {
                                                    oldAction = '-';
                                                    newAction =
                                                        'Insert dated rate starting $newFrom';
                                                  }
                                                }
                                              }
                                              return diffRow(
                                                'Action',
                                                oldAction,
                                                newAction,
                                              );
                                            })(),
                                            diffRow(
                                              'CGST',
                                              p.existingRates.isNotEmpty
                                                  ? '${p.existingRates.last['cgst']}'
                                                  : '-',
                                              '${p.cgst}',
                                            ),
                                            diffRow(
                                              'SGST',
                                              p.existingRates.isNotEmpty
                                                  ? '${p.existingRates.last['sgst']}'
                                                  : '-',
                                              '${p.sgst}',
                                            ),
                                            diffRow(
                                              'IGST',
                                              p.existingRates.isNotEmpty
                                                  ? '${p.existingRates.last['igst']}'
                                                  : '-',
                                              '${p.igst}',
                                            ),
                                            diffRow(
                                              'UTGST',
                                              p.existingRates.isNotEmpty
                                                  ? '${p.existingRates.last['utgst']}'
                                                  : '-',
                                              '${p.utgst}',
                                            ),
                                            diffRow(
                                              'Effective From',
                                              p.existingRates.isNotEmpty
                                                  ? (p
                                                            .existingRates
                                                            .last['effective_from'] ??
                                                        '-')
                                                  : '-',
                                              p.effectiveFrom != null
                                                  ? p.effectiveFrom!
                                                        .toIso8601String()
                                                        .split('T')[0]
                                                  : '(none)',
                                            ),
                                            // If there's an existing active rate and the proposal supplies a later effectiveFrom,
                                            // show the planned closure of the active rate to newFrom - 1 day and the new insertion date.
                                            if (p.effectiveFrom != null &&
                                                p.existingRates.isNotEmpty) ...[
                                              (() {
                                                Map<String, dynamic>? active;
                                                for (final r
                                                    in p.existingRates) {
                                                  if (r['effective_to'] ==
                                                      null) {
                                                    active = r;
                                                    break;
                                                  }
                                                }
                                                if (active != null) {
                                                  try {
                                                    final afrom = DateTime.parse(
                                                      active['effective_from']
                                                          as String,
                                                    );
                                                    if (p.effectiveFrom!
                                                        .isAfter(afrom)) {
                                                      final newTo = p
                                                          .effectiveFrom!
                                                          .subtract(
                                                            const Duration(
                                                              days: 1,
                                                            ),
                                                          );
                                                      return Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          const SizedBox(
                                                            height: AppSizes
                                                                .paddingS,
                                                          ),
                                                          diffRow(
                                                            'Existing active will be',
                                                            '${afrom.toIso8601String().split('T')[0]} - NULL',
                                                            '${afrom.toIso8601String().split('T')[0]} - ${newTo.toIso8601String().split('T')[0]}',
                                                          ),
                                                          diffRow(
                                                            'New rate will start',
                                                            '-',
                                                            p.effectiveFrom!
                                                                .toIso8601String()
                                                                .split('T')[0],
                                                          ),
                                                        ],
                                                      );
                                                    }
                                                  } catch (_) {
                                                    // ignore parse issues here
                                                  }
                                                }
                                                return const SizedBox.shrink();
                                              })(),
                                            ],
                                            const SizedBox(
                                              height: AppSizes.paddingM,
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton(
                                                  onPressed: p.valid
                                                      ? () {
                                                          setState(() {
                                                            p.approved =
                                                                !p.approved;
                                                          });
                                                        }
                                                      : null,
                                                  child: Text(
                                                    p.approved
                                                        ? 'Unselect'
                                                        : 'Select',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
