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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Attach File (PDF)',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (selectedFile != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insert_drive_file,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedFileName ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${(selectedFile!.lengthSync() / 1024).toStringAsFixed(2)} KB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onClearFile,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: onSelectFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select PDF File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
