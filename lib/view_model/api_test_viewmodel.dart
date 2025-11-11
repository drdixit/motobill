import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../repository/api_test_repository.dart';
import '../repository/api_cache_repository.dart';
import '../model/api_test_response.dart';
import '../core/providers/database_provider.dart';

final apiTestRepositoryProvider = Provider((ref) => ApiTestRepository());

final apiTestViewModelProvider =
    StateNotifierProvider<ApiTestViewModel, ApiTestState>((ref) {
      final repository = ref.watch(apiTestRepositoryProvider);
      final dbFuture = ref.watch(databaseProvider);
      return ApiTestViewModel(repository, dbFuture);
    });

class ApiTestState {
  final bool isLoading;
  final String requestInfo;
  final String responseInfo;
  final String? error;
  final String fullResponseBody; // Store complete response for parsing
  final int? statusCode; // Store HTTP status code
  final bool isCachedResponse; // Indicate if response came from cache

  ApiTestState({
    this.isLoading = false,
    this.requestInfo = '',
    this.responseInfo = '',
    this.error,
    this.fullResponseBody = '',
    this.statusCode,
    this.isCachedResponse = false,
  });

  // Check if response is successful (HTTP 200-299)
  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;

  ApiTestState copyWith({
    bool? isLoading,
    String? requestInfo,
    String? responseInfo,
    String? error,
    String? fullResponseBody,
    int? statusCode,
    bool? isCachedResponse,
  }) {
    return ApiTestState(
      isLoading: isLoading ?? this.isLoading,
      requestInfo: requestInfo ?? this.requestInfo,
      responseInfo: responseInfo ?? this.responseInfo,
      error: error ?? this.error,
      fullResponseBody: fullResponseBody ?? this.fullResponseBody,
      statusCode: statusCode ?? this.statusCode,
      isCachedResponse: isCachedResponse ?? this.isCachedResponse,
    );
  }
}

class ApiTestViewModel extends StateNotifier<ApiTestState> {
  final ApiTestRepository _repository;
  final Future<dynamic> _dbFuture;

  ApiTestViewModel(this._repository, this._dbFuture) : super(ApiTestState());

