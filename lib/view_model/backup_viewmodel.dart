import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/providers/database_provider.dart';
import '../repository/key_value_repository.dart';

// Backup state
class BackupState {
  final String? backupLocation;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  BackupState({
    this.backupLocation,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  BackupState copyWith({
    String? backupLocation,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return BackupState(
      backupLocation: backupLocation ?? this.backupLocation,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

// We don't need a separate provider since we'll create repository instances
// directly in async methods with the database instance

// Backup ViewModel
class BackupViewModel extends StateNotifier<BackupState> {
  final Ref ref;
  static const String backupLocationKey = 'local_backup_location';

  BackupViewModel(this.ref) : super(BackupState()) {
    _loadBackupLocation();
  }

  // Load backup location from database
  Future<void> _loadBackupLocation() async {
    try {
      final db = await ref.read(databaseProvider);
      final repository = KeyValueRepository(db);
      final location = await repository.getValue(backupLocationKey);

      state = state.copyWith(
        backupLocation: location ?? 'No backup location set',
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load backup location: $e');
    }
  }

  // Select backup folder
  Future<void> selectBackupFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Location',
      );

      if (result != null) {
        // Save to database
        final db = await ref.read(databaseProvider);
        final repository = KeyValueRepository(db);
        await repository.setValue(backupLocationKey, result);

        state = state.copyWith(
          backupLocation: result,
          successMessage: 'Backup location updated successfully',
        );

        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            state = state.copyWith(clearSuccess: true);
          }
        });
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to select folder: $e');
    }
  }

  // Create backup
  Future<void> createBackup() async {
    // Validate backup location
    if (state.backupLocation == null ||
        state.backupLocation == 'No backup location set') {
      state = state.copyWith(error: 'Please select a backup location first');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final db = await ref.read(databaseProvider);
      final repository = KeyValueRepository(db);
      final backupLocation = await repository.getValue(backupLocationKey);

      if (backupLocation == null) {
        throw Exception('Backup location not found in database');
      }

      // Verify backup location exists
      final backupDir = Directory(backupLocation);
      if (!await backupDir.exists()) {
        throw Exception('Backup location does not exist: $backupLocation');
      }

      // Source directory to backup
      const sourceDir = 'C:/motobill/database';
      final source = Directory(sourceDir);

      if (!await source.exists()) {
        throw Exception('Source directory does not exist: $sourceDir');
      }

      // Generate filename with timestamp
      final now = DateTime.now();
      final timestamp = DateFormat('HH_mm_ss__dd_MM_yyyy').format(now);
      final zipFileName = '$timestamp.zip';
      final zipFilePath = '$backupLocation/$zipFileName';

      // Create zip archive
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      // Add all files and subdirectories from source
      await _addDirectoryToZip(encoder, source, sourceDir);

      encoder.close();

      // Verify zip file was created
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        throw Exception('Failed to create backup file');
      }

      final fileSizeBytes = await zipFile.length();
      final fileSizeMB = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);

      state = state.copyWith(
        isLoading: false,
        successMessage:
            'Backup created successfully!\nFile: $zipFileName\nSize: $fileSizeMB MB',
      );

      // Clear success message after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          state = state.copyWith(clearSuccess: true);
        }
      });
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Backup failed: $e');
    }
  }

  // Recursively add directory contents to zip
  Future<void> _addDirectoryToZip(
    ZipFileEncoder encoder,
    Directory dir,
    String baseDir,
  ) async {
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File) {
        final relativePath = entity.path.replaceFirst('$baseDir/', '');
        encoder.addFile(entity, relativePath);
      } else if (entity is Directory) {
        // Recursively add subdirectories
        await _addDirectoryToZip(encoder, entity, baseDir);
      }
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Clear success message
  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }
}

// Provider for BackupViewModel
final backupViewModelProvider =
    StateNotifierProvider<BackupViewModel, BackupState>((ref) {
      return BackupViewModel(ref);
    });
