import 'package:flutter/material.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';

class ApiFileSelector extends StatelessWidget {
  final File? selectedFile;
  final String? selectedFileName;
  final VoidCallback onSelectFile;
  final VoidCallback onClearFile;

  const ApiFileSelector({
    super.key,
    required this.selectedFile,
    required this.selectedFileName,
    required this.onSelectFile,
    required this.onClearFile,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedFile != null) {
      return Container(
        width: 250,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedFileName ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${(selectedFile!.lengthSync() / 1024).toStringAsFixed(2)} KB',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClearFile,
              color: Colors.red,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      );
    } else {
      return SizedBox(
        width: 250,
        child: ElevatedButton.icon(
          onPressed: onSelectFile,
          icon: const Icon(Icons.upload_file, size: 20),
          label: const Text('Select PDF File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }
  }
}
