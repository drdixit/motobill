import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/manufacturer.dart';

class ManufacturerRepository {
  final Database _db;

  ManufacturerRepository(this._db);

  Future<List<Manufacturer>> getAllManufacturers() async {
    final result = await _db.rawQuery('''
      SELECT * FROM manufacturers
      WHERE is_deleted = 0
      ORDER BY name ASC
    ''');
    return result.map((json) => Manufacturer.fromJson(json)).toList();
  }

  Future<Manufacturer?> getManufacturerById(int id) async {
    final result = await _db.rawQuery(
      'SELECT * FROM manufacturers WHERE id = ? AND is_deleted = 0',
      [id],
    );
    if (result.isEmpty) return null;
    return Manufacturer.fromJson(result.first);
  }

  Future<int> createManufacturer(Manufacturer manufacturer) async {
    return await _db.rawInsert(
      '''INSERT INTO manufacturers
         (name, description, image, is_enabled)
         VALUES (?, ?, ?, ?)''',
      [
        manufacturer.name,
        manufacturer.description,
        manufacturer.image,
        manufacturer.isEnabled ? 1 : 0,
      ],
    );
  }

  Future<void> updateManufacturer(Manufacturer manufacturer) async {
    await _db.rawUpdate(
      '''UPDATE manufacturers
         SET name = ?, description = ?, image = ?, is_enabled = ?,
             updated_at = datetime('now')
         WHERE id = ?''',
      [
        manufacturer.name,
        manufacturer.description,
        manufacturer.image,
        manufacturer.isEnabled ? 1 : 0,
        manufacturer.id,
      ],
    );
  }

  Future<void> softDeleteManufacturer(int id) async {
    await _db.rawUpdate(
      'UPDATE manufacturers SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
      [id],
    );
  }

  Future<void> toggleManufacturerEnabled(int id, bool isEnabled) async {
    await _db.rawUpdate(
      'UPDATE manufacturers SET is_enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
      [isEnabled ? 1 : 0, id],
    );
  }

  Future<List<Manufacturer>> searchManufacturers(String query) async {
    final result = await _db.rawQuery(
      '''SELECT * FROM manufacturers
         WHERE is_deleted = 0 AND (name LIKE ? OR description LIKE ?)
         ORDER BY name ASC''',
      ['%$query%', '%$query%'],
    );
    return result.map((json) => Manufacturer.fromJson(json)).toList();
  }
}
