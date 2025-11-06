class ApiTestRequest {
  final String url;
  final String method;
  final String? filePath;
  final String? fileName;

  ApiTestRequest({
    required this.url,
    required this.method,
    this.filePath,
    this.fileName,
  });
}
