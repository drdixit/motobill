import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/gst_rate.dart';

class GstRateRepository {
  final Database _db;

  GstRateRepository(this._db);

  Future<List<Map<String, dynamic>>> getAllGstRates() async {
    try {
      final result = await _db.rawQuery('''
        SELECT
          gr.*,
          hc.code as hsn_code,
          hc.description as hsn_description
        FROM gst_rates gr
        LEFT JOIN hsn_codes hc ON gr.hsn_code_id = hc.id
        WHERE gr.is_deleted = 0
        ORDER BY hc.code, gr.effective_from DESC
      ''');
      return result;
    } catch (e) {
      throw Exception('Failed to get GST rates: $e');
    }
  }

  Future<GstRate?> getGstRateById(int id) async {
    try {
      final result = await _db.rawQuery(
        'SELECT * FROM gst_rates WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (result.isEmpty) return null;
      return GstRate.fromJson(result.first);
    } catch (e) {
      throw Exception('Failed to get GST rate: $e');
    }
  }

  Future<int> insertGstRate(GstRate gstRate) async {
    try {
      final id = await _db.rawInsert(
        '''
        INSERT INTO gst_rates (
          hsn_code_id, cgst, sgst, igst, utgst,
          effective_from, effective_to, is_enabled, is_deleted,
          created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, datetime('now'), datetime('now'))
      ''',
        [
          gstRate.hsnCodeId,
          gstRate.cgst,
          gstRate.sgst,
          gstRate.igst,
          gstRate.utgst,
          gstRate.effectiveFrom.toIso8601String().split('T')[0],
          gstRate.effectiveTo?.toIso8601String().split('T')[0],
          gstRate.isEnabled ? 1 : 0,
        ],
      );
      return id;
    } catch (e) {
      throw Exception('Failed to insert GST rate: $e');
    }
  }

  Future<void> updateGstRate(GstRate gstRate) async {
    try {
      await _db.rawUpdate(
        '''
        UPDATE gst_rates
        SET hsn_code_id = ?, cgst = ?, sgst = ?, igst = ?, utgst = ?,
            effective_from = ?, effective_to = ?, is_enabled = ?,
            updated_at = datetime('now')
        WHERE id = ?
      ''',
        [
          gstRate.hsnCodeId,
          gstRate.cgst,
          gstRate.sgst,
          gstRate.igst,
          gstRate.utgst,
          gstRate.effectiveFrom.toIso8601String().split('T')[0],
          gstRate.effectiveTo?.toIso8601String().split('T')[0],
          gstRate.isEnabled ? 1 : 0,
          gstRate.id,
        ],
      );
    } catch (e) {
      throw Exception('Failed to update GST rate: $e');
    }
  }

  Future<void> deleteGstRate(int id) async {
    try {
      await _db.rawUpdate(
        'UPDATE gst_rates SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
        [id],
      );
    } catch (e) {
      throw Exception('Failed to delete GST rate: $e');
    }
  }

  Future<void> toggleGstRateStatus(int id, bool isEnabled) async {
    try {
      await _db.rawUpdate(
        'UPDATE gst_rates SET is_enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
        [isEnabled ? 1 : 0, id],
      );
    } catch (e) {
      throw Exception('Failed to toggle GST rate status: $e');
    }
  }
}
