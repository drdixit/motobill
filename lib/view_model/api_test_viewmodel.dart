import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../repository/api_test_repository.dart';
import '../model/api_test_response.dart';

final apiTestRepositoryProvider = Provider((ref) => ApiTestRepository());

final apiTestViewModelProvider =
    StateNotifierProvider<ApiTestViewModel, ApiTestState>((ref) {
      final repository = ref.watch(apiTestRepositoryProvider);
      return ApiTestViewModel(repository);
    });

class ApiTestState {
  final bool isLoading;
  final String requestInfo;
  final String responseInfo;
  final String? error;
  final String fullResponseBody; // Store complete response for parsing

  ApiTestState({
    this.isLoading = false,
    this.requestInfo = '',
    this.responseInfo = '',
    this.error,
    this.fullResponseBody = '',
  });

  ApiTestState copyWith({
    bool? isLoading,
    String? requestInfo,
    String? responseInfo,
    String? error,
    String? fullResponseBody,
  }) {
    return ApiTestState(
      isLoading: isLoading ?? this.isLoading,
      requestInfo: requestInfo ?? this.requestInfo,
      responseInfo: responseInfo ?? this.responseInfo,
      error: error ?? this.error,
      fullResponseBody: fullResponseBody ?? this.fullResponseBody,
    );
  }
}

class ApiTestViewModel extends StateNotifier<ApiTestState> {
  final ApiTestRepository _repository;

  ApiTestViewModel(this._repository) : super(ApiTestState());

  Future<void> sendGetRequest(String url) async {
    if (url.isEmpty) {
      state = state.copyWith(
        error: 'URL cannot be empty',
        requestInfo: '',
        responseInfo: '',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      responseInfo: 'Starting request...',
      requestInfo: '',
      error: null,
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
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        requestInfo: '',
        responseInfo: '\n=== ERROR ===\n$e',
        error: e.toString(),
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
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      responseInfo: 'Starting request...',
      requestInfo: '',
      error: null,
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      String requestInfo;
      ApiTestResponse response;

      if (filePath != null && fileName != null) {
        requestInfo = _buildRequestInfoWithFile(
          'POST',
          url,
          fileName,
          filePath,
        );

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
      } else {
        requestInfo = _buildRequestInfo('POST', url);
        response = await _repository.sendPostRequest(url);
      }

      state = state.copyWith(
        isLoading: false,
        requestInfo: requestInfo,
        responseInfo: _formatResponse(response),
        fullResponseBody: response.body, // Store full body
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        requestInfo: '',
        responseInfo: '\n=== ERROR ===\n$e',
        error: e.toString(),
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

  String _formatResponse(ApiTestResponse response) {
    String result = '\n\n=== RESPONSE ===\n';
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
}
