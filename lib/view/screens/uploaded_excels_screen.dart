import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/providers/database_provider.dart';
import '../../repository/excel_upload_repository.dart';

final excelUploadsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = ExcelUploadRepository(db);
  return repository.getAllExcelUploads();
});

class UploadedExcelsScreen extends ConsumerStatefulWidget {
  const UploadedExcelsScreen({super.key});

  @override
  ConsumerState<UploadedExcelsScreen> createState() =>
      _UploadedExcelsScreenState();
}

class _UploadedExcelsScreenState extends ConsumerState<UploadedExcelsScreen> {
  String _searchQuery = '';

  Future<void> _downloadFile(String fileName) async {
    try {
      final sourcePath = path.join(
        'C:',
        'motobill',
        'database',
        'excel_files',
        fileName,
      );

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File not found: $fileName'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Show save file dialog
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputPath == null) {
        // User cancelled the dialog
        return;
      }

      // Copy file to selected location
      await sourceFile.copy(outputPath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File saved to: $outputPath'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _formatFileType(String fileType) {
    switch (fileType) {
      case 'products':
        return 'Products';
      case 'hsn':
      case 'hsn_codes':
        return 'HSN Codes';
      default:
        return fileType;
    }
  }

  String _formatDateTime(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate);
      final hour = dateTime.hour;
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
          '${hour12.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final excelUploadsAsync = ref.watch(excelUploadsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploaded Excel Files',
                style: TextStyle(
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search files...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),

          // Content
          Expanded(
            child: excelUploadsAsync.when(
              data: (uploads) {
                if (uploads.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No uploaded files found',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter uploads based on search query
                final filteredUploads = uploads.where((upload) {
                  final fileName = (upload['file_name'] as String)
                      .toLowerCase();
                  final fileType = (upload['file_type'] as String)
                      .toLowerCase();
                  return fileName.contains(_searchQuery) ||
                      fileType.contains(_searchQuery);
                }).toList();

                if (filteredUploads.isEmpty) {
                  return Center(
                    child: Text(
                      'No files match your search',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'File Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Type',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Uploaded At',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                'Actions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Table Body
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredUploads.length,
                          itemBuilder: (context, index) {
                            final upload = filteredUploads[index];
                            final fileName = upload['file_name'] as String;
                            final fileType = upload['file_type'] as String;
                            final createdAt = upload['created_at'] as String;

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.divider,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.description,
                                            color: AppColors.success,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              fileName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _formatFileType(fileType),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _formatDateTime(createdAt),
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(Icons.download),
                                          color: AppColors.primary,
                                          tooltip: 'Download',
                                          onPressed: () =>
                                              _downloadFile(fileName),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading files: $error',
                      style: TextStyle(fontSize: 16, color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
