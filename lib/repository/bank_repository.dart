import 'package:sqflite_common/sqlite_api.dart';
import '../model/bank.dart';

class BankRepository {
  final Database _db;
  BankRepository(this._db);

  Future<Bank?> getBankByCompanyId(int companyId) async {
    final result = await _db.rawQuery(
      'SELECT * FROM bank WHERE company_id = ? AND is_deleted = 0 LIMIT 1',
      [companyId],
    );
    if (result.isEmpty) return null;
    return Bank.fromJson(result.first);
  }

  Future<int> createBank(Bank bank) async {
    return await _db.rawInsert(
      '''INSERT INTO bank
         (account_holder_name, account_number, ifsc_code, bank_name, branch_name, customer_id, vendor_id, company_id, is_enabled, is_deleted, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, datetime('now'), datetime('now'))''',
      [
        bank.accountHolderName,
        bank.accountNumber,
        bank.ifscCode,
        bank.bankName,
        bank.branchName,
        bank.customerId,
        bank.vendorId,
        bank.companyId,
        bank.isEnabled ? 1 : 0,
      ],
    );
  }

  Future<void> updateBank(Bank bank) async {
    await _db.rawUpdate(
      '''UPDATE bank SET account_holder_name = ?, account_number = ?, ifsc_code = ?, bank_name = ?, branch_name = ?,
         customer_id = ?, vendor_id = ?, company_id = ?, is_enabled = ?, updated_at = datetime('now') WHERE id = ?''',
      [
        bank.accountHolderName,
        bank.accountNumber,
        bank.ifscCode,
        bank.bankName,
        bank.branchName,
        bank.customerId,
        bank.vendorId,
        bank.companyId,
        bank.isEnabled ? 1 : 0,
        bank.id,
      ],
    );
  }

  Future<void> softDeleteBank(int id) async {
    await _db.rawUpdate(
      "UPDATE bank SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?",
      [id],
    );
  }
}
