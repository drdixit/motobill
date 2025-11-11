import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../model/api_test_response.dart';

class ApiTestRepository {
  Future<ApiTestResponse> sendGetRequest(String url) async {
    final uri = Uri.parse(url);
    final response = await http.get(uri);

    return _mapResponse(response);
  }

  Future<ApiTestResponse> sendPostRequest(String url) async {
    final uri = Uri.parse(url);
    final response = await http.post(uri);

    return _mapResponse(response);
  }

  Future<ApiTestResponse> uploadFile({
    required String url,
    required String filePath,
    required String fileName,
  }) async {
    final uri = Uri.parse(url);
    final request = http.MultipartRequest('POST', uri);

    // Stream file without loading into memory
    final file = File(filePath);
    final fileStream = http.ByteStream(file.openRead());
    final fileLength = file.lengthSync();

    request.files.add(
      http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _mapResponse(response);
  }

  ApiTestResponse _mapResponse(http.Response response) {
    return ApiTestResponse(
      statusCode: response.statusCode,
      reasonPhrase: response.reasonPhrase,
      headers: response.headers,
      body: response.body,
      bodyLength: response.body.length,
    );
  }

  /// Calculate SHA-256 hash of a file
  Future<String> calculateFileHash(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
