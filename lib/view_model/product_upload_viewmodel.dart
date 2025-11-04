import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/manufacturer.dart';
import '../model/product_proposal.dart';
import '../repository/manufacturer_repository.dart';

/// State for Product Upload Screen
class ProductUploadState {
  final String? fileName;
  final Map<String, List<List<String>>> sheets;
  final List<ProductProposal> proposals;
  final bool isProcessing;
  final double progress;
  final String progressMessage;
  final List<Manufacturer> manufacturers;
  final int selectedDefaultManufacturerId;
  final String? error;

  ProductUploadState({
    this.fileName,
    this.sheets = const {},
    this.proposals = const [],
    this.isProcessing = false,
    this.progress = 0.0,
    this.progressMessage = '',
    this.manufacturers = const [],
    this.selectedDefaultManufacturerId = 1,
    this.error,
  });

  ProductUploadState copyWith({
    String? fileName,
    bool clearFileName = false,
    Map<String, List<List<String>>>? sheets,
    List<ProductProposal>? proposals,
    bool? isProcessing,
    double? progress,
    String? progressMessage,
    List<Manufacturer>? manufacturers,
    int? selectedDefaultManufacturerId,
    String? error,
    bool clearError = false,
  }) {
    return ProductUploadState(
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      sheets: sheets ?? this.sheets,
      proposals: proposals ?? this.proposals,
      isProcessing: isProcessing ?? this.isProcessing,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      manufacturers: manufacturers ?? this.manufacturers,
      selectedDefaultManufacturerId:
          selectedDefaultManufacturerId ?? this.selectedDefaultManufacturerId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// ViewModel for Product Upload Screen
/// Handles all business logic for product upload functionality
class ProductUploadViewModel extends StateNotifier<ProductUploadState> {
  ProductUploadViewModel() : super(ProductUploadState());

  // Load manufacturers from database
  Future<void> loadManufacturers(Database db) async {
    try {
      final repository = ManufacturerRepository(db);
      final manufacturers = await repository.getAllManufacturers();
      state = state.copyWith(manufacturers: manufacturers);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load manufacturers: $e');
    }
  }

  // Set selected default manufacturer
  void setSelectedManufacturer(int manufacturerId) {
    state = state.copyWith(selectedDefaultManufacturerId: manufacturerId);
  }

  // Resolve manufacturer ID from Excel name or use dropdown default
  int resolveManufacturerId(String manufacturerNameFromExcel) {
    if (manufacturerNameFromExcel.isEmpty) {
      return state.selectedDefaultManufacturerId;
    }

    final matchedManufacturer = state.manufacturers
        .where(
          (m) =>
              m.name.toLowerCase() == manufacturerNameFromExcel.toLowerCase(),
        )
        .firstOrNull;

    if (matchedManufacturer != null) {
      return matchedManufacturer.id ?? state.selectedDefaultManufacturerId;
    }

    return state.selectedDefaultManufacturerId;
  }

  // Download template file
  Future<String?> downloadTemplate() async {
    try {
      final byteData = await rootBundle.load('assets/products.xlsx');
      final bytes = byteData.buffer.asUint8List();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Product Template',
        fileName: 'product_template.xlsx',
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

  // Set file name
  void setFileName(String? fileName) {
    state = state.copyWith(fileName: fileName, clearFileName: fileName == null);
  }

  // Set parsed sheets
  void setSheets(Map<String, List<List<String>>> sheets) {
    state = state.copyWith(sheets: sheets);
  }

  // Set proposals
  void setProposals(List<ProductProposal> proposals) {
    state = state.copyWith(proposals: proposals);
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

  // Toggle individual proposal approval
  void toggleProposalApproval(int index, bool approved) {
    final updatedProposals = List<ProductProposal>.from(state.proposals);
    updatedProposals[index].approved = approved;
    state = state.copyWith(proposals: updatedProposals);
  }

  // Approve all valid proposals
  void approveAll() {
    final updatedProposals = List<ProductProposal>.from(state.proposals);
    for (final p in updatedProposals) {
      if (p.valid) {
        p.approved = true;
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
}

// Provider
final productUploadViewModelProvider =
    StateNotifierProvider.autoDispose<
      ProductUploadViewModel,
      ProductUploadState
    >((ref) {
      return ProductUploadViewModel();
    });
