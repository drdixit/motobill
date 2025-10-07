import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/vehicle.dart';
import '../model/vehicle_type.dart';
import '../model/fuel_type.dart';

class VehicleRepository {
  final Database _db;

  VehicleRepository(this._db);

  Future<List<Vehicle>> getAllVehicles() async {
    final result = await _db.rawQuery('''
      SELECT * FROM vehicles
      WHERE is_deleted = 0
      ORDER BY name ASC
    ''');
    return result.map((json) => Vehicle.fromJson(json)).toList();
  }

  Future<Vehicle?> getVehicleById(int id) async {
    final result = await _db.rawQuery(
      'SELECT * FROM vehicles WHERE id = ? AND is_deleted = 0',
      [id],
    );
    if (result.isEmpty) return null;
    return Vehicle.fromJson(result.first);
  }

  Future<int> createVehicle(Vehicle vehicle) async {
    // Validate manufacturer_id exists
    final manufacturerCheck = await _db.rawQuery(
      'SELECT id FROM manufacturers WHERE id = ? AND is_deleted = 0',
      [vehicle.manufacturerId],
    );

    if (manufacturerCheck.isEmpty) {
      throw Exception('Invalid manufacturer ID');
    }

    // Validate vehicle_type_id exists
    final vehicleTypeCheck = await _db.rawQuery(
      'SELECT id FROM vehicle_types WHERE id = ? AND is_deleted = 0',
      [vehicle.vehicleTypeId],
    );

    if (vehicleTypeCheck.isEmpty) {
      throw Exception('Invalid vehicle type ID');
    }

    // Validate fuel_type_id exists
    final fuelTypeCheck = await _db.rawQuery(
      'SELECT id FROM fuel_types WHERE id = ? AND is_deleted = 0',
      [vehicle.fuelTypeId],
    );

    if (fuelTypeCheck.isEmpty) {
      throw Exception('Invalid fuel type ID');
    }

    return await _db.rawInsert(
      '''INSERT INTO vehicles
         (name, model_year, description, image, manufacturer_id,
          vehicle_type_id, fuel_type_id, is_enabled)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        vehicle.name,
        vehicle.modelYear,
        vehicle.description,
        vehicle.image,
        vehicle.manufacturerId,
        vehicle.vehicleTypeId,
        vehicle.fuelTypeId,
        vehicle.isEnabled ? 1 : 0,
      ],
    );
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    // Validate manufacturer_id exists
    final manufacturerCheck = await _db.rawQuery(
      'SELECT id FROM manufacturers WHERE id = ? AND is_deleted = 0',
      [vehicle.manufacturerId],
    );

    if (manufacturerCheck.isEmpty) {
      throw Exception('Invalid manufacturer ID');
    }

    // Validate vehicle_type_id exists
    final vehicleTypeCheck = await _db.rawQuery(
      'SELECT id FROM vehicle_types WHERE id = ? AND is_deleted = 0',
      [vehicle.vehicleTypeId],
    );

    if (vehicleTypeCheck.isEmpty) {
      throw Exception('Invalid vehicle type ID');
    }

    // Validate fuel_type_id exists
    final fuelTypeCheck = await _db.rawQuery(
      'SELECT id FROM fuel_types WHERE id = ? AND is_deleted = 0',
      [vehicle.fuelTypeId],
    );

    if (fuelTypeCheck.isEmpty) {
      throw Exception('Invalid fuel type ID');
    }

    await _db.rawUpdate(
      '''UPDATE vehicles
         SET name = ?, model_year = ?, description = ?, image = ?,
             manufacturer_id = ?, vehicle_type_id = ?, fuel_type_id = ?,
             is_enabled = ?, updated_at = datetime('now')
         WHERE id = ?''',
      [
        vehicle.name,
        vehicle.modelYear,
        vehicle.description,
        vehicle.image,
        vehicle.manufacturerId,
        vehicle.vehicleTypeId,
        vehicle.fuelTypeId,
        vehicle.isEnabled ? 1 : 0,
        vehicle.id,
      ],
    );
  }

  Future<void> softDeleteVehicle(int id) async {
    await _db.rawUpdate(
      'UPDATE vehicles SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
      [id],
    );
  }

  Future<void> toggleVehicleEnabled(int id, bool isEnabled) async {
    await _db.rawUpdate(
      'UPDATE vehicles SET is_enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
      [isEnabled ? 1 : 0, id],
    );
  }

  Future<List<Vehicle>> searchVehicles(String query) async {
    final result = await _db.rawQuery(
      '''SELECT * FROM vehicles
         WHERE is_deleted = 0 AND (name LIKE ? OR description LIKE ?)
         ORDER BY name ASC''',
      ['%$query%', '%$query%'],
    );
    return result.map((json) => Vehicle.fromJson(json)).toList();
  }

  Future<List<VehicleType>> getAllVehicleTypes() async {
    final result = await _db.rawQuery('''
      SELECT * FROM vehicle_types
      WHERE is_deleted = 0
      ORDER BY name ASC
    ''');
    return result.map((json) => VehicleType.fromJson(json)).toList();
  }

  Future<List<FuelType>> getAllFuelTypes() async {
    final result = await _db.rawQuery('''
      SELECT * FROM fuel_types
      WHERE is_deleted = 0
      ORDER BY name ASC
    ''');
    return result.map((json) => FuelType.fromJson(json)).toList();
  }
}
