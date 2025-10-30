import 'package:flutter/material.dart';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class ProductUploadScreen extends ConsumerStatefulWidget {
  const ProductUploadScreen({super.key});

  @override
  ConsumerState<ProductUploadScreen> createState() =>
      _ProductUploadScreenState();
}

class _ProductUploadScreenState extends ConsumerState<ProductUploadScreen> {
  String? _fileName;
  final Map<String, List<List<String>>> _sheets = {};

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    try {
      final bytes = File(path).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      final Map<String, List<List<String>>> parsed = {};
      for (final sheetName in excel.tables.keys) {
        final table = excel.tables[sheetName];
        if (table == null) continue;
        final rows = <List<String>>[];
        for (final row in table.rows) {
          final cells = row
              .map((cell) {
                if (cell == null) return '';
                final val = cell.value;
                return val == null ? '' : val.toString();
              })
              .toList(growable: false);
          rows.add(cells);
        }
        parsed[sheetName] = rows;
      }

      setState(() {
        _sheets
          ..clear()
          ..addAll(parsed);
        _fileName = result.files.single.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read Excel file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Product Upload',
            style: TextStyle(
              fontSize: AppSizes.fontXXL,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            _fileName == null
                ? 'Upload a product .xlsx file to import products'
                : 'Selected: $_fileName',
            style: TextStyle(
              fontSize: AppSizes.fontM,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload .xlsx'),
              ),
              const SizedBox(width: AppSizes.paddingM),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _fileName = null;
                  });
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),
          if (_sheets.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Text(
                      'This screen is a placeholder for the Product Upload flow.',
                    ),
                    SizedBox(height: AppSizes.paddingS),
                    Text(
                      'You can upload an .xlsx, preview parsed rows, validate, and apply changes to DB.',
                    ),
                  ],
                ),
              ),
            )
          else
            // Show first sheet content in a scrollable DataTable
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sheets: ${_sheets.keys.join(', ')}',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSizes.paddingS),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: _buildSheetTable(
                            _sheets.entries.first.key,
                            _sheets.entries.first.value,
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
    );
  }

  Widget _buildSheetTable(String name, List<List<String>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Determine max columns
    var maxCols = 0;
    for (final r in rows) {
      if (r.length > maxCols) maxCols = r.length;
    }

    // Determine if first row is header-like
    final firstRow = rows.first;
    final isHeader =
        firstRow.join(' ').trim().isNotEmpty &&
        firstRow.any((c) => RegExp(r'[A-Za-z]').hasMatch(c));

    final headers = List<String>.generate(
      maxCols,
      (i) => isHeader && i < firstRow.length && firstRow[i].trim().isNotEmpty
          ? firstRow[i].trim()
          : 'Col ${i + 1}',
    );

    final dataRows = isHeader ? rows.sublist(1) : rows;

    return DataTable(
      columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
      rows: dataRows.map((r) {
        final cells = List<String>.from(r);
        // pad
        while (cells.length < maxCols) cells.add('');
        return DataRow(cells: cells.map((c) => DataCell(Text(c))).toList());
      }).toList(),
    );
  }
}
