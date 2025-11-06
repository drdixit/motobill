class ApiTestResponse {
  final int statusCode;
  final String? reasonPhrase;
  final Map<String, String> headers;
  final String body;
  final int bodyLength;

  ApiTestResponse({
    required this.statusCode,
    this.reasonPhrase,
    required this.headers,
    required this.body,
    required this.bodyLength,
  });
}
