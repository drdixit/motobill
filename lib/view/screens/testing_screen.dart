import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
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
  String? suggestion;

  bool approved = false;
  bool selectable = true; // only one proposal per HSN may be selectable

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

  Future<void> _downloadTemplate() async {
    try {
      // Load the template from assets
      final byteData = await rootBundle.load('assets/hsn_codes.xlsx');
      final bytes = byteData.buffer.asUint8List();

      // Let user pick a save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save HSN Code Template',
        fileName: 'hsn_code_template.xlsx',
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

  // UI date formatting helper: MM/DD/YYYY
  String _formatDateForUi(dynamic d) {
    if (d == null) return '-';
    try {
      DateTime dt;
      if (d is DateTime) {
        dt = d;
      } else {
        dt = DateTime.parse(d.toString());
      }
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return '$mm/$dd/$yyyy';
    } catch (_) {
      return d.toString();
    }
  }

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

      // Validate H1 (column H, row 1) of the first sheet: it MUST contain
      // exactly four space characters ("    "). This is our canonical
      // validation for HSN code import files. If it doesn't match, we
      // reject the file and do not process it further.
      if (excel.tables.isNotEmpty) {
        final firstKey = excel.tables.keys.first;
        final firstTable = excel.tables[firstKey];
        if (firstTable != null && firstTable.rows.isNotEmpty) {
          final firstRow = firstTable.rows.first;
          // Column H is index 7 (0-based). Safely check length.
          String h1Val = '';
          if (firstRow.length > 7 && firstRow[7] != null) {
            final v = firstRow[7]?.value;
            h1Val = v == null ? '' : v.toString();
          }

          // If H1 does NOT contain exactly four spaces, reject the file.
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

      double cgst = parseDouble(row.length > 2 ? row[2] : null);
      double sgst = parseDouble(row.length > 3 ? row[3] : null);
      double igst = parseDouble(row.length > 4 ? row[4] : null);
      final double utgst = parseDouble(row.length > 5 ? row[5] : null);
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
      // If cgst & sgst provided but igst missing, compute igst = cgst + sgst
      // If igst provided but cgst & sgst missing, split igst equally into cgst/sgst
      String? suggestion;
      if ((cgst > 0 || sgst > 0) && igst == 0) {
        // Only compute if both cgst and sgst present (non-zero). If one is zero, prefer provided values.
        if (cgst > 0 && sgst > 0) {
          igst = cgst + sgst;
          suggestion = 'Computed IGST=${igst} as CGST+SGST';
        }
      } else if (igst > 0 && cgst == 0 && sgst == 0) {
        // Split IGST evenly into CGST/SGST
        final half = igst / 2.0;
        cgst = half;
        sgst = half;
        suggestion = 'Computed CGST=${cgst} and SGST=${sgst} as IGST/2';
      }

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
        )..suggestion = suggestion,
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
          // Edge-case check: if user did NOT provide effectiveFrom (null) but the
          // existing active rate starts today, then applying with today's date
          // would be a no-op start-date collision. Disallow such updates — require
          // an explicit effectiveFrom > active start.
          if (p.effectiveFrom == null && p.existingRates.isNotEmpty) {
            for (final r in p.existingRates) {
              if (r['effective_to'] == null) {
                try {
                  final afrom = DateTime.parse(r['effective_from'] as String);
                  final now = DateTime.now();
                  final sameDate =
                      afrom.year == now.year &&
                      afrom.month == now.month &&
                      afrom.day == now.day;
                  if (sameDate &&
                      (p.cgst > 0 || p.sgst > 0 || p.igst > 0 || p.utgst > 0)) {
                    p.valid = false;
                    p.invalidReason =
                        'No effective_from provided; existing active rate starts today (${_formatDateForUi(afrom)}). Provide an explicit effective_from > today to change rates.';
                  }
                } catch (_) {
                  // ignore parse issues
                }
                break;
              }
            }
          }
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
                      'Effective date ${_formatDateForUi(newFrom)} conflicts with active DB rate starting ${_formatDateForUi(from)}';
                  break;
                }
              } else {
                // closed interval [from .. to] - newFrom must not fall inside this interval (inclusive)
                if (!newFrom.isBefore(from) && !newFrom.isAfter(to)) {
                  p.valid = false;
                  p.invalidReason =
                      'Effective date ${_formatDateForUi(newFrom)} falls inside existing DB interval ${_formatDateForUi(from)} - ${_formatDateForUi(to)} (id=${r['id']})';
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

      // Validate percentage ranges for rates (0..100)
      if (p.valid) {
        String? badField;
        if (p.cgst < 0 || p.cgst > 100) badField = 'CGST';
        if (p.sgst < 0 || p.sgst > 100) badField = badField ?? 'SGST';
        if (p.igst < 0 || p.igst > 100) badField = badField ?? 'IGST';
        if (p.utgst < 0 || p.utgst > 100) badField = badField ?? 'UTGST';
        if (badField != null) {
          p.valid = false;
          p.invalidReason = '$badField must be between 0 and 100';
        }

        // Ensure HSN code is present
        if (p.valid) {
          if (p.hsnCode.trim().isEmpty) {
            p.valid = false;
            p.invalidReason = 'HSN code is required';
          }
        }

        // Require either both CGST and SGST (both > 0) or IGST (> 0).
        // This rule applies to newly created HSNs and existing ones.
        if (p.valid) {
          final hasBothCsgst = p.cgst > 0 && p.sgst > 0;
          final hasIgst = p.igst > 0;
          if (!(hasBothCsgst || hasIgst)) {
            p.valid = false;
            p.invalidReason = 'Provide both CGST and SGST, or provide IGST.';
          }
        }
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

      // If group contains both dated and undated proposals, normally we mark
      // undated ones as conflicting to avoid ambiguous ordering. However, when
      // all proposals in the group are for a newly-created HSN (existingHsnId
      // is null), treat undated rows as having priority equivalent to dated
      // ones and allow them (their effectiveFrom will be treated as today).
      final dated = group.where((p) => p.effectiveFrom != null).toList();
      final undated = group.where((p) => p.effectiveFrom == null).toList();
      if (dated.isNotEmpty && undated.isNotEmpty) {
        final hasExistingHsn = group.any((p) => p.existingHsnId != null);
        if (hasExistingHsn) {
          // If any proposal references an existing HSN in DB, keep the old
          // conservative behavior and mark undated rows invalid so the user
          // must provide dates to disambiguate.
          for (final p in undated) {
            p.valid = false;
            p.invalidReason =
                'Conflicts with dated proposals for same HSN in this import. Provide effective_from or remove the dated rows.';
          }
        } else {
          // All proposals are for a new HSN: allow undated rows. For UI and
          // validation purposes they will be treated as if effectiveFrom == today.
          for (final p in undated) {
            // keep p.valid as-is (do not mark invalid)
            p.selectable = true;
          }
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
              // If the group contains any existing HSN (already in DB) then
              // duplicate effective_from within import is ambiguous and should
              // be rejected. However, if all proposals in the group are for a
              // newly-created HSN (existingHsnId == null), allow duplicate
              // dates here — they are treated as same-priority and the UI
              // selection/Apply logic will ensure only one goes to DB.
              final hasExistingHsn = group.any((x) => x.existingHsnId != null);
              if (hasExistingHsn) {
                p.valid = false;
                p.invalidReason =
                    'Duplicate effective_from ${_formatDateForUi(p.effectiveFrom)} in import for same HSN';
                break;
              } else {
                // all new HSNs: allow duplicate dates — keep valid/selectable
                // (do not mark invalid).
                break;
              }
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
                      'Effective_from ${_formatDateForUi(newFrom)} conflicts with active DB rate starting ${_formatDateForUi(from)}';
                  break;
                }
              } else {
                // closed interval [from .. to]
                if (!newFrom.isBefore(from) && !newFrom.isAfter(to)) {
                  // newFrom is within [from..to]
                  p.valid = false;
                  p.invalidReason =
                      'Effective_from ${_formatDateForUi(newFrom)} falls inside existing DB interval ${_formatDateForUi(from)} - ${_formatDateForUi(to)} (id=${r['id']})';
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

      // --- Duplicate resolution: when multiple proposals reference the same HSN
      // we should NOT automatically invalidate other valid proposals. Instead
      // keep all valid proposals selectable and surface the choice to the user.
      // If none of the group are valid, mark them all invalid so the user knows
      // to fix the import.
      final validCandidates = group.where((p) => p.valid).toList();
      if (validCandidates.isEmpty) {
        for (final p in group) {
          p.valid = false;
          p.selectable = false;
          p.invalidReason =
              'Multiple proposals for same HSN in import; none passed validation. Resolve and re-import.';
        }
      } else {
        // Keep all valid candidates selectable and don't auto-disable any.
        for (final p in group) {
          if (p.valid) {
            p.selectable = true;
            // leave p.valid as true and let the user pick which one to approve
          } else {
            // invalid proposals remain non-selectable
            p.selectable = false;
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
                  'Testing',
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
                      onPressed: _pickAndLoadExcel,
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
                        onPressed: () {
                          setState(() {
                            _sheets.clear();
                            _fileName = null;
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
            if (_proposals.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: Card(
                  margin: EdgeInsets.zero,
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
                          children: [
                            Text(
                              'Proposed changes from file: ${_fileName ?? ""} (${_proposals.length})',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      // Approve at most one proposal per HSN. We keep all
                                      // valid proposals selectable but auto-approving must
                                      // not create multiple selected entries for the same
                                      // HSN. This picks the first valid/selectable proposal
                                      // encountered per HSN and clears others.
                                      final chosenHsn = <String>{};
                                      for (final p in _proposals) {
                                        p.approved = false; // clear first
                                      }
                                      for (final p in _proposals) {
                                        final key = p.hsnCode.toLowerCase();
                                        if (p.valid &&
                                            p.selectable &&
                                            !chosenHsn.contains(key)) {
                                          p.approved = true;
                                          chosenHsn.add(key);
                                        }
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
                                      onChanged: (p.valid && p.selectable)
                                          ? (v) {
                                              setState(() {
                                                final newVal = v ?? false;
                                                // enforce single selection per HSN: unapprove others
                                                if (newVal) {
                                                  for (final other
                                                      in _proposals) {
                                                    if (other.hsnCode
                                                                .toLowerCase() ==
                                                            p.hsnCode
                                                                .toLowerCase() &&
                                                        !identical(other, p)) {
                                                      other.approved = false;
                                                    }
                                                  }
                                                }
                                                p.approved = newVal;
                                              });
                                            }
                                          : null,
                                    ),
                                    // First line: compact summary — HSN | prev -> new | existence
                                    title: Builder(
                                      builder: (context) {
                                        // compute previous (active) date if any
                                        String prevDate = '-';
                                        for (final r in p.existingRates) {
                                          if (r['effective_to'] == null) {
                                            try {
                                              final dt = DateTime.parse(
                                                r['effective_from'] as String,
                                              );
                                              prevDate = _formatDateForUi(dt);
                                            } catch (_) {
                                              prevDate =
                                                  r['effective_from']
                                                      ?.toString() ??
                                                  '-';
                                            }
                                            break;
                                          }
                                        }
                                        final newDate = p.effectiveFrom != null
                                            ? _formatDateForUi(p.effectiveFrom)
                                            : '(today)';

                                        return Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                p.hsnCode,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                '$prevDate → $newDate',
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                p.existingHsnId != null
                                                    ? 'Exists (id=${p.existingHsnId})'
                                                    : 'Will be created',
                                                textAlign: TextAlign.right,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    // Second line: show problem (if any) and suggestions
                                    subtitle: (p.valid && p.suggestion == null)
                                        ? null
                                        : Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (!p.valid)
                                                  Text(
                                                    p.invalidReason ??
                                                        'Invalid proposal',
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                if (p.suggestion != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4.0,
                                                        ),
                                                    child: Text(
                                                      p.suggestion!,
                                                      style: TextStyle(
                                                        color: Colors.blue[700],
                                                        fontSize:
                                                            AppSizes.fontS,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
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
                                                            // If the import didn't provide an effectiveFrom
                                                            // then show today's date when this proposal
                                                            // represents a real rate change (new HSN or any rate provided).
                                                            // Otherwise show '(none)'.
                                                            p.effectiveFrom !=
                                                                    null
                                                                ? _formatDateForUi(
                                                                    p.effectiveFrom,
                                                                  )
                                                                : ((p.existingHsnId ==
                                                                              null ||
                                                                          p.cgst >
                                                                              0 ||
                                                                          p.sgst >
                                                                              0 ||
                                                                          p.igst >
                                                                              0 ||
                                                                          p.utgst >
                                                                              0)
                                                                      ? _formatDateForUi(
                                                                          DateTime.now(),
                                                                        )
                                                                      : '(none)'),
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
                                                      return _formatDateForUi(
                                                        d,
                                                      );
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
                                                height: AppSizes.paddingS,
                                              ),
                                            ],
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
                                                  ? _formatDateForUi(
                                                      p
                                                          .existingRates
                                                          .last['effective_from'],
                                                    )
                                                  : '-',
                                              p.effectiveFrom != null
                                                  ? _formatDateForUi(
                                                      p.effectiveFrom,
                                                    )
                                                  : ((p.existingHsnId == null ||
                                                            p.cgst > 0 ||
                                                            p.sgst > 0 ||
                                                            p.igst > 0 ||
                                                            p.utgst > 0)
                                                        ? _formatDateForUi(
                                                            DateTime.now(),
                                                          )
                                                        : '(none)'),
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
                                                            '${_formatDateForUi(afrom)} - NULL',
                                                            '${_formatDateForUi(afrom)} - ${_formatDateForUi(newTo)}',
                                                          ),
                                                          diffRow(
                                                            'New rate will start',
                                                            '-',
                                                            _formatDateForUi(
                                                              p.effectiveFrom,
                                                            ),
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
                                                  onPressed:
                                                      (p.valid && p.selectable)
                                                      ? () {
                                                          setState(() {
                                                            final newVal =
                                                                !p.approved;
                                                            if (newVal) {
                                                              for (final other
                                                                  in _proposals) {
                                                                if (other.hsnCode
                                                                            .toLowerCase() ==
                                                                        p.hsnCode
                                                                            .toLowerCase() &&
                                                                    !identical(
                                                                      other,
                                                                      p,
                                                                    )) {
                                                                  other.approved =
                                                                      false;
                                                                }
                                                              }
                                                            }
                                                            p.approved = newVal;
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
