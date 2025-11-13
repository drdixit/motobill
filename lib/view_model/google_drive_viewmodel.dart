import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import '../core/providers/database_provider.dart';
import '../model/google_account_info.dart';
import '../repository/key_value_repository.dart';
import '../repository/google_drive_repository.dart';

// Google Drive state
class GoogleDriveState {
  final GoogleAccountInfo? accountInfo;
  final bool isLoading;
  final double uploadProgress; // 0.0 to 1.0
  final String? error;
  final String? successMessage;
  final bool isAuthenticating;

  GoogleDriveState({
    this.accountInfo,
    this.isLoading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.successMessage,
    this.isAuthenticating = false,
  });

  GoogleDriveState copyWith({
    GoogleAccountInfo? accountInfo,
    bool? isLoading,
    double? uploadProgress,
    String? error,
    String? successMessage,
    bool? isAuthenticating,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearAccount = false,
  }) {
    return GoogleDriveState(
      accountInfo: clearAccount ? null : (accountInfo ?? this.accountInfo),
      isLoading: isLoading ?? this.isLoading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
    );
  }

  bool get isAuthenticated => accountInfo?.isAuthenticated ?? false;
}

// Google Drive ViewModel
class GoogleDriveViewModel extends StateNotifier<GoogleDriveState> {
  final Ref ref;
  late final GoogleSignIn _googleSignIn;

  GoogleDriveViewModel(this.ref) : super(GoogleDriveState()) {
    _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
    _loadAccountInfo();
  }

  // Load account info from database
  Future<void> _loadAccountInfo() async {
    try {
      final db = await ref.read(databaseProvider);
      final keyValueRepo = KeyValueRepository(db);
      final driveRepo = GoogleDriveRepository(keyValueRepo);

      final accountInfo = await driveRepo.getAccountInfo();
      if (accountInfo != null) {
        state = state.copyWith(accountInfo: accountInfo);
      }
    } catch (e) {
      // Silent fail on load
    }
  }

  // Sign in with Google
  Future<void> signIn() async {
    state = state.copyWith(isAuthenticating: true, clearError: true);

    try {
      // Attempt silent sign in first
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();

      // If silent sign in fails, do interactive sign in
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        // User cancelled sign in
        state = state.copyWith(
          isAuthenticating: false,
          error: 'Sign in cancelled',
        );
        return;
      }

      // Get authentication
      final auth = await account.authentication;

      // Create account info
      final accountInfo = GoogleAccountInfo(
        email: account.email,
        displayName: account.displayName ?? account.email,
        photoUrl: account.photoUrl,
        refreshToken: auth.serverAuthCode,
        accessToken: auth.accessToken,
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
      );

      // Save to database
      final db = await ref.read(databaseProvider);
      final keyValueRepo = KeyValueRepository(db);
      final driveRepo = GoogleDriveRepository(keyValueRepo);
      await driveRepo.saveAccountInfo(accountInfo);

      state = state.copyWith(
        accountInfo: accountInfo,
        isAuthenticating: false,
        successMessage: 'Successfully signed in as ${account.email}',
      );

      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          state = state.copyWith(clearSuccess: true);
        }
      });
    } catch (e) {
      state = state.copyWith(
        isAuthenticating: false,
        error: 'Sign in failed: $e',
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();

      // Clear from database
      final db = await ref.read(databaseProvider);
      final keyValueRepo = KeyValueRepository(db);
      final driveRepo = GoogleDriveRepository(keyValueRepo);
      await driveRepo.clearAccountInfo();

      state = state.copyWith(
        clearAccount: true,
        successMessage: 'Successfully signed out',
      );

      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          state = state.copyWith(clearSuccess: true);
        }
      });
    } catch (e) {
      state = state.copyWith(error: 'Sign out failed: $e');
    }
  }

  // Upload backup to Google Drive
  Future<void> uploadBackup(String zipFilePath) async {
    if (!state.isAuthenticated) {
      state = state.copyWith(error: 'Please sign in with Google first');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      uploadProgress: 0.0,
      clearError: true,
    );

    try {
      // Update progress: Authenticating
      state = state.copyWith(uploadProgress: 0.1);

      // Get authenticated HTTP client
      final httpClient = await _getAuthenticatedClient();
      if (httpClient == null) {
        throw Exception('Failed to get authenticated client');
      }

      // Update progress: Preparing file
      state = state.copyWith(uploadProgress: 0.2);

      final file = File(zipFilePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found: $zipFilePath');
      }

      final fileName = file.uri.pathSegments.last;
      final fileSize = await file.length();
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

      // Update progress: Creating Drive API
      state = state.copyWith(uploadProgress: 0.3);

      final driveApi = drive.DriveApi(httpClient);

      // Create file metadata
      final driveFile = drive.File();
      driveFile.name = fileName;
      driveFile.description = 'MotoBill Database Backup';

      // Update progress: Starting upload
      state = state.copyWith(uploadProgress: 0.4);

      // Read file as stream for progress tracking
      final fileStream = file.openRead();
      final fileLength = await file.length();

      // Upload with progress tracking
      int uploadedBytes = 0;
      final progressStream = fileStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (List<int> data, sink) {
            uploadedBytes += data.length;
            final progress = 0.4 + (uploadedBytes / fileLength * 0.5);
            state = state.copyWith(uploadProgress: progress);
            sink.add(data);
          },
        ),
      );

      final media = drive.Media(progressStream, fileLength);

      // Upload to Drive
      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );

      // Update progress: Verifying
      state = state.copyWith(uploadProgress: 0.95);

      if (uploadedFile.id == null) {
        throw Exception('Failed to upload file to Google Drive');
      }

      // Update progress: Complete
      state = state.copyWith(uploadProgress: 1.0);

      // Small delay to show 100%
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(
        isLoading: false,
        uploadProgress: 0.0,
        successMessage:
            'Backup uploaded successfully to Google Drive!\nFile: $fileName\nSize: $fileSizeMB MB',
      );

      // Clear success message after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          state = state.copyWith(clearSuccess: true);
        }
      });
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        uploadProgress: 0.0,
        error: 'Upload failed: $e',
      );
    }
  }

  // Get authenticated HTTP client
  Future<http.Client?> _getAuthenticatedClient() async {
    try {
      // Try to get current user
      final account = await _googleSignIn.signInSilently();

      if (account == null) {
        // Need to re-authenticate
        state = state.copyWith(error: 'Session expired. Please sign in again.');
        return null;
      }

      // Get authenticated client
      final client = await _googleSignIn.authenticatedClient();
      return client;
    } catch (e) {
      // Token might be expired, try to refresh
      try {
        await _googleSignIn.signOut();
        final account = await _googleSignIn.signIn();

        if (account == null) {
          return null;
        }

        final client = await _googleSignIn.authenticatedClient();
        return client;
      } catch (e) {
        return null;
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

// Provider for GoogleDriveViewModel
final googleDriveViewModelProvider =
    StateNotifierProvider<GoogleDriveViewModel, GoogleDriveState>((ref) {
      return GoogleDriveViewModel(ref);
    });
