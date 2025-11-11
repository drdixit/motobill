import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../view_model/api_test_viewmodel.dart';
import '../../widgets/api_test/api_url_field.dart';
import '../../widgets/api_test/api_file_selector.dart';
import '../../widgets/api_test/api_response_display.dart';
import 'purchase_bill_preview_screen.dart';

class ApiTestScreen extends ConsumerStatefulWidget {
  const ApiTestScreen({super.key});

  @override
  ConsumerState<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends ConsumerState<ApiTestScreen> {
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

    // Always POST method with file
    if (_selectedFile != null && _selectedFileName != null) {
      viewModel.sendPostRequest(
        url,
        filePath: _selectedFile!.path,
        fileName: _selectedFileName!,
      );
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
                  // API URL, File Selector, and Test Button on same line
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // API URL Field
                      Expanded(
                        flex: 3,
                        child: ApiUrlField(controller: _urlController),
                      ),
                      const SizedBox(width: 12),
                      // File Selector
                      Expanded(
                        flex: 2,
                        child: ApiFileSelector(
                          selectedFile: _selectedFile,
                          selectedFileName: _selectedFileName,
                          onSelectFile: _pickFile,
                          onClearFile: _clearFile,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Test API Button
                      SizedBox(
                        width: 180,
                        child: ElevatedButton.icon(
                          onPressed: (state.isLoading || _selectedFile == null)
                              ? null
                              : _handleTestApi,
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
                            state.isLoading
                                ? 'Processing...'
                                : 'Test API (POST)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ApiResponseDisplay(
              requestInfo: state.requestInfo,
              responseInfo: state.responseInfo,
            ),
            // Parse Invoice Button - Only show when API response is successful
            if (state.isSuccess)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PurchaseBillPreviewScreen(
                          jsonResponse: state
                              .fullResponseBody, // Use full body for parsing
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Create Purchase Bill from Response'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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
      ),
    );
  }
}
