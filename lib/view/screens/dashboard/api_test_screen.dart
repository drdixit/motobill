import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../view_model/api_test_viewmodel.dart';
import '../../widgets/api_test/api_url_field.dart';
import '../../widgets/api_test/api_method_selector.dart';
import '../../widgets/api_test/api_file_selector.dart';
import '../../widgets/api_test/api_response_display.dart';

class ApiTestScreen extends ConsumerStatefulWidget {
  const ApiTestScreen({super.key});

  @override
  ConsumerState<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends ConsumerState<ApiTestScreen> {
  final TextEditingController _urlController = TextEditingController(
    text: 'http://192.168.1.3/ci360/api/DocIntelligenece/Invoices/dummy',
  );
  final List<String> _methods = ['GET', 'POST'];
  String _selectedMethod = 'GET';
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
    });
  }

  void _handleTestApi() {
    final viewModel = ref.read(apiTestViewModelProvider.notifier);
    final url = _urlController.text.trim();

    if (_selectedMethod == 'GET') {
      viewModel.sendGetRequest(url);
    } else if (_selectedMethod == 'POST') {
      if (_selectedFile != null && _selectedFileName != null) {
        viewModel.sendPostRequest(
          url,
          filePath: _selectedFile!.path,
          fileName: _selectedFileName!,
        );
      } else {
        viewModel.sendPostRequest(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(apiTestViewModelProvider);

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
                  ApiUrlField(controller: _urlController),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ApiMethodSelector(
                          selectedMethod: _selectedMethod,
                          methods: _methods,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedMethod = newValue;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: state.isLoading ? null : _handleTestApi,
                          icon: state.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            state.isLoading ? 'Processing...' : 'Test API',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedMethod == 'POST') ...[
                    const SizedBox(height: 16),
                    ApiFileSelector(
                      selectedFile: _selectedFile,
                      selectedFileName: _selectedFileName,
                      onSelectFile: _pickFile,
                      onClearFile: _clearFile,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            ApiResponseDisplay(
              requestInfo: state.requestInfo,
              responseInfo: state.responseInfo,
            ),
          ],
        ),
      ),
    );
  }
}
