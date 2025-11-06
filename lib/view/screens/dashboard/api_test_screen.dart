import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_colors.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  String _response = '';
  bool _isLoading = false;
  String _selectedMethod = 'GET';
  final List<String> _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
  final TextEditingController _urlController = TextEditingController(
    text: 'https://dummyjson.com/test',
  );

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testApi() async {
    final urlText = _urlController.text.trim();

    if (urlText.isEmpty) {
      setState(() {
        _response = 'Error: URL cannot be empty';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      final url = Uri.parse(urlText);
      http.Response response;

      switch (_selectedMethod) {
        case 'GET':
          response = await http.get(url);
          break;
        case 'POST':
          response = await http.post(url);
          break;
        case 'PUT':
          response = await http.put(url);
          break;
        case 'PATCH':
          response = await http.patch(url);
          break;
        case 'DELETE':
          response = await http.delete(url);
          break;
        default:
          response = await http.get(url);
      }

      // Get content type from headers
      final contentType = response.headers['content-type'] ?? '';
      String formattedResponse = 'Status Code: ${response.statusCode}\n';
      formattedResponse += 'Content-Type: $contentType\n\n';

      // Try to parse as JSON first
      if (contentType.contains('application/json') ||
          contentType.contains('text/json')) {
        try {
          final jsonResponse = json.decode(response.body);
          final prettyJson = const JsonEncoder.withIndent(
            '  ',
          ).convert(jsonResponse);
          formattedResponse += prettyJson;
        } catch (e) {
          formattedResponse += response.body;
        }
      } else if (contentType.contains('image/')) {
        // Handle image responses
        formattedResponse +=
            '[Image Response - ${response.bodyBytes.length} bytes]\n';
        formattedResponse +=
            'This is a binary image file and cannot be displayed as text.\n';
        formattedResponse += 'Content-Type: $contentType';
      } else if (contentType.contains('text/')) {
        // Handle plain text responses
        formattedResponse += response.body;
      } else {
        // Try to parse as JSON anyway, if it fails show raw body
        try {
          final jsonResponse = json.decode(response.body);
          final prettyJson = const JsonEncoder.withIndent(
            '  ',
          ).convert(jsonResponse);
          formattedResponse += prettyJson;
        } catch (e) {
          // Not JSON, show raw response or binary info
          if (response.bodyBytes.length > 1000 && response.body.contains('ÿ')) {
            formattedResponse +=
                '[Binary Response - ${response.bodyBytes.length} bytes]\n';
            formattedResponse +=
                'This appears to be binary data and cannot be displayed as text.';
          } else {
            formattedResponse += response.body;
          }
        }
      }

      setState(() {
        _response = formattedResponse;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test API Endpoint',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'API URL',
                      hintText: 'Enter API endpoint URL',
                      prefixIcon: Icon(Icons.link, color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Method:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedMethod,
                        items: _methods.map((method) {
                          return DropdownMenuItem(
                            value: method,
                            child: Text(
                              method,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedMethod = value!;
                          });
                        },
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testApi,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow, size: 20),
                        label: Text(_isLoading ? 'Loading...' : 'Test API'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Response',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading...',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: _response.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Click "Test API" to see the response',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: SelectableText(
                                        _response,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                          color: _response.startsWith('Error')
                                              ? Colors.red.shade700
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
