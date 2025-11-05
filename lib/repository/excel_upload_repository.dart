import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ExcelUploadRepository {
  final Database _db;

  ExcelUploadRepository(this._db);

  Future<List<Map<String, dynamic>>> getAllExcelUploads() async {
    return await _db.rawQuery('''
      SELECT * FROM excel_uploads
      WHERE is_deleted = 0
      ORDER BY created_at DESC
    ''');
  }

  Future<Map<String, dynamic>?> getExcelUploadById(int id) async {
    final result = await _db.rawQuery(
      'SELECT * FROM excel_uploads WHERE id = ? AND is_deleted = 0',
      [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> deleteExcelUpload(int id) async {
    await _db.rawUpdate(
      'UPDATE excel_uploads SET is_deleted = 1, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }
}
