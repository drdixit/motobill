import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  String _response = '';
  String _requestInfo = '';
  bool _isLoading = false;
  String _selectedMethod = 'GET';
  final List<String> _methods = ['GET', 'POST'];
  final TextEditingController _urlController = TextEditingController(
    text: 'http://192.168.1.3/ci360/api/DocIntelligenece/Invoices/dummy',
  );
  File? _selectedFile;
  String? _selectedFileName;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
    });
  }

  Future<void> _testApi() async {
    final urlText = _urlController.text.trim();

    if (urlText.isEmpty) {
      setState(() {
        _response = 'Error: URL cannot be empty';
        _requestInfo = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _response = 'Starting request...';
      _requestInfo = '';
    });

    // Give UI a chance to update
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final url = Uri.parse(urlText);
      String requestDetails = '=== REQUEST ===\n';
      requestDetails += 'Method: $_selectedMethod\n';
      requestDetails += 'URL: $urlText\n';

      if (_selectedMethod == 'GET') {
        requestDetails += '\n--- Request Body ---\n';
        requestDetails += 'None\n';

        final response = await http.get(url);

        setState(() {
          _requestInfo = requestDetails;
          _response = _formatSimpleResponse(response);
          _isLoading = false;
        });
      } else if (_selectedMethod == 'POST') {
        if (_selectedFile != null) {
          requestDetails += '\n--- Request Body ---\n';
          requestDetails += 'File: $_selectedFileName\n';
          requestDetails += 'Size: ${_selectedFile!.lengthSync()} bytes\n';

          setState(() {
            _requestInfo = requestDetails;
            _response = 'Uploading file...';
          });

          await Future.delayed(const Duration(milliseconds: 50));

          var request = http.MultipartRequest('POST', url);

          // Add file with explicit content type
          final fileStream = http.ByteStream(_selectedFile!.openRead());
          final fileLength = _selectedFile!.lengthSync();

          request.files.add(
            http.MultipartFile(
              'file',
              fileStream,
              fileLength,
              filename: _selectedFileName,
              contentType: MediaType('application', 'pdf'),
            ),
          );

          setState(() {
            _response = 'Sending request...';
          });

          await Future.delayed(const Duration(milliseconds: 50));

          final streamedResponse = await request.send();

          setState(() {
            _response = 'Receiving response...';
          });

          await Future.delayed(const Duration(milliseconds: 50));

          final response = await http.Response.fromStream(streamedResponse);

          setState(() {
            _requestInfo = requestDetails;
            _response = _formatSimpleResponse(response);
            _isLoading = false;
          });
        } else {
          requestDetails += '\n--- Request Body ---\n';
          requestDetails += 'None\n';

          final response = await http.post(url);

          setState(() {
            _requestInfo = requestDetails;
            _response = _formatSimpleResponse(response);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _requestInfo = '';
        _response = '\n=== ERROR ===\n$e';
        _isLoading = false;
      });
    }
  }

  String _formatSimpleResponse(http.Response response) {
    String result = '\n\n=== RESPONSE ===\n';
    result += 'Status: ${response.statusCode}\n';
    result += 'Message: ${response.reasonPhrase ?? "OK"}\n\n';

    result += '--- Headers ---\n';
    response.headers.forEach((key, value) {
      result += '$key: $value\n';
    });

    result += '\n--- Body ---\n';

    // Limit body display to 2KB to prevent freeze
    final bodyLength = response.body.length;
    if (bodyLength > 2000) {
      result += '[Large response: $bodyLength bytes]\n';
      result += response.body.substring(0, 2000);
      result += '\n\n[...truncated]';
    } else {
      result += response.body;
    }

    return result;
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
                      if (_selectedMethod == 'POST') ...[
                        OutlinedButton.icon(
                          onPressed: _selectedFile == null
                              ? _pickFile
                              : _clearFile,
                          icon: Icon(
                            _selectedFile == null
                                ? Icons.upload_file
                                : Icons.close,
                            size: 18,
                          ),
                          label: Text(
                            _selectedFile == null ? 'Upload PDF' : 'Clear',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _selectedFile == null
                                ? AppColors.primary
                                : Colors.red,
                            side: BorderSide(
                              color: _selectedFile == null
                                  ? AppColors.primary
                                  : Colors.red,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        if (_selectedFile != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedFileName ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 16),
                      ],
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
                              child: _response.isEmpty && _requestInfo.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Click "Test API" to see the request and response',
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
                                        '$_requestInfo$_response',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                          color: _response.contains('ERROR')
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
