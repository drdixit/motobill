import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/hsn_code.dart';

class HsnCodeRepository {
  final Database _db;

  HsnCodeRepository(this._db);

  Future<List<HsnCode>> getAllHsnCodes() async {
    try {
      final result = await _db.rawQuery('''
        SELECT * FROM hsn_codes
        WHERE is_deleted = 0
        ORDER BY code
      ''');
      return result.map((json) => HsnCode.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get HSN codes: $e');
    }
  }

  Future<HsnCode?> getHsnCodeById(int id) async {
    try {
      final result = await _db.rawQuery(
        'SELECT * FROM hsn_codes WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (result.isEmpty) return null;
      return HsnCode.fromJson(result.first);
    } catch (e) {
      throw Exception('Failed to get HSN code: $e');
    }
  }

  Future<int> insertHsnCode(HsnCode hsnCode) async {
    try {
      final id = await _db.rawInsert(
        '''
        INSERT INTO hsn_codes (code, description, is_enabled, is_deleted, created_at, updated_at)
        VALUES (?, ?, ?, 0, datetime('now'), datetime('now'))
      ''',
        [hsnCode.code, hsnCode.description, hsnCode.isEnabled ? 1 : 0],
      );
      return id;
    } catch (e) {
      throw Exception('Failed to insert HSN code: $e');
    }
  }

  Future<void> updateHsnCode(HsnCode hsnCode) async {
    try {
      await _db.rawUpdate(
        '''
        UPDATE hsn_codes
        SET code = ?, description = ?, is_enabled = ?, updated_at = datetime('now')
        WHERE id = ?
      ''',
        [
          hsnCode.code,
          hsnCode.description,
          hsnCode.isEnabled ? 1 : 0,
          hsnCode.id,
        ],
      );
    } catch (e) {
      throw Exception('Failed to update HSN code: $e');
    }
  }

  Future<void> deleteHsnCode(int id) async {
    try {
      await _db.rawUpdate(
        'UPDATE hsn_codes SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
        [id],
      );
    } catch (e) {
      throw Exception('Failed to delete HSN code: $e');
    }
  }

  Future<void> toggleHsnCodeStatus(int id, bool isEnabled) async {
    try {
      await _db.rawUpdate(
        'UPDATE hsn_codes SET is_enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
        [isEnabled ? 1 : 0, id],
      );
    } catch (e) {
      throw Exception('Failed to toggle HSN code status: $e');
    }
  }
}
