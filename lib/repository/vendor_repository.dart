import 'package:sqflite_common/sqlite_api.dart';
import '../model/vendor.dart';

class VendorRepository {
  final Database _db;

  VendorRepository(this._db);

  /// Get all active and enabled vendors (not deleted and enabled)
  /// Used for Create Purchase screen where only enabled vendors should be selectable
  Future<List<Vendor>> getAllVendors() async {
    final result = await _db.rawQuery(
      'SELECT * FROM vendors WHERE is_deleted = 0 AND is_enabled = 1 ORDER BY name ASC',
    );
    return result.map((json) => Vendor.fromJson(json)).toList();
  }

  /// Get all vendors including disabled ones (not deleted)
  /// Used for Masters screen to show all vendors regardless of enabled status
  Future<List<Vendor>> getAllVendorsIncludingDisabled() async {
    final result = await _db.rawQuery(
      'SELECT * FROM vendors WHERE is_deleted = 0 ORDER BY name ASC',
    );
    return result.map((json) => Vendor.fromJson(json)).toList();
  }

  Future<Vendor?> getVendorById(int id) async {
    final result = await _db.rawQuery(
      'SELECT * FROM vendors WHERE id = ? AND is_deleted = 0',
      [id],
    );
    if (result.isEmpty) return null;
    return Vendor.fromJson(result.first);
  }

  Future<int> createVendor(Vendor vendor) async {
    return await _db.rawInsert(
      '''INSERT INTO vendors (name, legal_name, phone, email, gst_number,
         address_line1, address_line2, city, state, pincode, is_enabled, is_deleted, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, datetime('now'), datetime('now'))''',
      [
        vendor.name,
        vendor.legalName,
        vendor.phone,
        vendor.email,
        vendor.gstNumber,
        vendor.addressLine1,
        vendor.addressLine2,
        vendor.city,
        vendor.state,
        vendor.pincode,
        vendor.isEnabled ? 1 : 0,
      ],
    );
  }

  Future<void> updateVendor(Vendor vendor) async {
    await _db.rawUpdate(
      '''UPDATE vendors SET name = ?, legal_name = ?, phone = ?, email = ?,
         gst_number = ?, address_line1 = ?, address_line2 = ?, city = ?,
         state = ?, pincode = ?, is_enabled = ?, updated_at = datetime('now')
         WHERE id = ?''',
      [
        vendor.name,
        vendor.legalName,
        vendor.phone,
        vendor.email,
        vendor.gstNumber,
        vendor.addressLine1,
        vendor.addressLine2,
        vendor.city,
        vendor.state,
        vendor.pincode,
        vendor.isEnabled ? 1 : 0,
        vendor.id,
      ],
    );
  }

  Future<void> softDeleteVendor(int id) async {
    await _db.rawUpdate(
      'UPDATE vendors SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
      [id],
    );
  }

  Future<void> toggleVendorEnabled(int id, bool isEnabled) async {
    await _db.rawUpdate(
      'UPDATE vendors SET is_enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
      [isEnabled ? 1 : 0, id],
    );
  }

  Future<List<Vendor>> searchVendors(String query) async {
    final result = await _db.rawQuery(
      '''SELECT * FROM vendors
         WHERE is_deleted = 0
         AND (name LIKE ? OR legal_name LIKE ? OR phone LIKE ? OR email LIKE ?)
         ORDER BY name ASC''',
      ['%$query%', '%$query%', '%$query%', '%$query%'],
    );
    return result.map((json) => Vendor.fromJson(json)).toList();
  }
}
