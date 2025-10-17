import 'package:sqflite_common/sqlite_api.dart';
import '../model/company_info.dart';

class CompanyInfoRepository {
  final Database _db;

  CompanyInfoRepository(this._db);

  Future<CompanyInfo?> getPrimaryCompanyInfo() async {
    final result = await _db.rawQuery('''SELECT * FROM company_info
         WHERE is_primary = 1 AND is_deleted = 0 AND is_enabled = 1
         LIMIT 1''');
    if (result.isEmpty) return null;
    return CompanyInfo.fromJson(result.first);
  }

  Future<List<CompanyInfo>> getAllCompanyInfo() async {
    final result = await _db.rawQuery(
      'SELECT * FROM company_info WHERE is_deleted = 0 ORDER BY is_primary DESC, name ASC',
    );
    return result.map((json) => CompanyInfo.fromJson(json)).toList();
  }

  Future<CompanyInfo?> getCompanyInfoById(int id) async {
    final result = await _db.rawQuery(
      'SELECT * FROM company_info WHERE id = ? AND is_deleted = 0',
      [id],
    );
    if (result.isEmpty) return null;
    return CompanyInfo.fromJson(result.first);
  }

  Future<void> updateCompanyInfo(CompanyInfo companyInfo) async {
    try {
      await _db.rawUpdate(
        '''
        UPDATE company_info
        SET name = ?, legal_name = ?, gst_number = ?,
            address_line1 = ?, address_line2 = ?, city = ?,
            state = ?, pincode = ?, phone = ?, email = ?,
            updated_at = datetime('now')
        WHERE id = ?
      ''',
        [
          companyInfo.name,
          companyInfo.legalName,
          companyInfo.gstNumber,
          companyInfo.addressLine1,
          companyInfo.addressLine2,
          companyInfo.city,
          companyInfo.state,
          companyInfo.pincode,
          companyInfo.phone,
          companyInfo.email,
          companyInfo.id,
        ],
      );
    } catch (e) {
      throw Exception('Failed to update company info: $e');
    }
  }
}