  Future<void> sendGetRequest(String url) async {
    if (url.isEmpty) {
      state = state.copyWith(
        error: 'URL cannot be empty',
        requestInfo: '',
        responseInfo: '',
        statusCode: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      responseInfo: 'Starting request...',
      requestInfo: '',
      error: null,
      statusCode: null,
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final requestInfo = _buildRequestInfo('GET', url);

      final response = await _repository.sendGetRequest(url);

      state = state.copyWith(
        isLoading: false,
        requestInfo: requestInfo,
        responseInfo: _formatResponse(response),
        fullResponseBody: response.body, // Store full body
        statusCode: response.statusCode, // Store status code
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        requestInfo: '',
        responseInfo: '\n=== ERROR ===\n$e',
        error: e.toString(),
        statusCode: null,
      );
    }
  }

  Future<void> sendPostRequest(
    String url, {
    String? filePath,
    String? fileName,
  }) async {
    if (url.isEmpty) {
      state = state.copyWith(
        error: 'URL cannot be empty',
        requestInfo: '',
        responseInfo: '',
        statusCode: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      responseInfo: 'Starting request...',
      requestInfo: '',
      error: null,
      statusCode: null,
      isCachedResponse: false,
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      String requestInfo;
      ApiTestResponse response;
      bool usedCache = false;

      if (filePath != null && fileName != null) {
        requestInfo = _buildRequestInfoWithFile(
          'POST',
          url,
          fileName,
          filePath,
        );

        state = state.copyWith(
          requestInfo: requestInfo,
          responseInfo: 'Calculating file hash...',
        );
        await Future.delayed(const Duration(milliseconds: 50));

        // Calculate file hash
        final fileHash = await _repository.calculateFileHash(filePath);

        state = state.copyWith(responseInfo: 'Checking cache...');
        await Future.delayed(const Duration(milliseconds: 50));

        // Get database and cache repository
        final db = await _dbFuture;
        final cacheRepository = ApiCacheRepository(db);

        // Check if cached response exists
        final cachedResponse = await cacheRepository.getCachedResponse(
          fileHash,
        );

        if (cachedResponse != null) {
          // Use cached response
          usedCache = true;
          state = state.copyWith(responseInfo: 'Using cached response...');
          await Future.delayed(const Duration(milliseconds: 50));

          response = ApiTestResponse(
            statusCode: 200,
            reasonPhrase: 'OK (Cached)',
            headers: {'x-cache': 'HIT'},
            body: cachedResponse,
            bodyLength: cachedResponse.length,
          );
        } else {
          // No cache, hit the API
          state = state.copyWith(
            requestInfo: requestInfo,
            responseInfo: 'Uploading file...',
          );
          await Future.delayed(const Duration(milliseconds: 50));

          state = state.copyWith(responseInfo: 'Sending request...');
          await Future.delayed(const Duration(milliseconds: 50));

          response = await _repository.uploadFile(
            url: url,
            filePath: filePath,
            fileName: fileName,
          );

          state = state.copyWith(responseInfo: 'Receiving response...');
          await Future.delayed(const Duration(milliseconds: 50));

          // If response is successful, cache it
          if (response.statusCode >= 200 && response.statusCode < 300) {
            state = state.copyWith(responseInfo: 'Caching response...');
            await Future.delayed(const Duration(milliseconds: 50));

            await cacheRepository.cacheResponse(fileHash, response.body);
          }
        }
      } else {
        requestInfo = _buildRequestInfo('POST', url);
        response = await _repository.sendPostRequest(url);
      }

      state = state.copyWith(
        isLoading: false,
        requestInfo: requestInfo,
        responseInfo: _formatResponse(response, isCached: usedCache),
        fullResponseBody: response.body, // Store full body
        statusCode: response.statusCode, // Store status code
        isCachedResponse: usedCache,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        requestInfo: '',
        responseInfo: '\n=== ERROR ===\n$e',
        error: e.toString(),
        statusCode: null,
        isCachedResponse: false,
      );
    }
  }

  String _buildRequestInfo(String method, String url) {
    String info = '=== REQUEST ===\n';
    info += 'Method: $method\n';
    info += 'URL: $url\n';
    info += '\n--- Request Body ---\n';
    info += 'None\n';
    return info;
  }

  String _buildRequestInfoWithFile(
    String method,
    String url,
    String fileName,
    String filePath,
  ) {
    String info = '=== REQUEST ===\n';
    info += 'Method: $method\n';
    info += 'URL: $url\n';
    info += '\n--- Request Body ---\n';
    info += 'File: $fileName\n';
    info += 'Size: ${_getFileSize(filePath)} bytes\n';
    return info;
  }

  int _getFileSize(String filePath) {
    try {
      return File(filePath).lengthSync();
    } catch (e) {
      return 0;
    }
  }

  String _formatResponse(ApiTestResponse response, {bool isCached = false}) {
    String result = '\n\n=== RESPONSE ===\n';

    if (isCached) {
      result += '🔄 CACHED RESPONSE (File already processed)\n\n';
    }

    result += 'Status: ${response.statusCode}\n';
    result += 'Message: ${response.reasonPhrase ?? "OK"}\n\n';

    result += '--- Headers ---\n';
    response.headers.forEach((key, value) {
      result += '$key: $value\n';
    });

    result += '\n--- Body ---\n';

    // Limit body display to 2KB to prevent freeze
    if (response.bodyLength > 2000) {
      result += '[Large response: ${response.bodyLength} bytes]\n';
      result += response.body.substring(0, 2000);
      result += '\n\n[...truncated]';
    } else {
      result += response.body;
    }

    return result;
  }

  void clearResponse() {
    state = ApiTestState();
  }
}
