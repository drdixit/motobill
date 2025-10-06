import 'package:sqflite/sqflite.dart';
import '../model/customer.dart';

/// Repository for customer database operations
/// Handles all CRUD operations for customers table
class CustomerRepository {
  final Database _db;

  CustomerRepository(this._db);

  /// Get all active customers (not deleted)
  Future<List<Customer>> getAllCustomers() async {
    try {
      final result = await _db.rawQuery(
        'SELECT * FROM customers WHERE is_deleted = 0 ORDER BY name ASC',
      );
      return result.map((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch customers: $e');
    }
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(int id) async {
    try {
      final result = await _db.rawQuery(
        'SELECT * FROM customers WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (result.isEmpty) return null;
      return Customer.fromJson(result.first);
    } catch (e) {
      throw Exception('Failed to fetch customer: $e');
    }
  }

  /// Create new customer
  Future<int> createCustomer(Customer customer) async {
    try {
      final id = await _db.rawInsert(
        '''INSERT INTO customers (
          name, legal_name, phone, email, gst_number,
          address_line1, address_line2, city, state, pincode,
          is_enabled, is_deleted, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
        [
          customer.name,
          customer.legalName,
          customer.phone,
          customer.email,
          customer.gstNumber,
          customer.addressLine1,
          customer.addressLine2,
          customer.city,
          customer.state,
          customer.pincode,
          customer.isEnabled ? 1 : 0,
          customer.isDeleted ? 1 : 0,
        ],
      );
      return id;
    } catch (e) {
      throw Exception('Failed to create customer: $e');
    }
  }

  /// Update existing customer
  Future<void> updateCustomer(Customer customer) async {
    try {
      await _db.rawUpdate(
        '''UPDATE customers SET
          name = ?, legal_name = ?, phone = ?, email = ?, gst_number = ?,
          address_line1 = ?, address_line2 = ?, city = ?, state = ?, pincode = ?,
          is_enabled = ?, updated_at = datetime('now')
        WHERE id = ?''',
        [
          customer.name,
          customer.legalName,
          customer.phone,
          customer.email,
          customer.gstNumber,
          customer.addressLine1,
          customer.addressLine2,
          customer.city,
          customer.state,
          customer.pincode,
          customer.isEnabled ? 1 : 0,
          customer.id,
        ],
      );
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }

  /// Soft delete customer (set is_deleted = 1)
  Future<void> softDeleteCustomer(int id) async {
    try {
      await _db.rawUpdate(
        'UPDATE customers SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
        [id],
      );
    } catch (e) {
      throw Exception('Failed to delete customer: $e');
    }
  }

  /// Toggle customer enabled status
  Future<void> toggleCustomerEnabled(int id, bool isEnabled) async {
    try {
      await _db.rawUpdate(
        'UPDATE customers SET is_enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
        [isEnabled ? 1 : 0, id],
      );
    } catch (e) {
      throw Exception('Failed to toggle customer status: $e');
    }
  }

  /// Search customers by name or GST number
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final result = await _db.rawQuery(
        '''SELECT * FROM customers
        WHERE is_deleted = 0
        AND (name LIKE ? OR legal_name LIKE ? OR gst_number LIKE ? OR phone LIKE ?)
        ORDER BY name ASC''',
        ['%$query%', '%$query%', '%$query%', '%$query%'],
      );
      return result.map((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search customers: $e');
    }
  }
}
