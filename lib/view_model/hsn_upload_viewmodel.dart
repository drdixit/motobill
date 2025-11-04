import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import '../model/hsn_proposal.dart';

/// State for HSN Upload Screen
class HsnUploadState {
  final String? fileName;
  final Map<String, List<List<String>>> sheets;
  final List<HsnProposal> proposals;
  final bool isProcessing;
  final double progress;
  final String progressMessage;
  final String? error;

  HsnUploadState({
    this.fileName,
    this.sheets = const {},
    this.proposals = const [],
    this.isProcessing = false,
    this.progress = 0.0,
    this.progressMessage = '',
    this.error,
  });

  HsnUploadState copyWith({
    String? fileName,
    bool clearFileName = false,
    Map<String, List<List<String>>>? sheets,
    List<HsnProposal>? proposals,
    bool? isProcessing,
    double? progress,
    String? progressMessage,
    String? error,
    bool clearError = false,
  }) {
    return HsnUploadState(
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      sheets: sheets ?? this.sheets,
      proposals: proposals ?? this.proposals,
      isProcessing: isProcessing ?? this.isProcessing,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// ViewModel for HSN Upload Screen
/// Handles all business logic for HSN code upload functionality
class HsnUploadViewModel extends StateNotifier<HsnUploadState> {
  HsnUploadViewModel() : super(HsnUploadState());

  // Download template file
  Future<String?> downloadTemplate() async {
    try {
      final byteData = await rootBundle.load('assets/hsn_codes.xlsx');
      final bytes = byteData.buffer.asUint8List();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save HSN Code Template',
        fileName: 'hsn_code_template.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) return null;

      final file = File(result);
      await file.writeAsBytes(bytes);

      return path.basename(result);
    } catch (e) {
      state = state.copyWith(error: 'Failed to download template: $e');
      return null;
    }
  }

  // UI date formatting helper: MM/DD/YYYY
  String formatDateForUi(dynamic d) {
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

  // Pick and load Excel file
  Future<bool> pickAndLoadExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return false;

      final filePath = result.files.single.path;
      if (filePath == null) return false;

      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Validate H1 (column H, row 1): must contain exactly four spaces
      if (excel.tables.isNotEmpty) {
        final firstKey = excel.tables.keys.first;
        final firstTable = excel.tables[firstKey];
        if (firstTable != null && firstTable.rows.isNotEmpty) {
          final firstRow = firstTable.rows.first;
          String h1Val = '';
          if (firstRow.length > 7 && firstRow[7] != null) {
            final v = firstRow[7]?.value;
            h1Val = v == null ? '' : v.toString();
          }

          if (h1Val != '    ') {
            state = state.copyWith(
              error: 'Invalid Uploaded Excel File Please Use Official Template',
            );
            return false;
          }
        }
      }

      // Parse all sheets
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

      state = state.copyWith(
        sheets: parsed,
        fileName: result.files.single.name,
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to read Excel file: $e');
      return false;
    }
  }

  // Set processing state with progress
  void setProcessing(
    bool isProcessing, {
    double progress = 0.0,
    String message = '',
  }) {
    state = state.copyWith(
      isProcessing: isProcessing,
      progress: progress,
      progressMessage: message,
    );
  }

  // Set proposals
  void setProposals(List<HsnProposal> proposals) {
    state = state.copyWith(proposals: proposals);
  }

  // Toggle individual proposal approval
  void toggleProposalApproval(HsnProposal proposal, bool approved) {
    final updatedProposals = List<HsnProposal>.from(state.proposals);
    final index = updatedProposals.indexOf(proposal);

    if (index >= 0) {
      if (approved) {
        // Enforce single selection per HSN: unapprove others
        for (final other in updatedProposals) {
          if (other.hsnCode.toLowerCase() == proposal.hsnCode.toLowerCase() &&
              !identical(other, proposal)) {
            other.approved = false;
          }
        }
      }
      updatedProposals[index].approved = approved;
      state = state.copyWith(proposals: updatedProposals);
    }
  }

  // Approve all valid proposals (one per HSN)
  void approveAll() {
    final updatedProposals = List<HsnProposal>.from(state.proposals);
    final chosenHsn = <String>{};

    // Clear all approvals first
    for (final p in updatedProposals) {
      p.approved = false;
    }

    // Approve first valid/selectable proposal per HSN
    for (final p in updatedProposals) {
      final key = p.hsnCode.toLowerCase();
      if (p.valid && p.selectable && !chosenHsn.contains(key)) {
        p.approved = true;
        chosenHsn.add(key);
      }
    }

    state = state.copyWith(proposals: updatedProposals);
  }

  // Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Clear all state
  void clearAll() {
    state = state.copyWith(
      clearFileName: true,
      sheets: {},
      proposals: [],
      isProcessing: false,
      progress: 0.0,
      progressMessage: '',
      clearError: true,
    );
  }

  // Set error message
  void setError(String error) {
    state = state.copyWith(error: error);
  }

  // Helper method to parse double from dynamic value
  double parseDouble(dynamic v) {
    if (v == null || v.toString().trim().isEmpty) return 0.0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // Helper method to parse date from dynamic value
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
}

// Provider
final hsnUploadViewModelProvider =
    StateNotifierProvider.autoDispose<HsnUploadViewModel, HsnUploadState>((
      ref,
    ) {
      return HsnUploadViewModel();
    });
