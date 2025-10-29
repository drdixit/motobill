import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class TestingScreen extends StatefulWidget {
  const TestingScreen({super.key});

  @override
  State<TestingScreen> createState() => _TestingScreenState();
}

class _TestingScreenState extends State<TestingScreen> {
  // Map of sheetName -> rows (each row is List<String>)
  final Map<String, List<List<String>>> _sheets = {};
  String? _fileName;

  Future<void> _pickAndLoadExcel() async {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Testing',
                style: TextStyle(
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.paddingS),
              Text(
                _fileName == null
                    ? 'Upload an .xlsx file to display its contents'
                    : 'Showing: $_fileName',
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAndLoadExcel,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload .xlsx'),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  if (_sheets.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _sheets.clear();
                          _fileName = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingL),
              Expanded(
                child: _sheets.isEmpty
                    ? Center(
                        child: Text(
                          'No data loaded',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView(
                        children: _sheets.entries.map((entry) {
                          final sheetName = entry.key;
                          final rows = entry.value;
                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: AppSizes.paddingM,
                            ),
                            child: ExpansionTile(
                              title: Text(sheetName),
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Builder(
                                    builder: (context) {
                                      // Determine maximum number of columns across all rows
                                      final maxCols = rows.fold<int>(
                                        0,
                                        (prev, row) => row.length > prev
                                            ? row.length
                                            : prev,
                                      );
                                      final cols = maxCols > 0 ? maxCols : 1;

                                      final columnWidgets =
                                          List<DataColumn>.generate(
                                            cols,
                                            (i) => DataColumn(
                                              label: Text('C${i + 1}'),
                                            ),
                                          );

                                      if (columnWidgets.isEmpty) {
                                        // Defensive fallback: show a placeholder instead of an empty DataTable
                                        return Container(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            'No columns available to display',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        );
                                      }

                                      final dataRows = rows.map((r) {
                                        // Pad missing cells with empty strings so every row has `cols` cells
                                        return DataRow(
                                          cells: List<DataCell>.generate(cols, (
                                            i,
                                          ) {
                                            final value = i < r.length
                                                ? r[i]
                                                : '';
                                            return DataCell(Text(value));
                                          }),
                                        );
                                      }).toList();

                                      return DataTable(
                                        columns: columnWidgets,
                                        rows: dataRows,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
