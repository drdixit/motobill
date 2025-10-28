# `bank` table

This document describes the `bank` table added to the MotoBill SQLite database.

## Purpose
The `bank` table stores bank account details used by customers, vendors or companies. It follows the project's soft-delete convention and contains references to `customers`, `vendors` and `companies` where applicable.

## Schema

CREATE TABLE statement used:

```sql
CREATE TABLE IF NOT EXISTS bank (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_holder_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  ifsc_code TEXT,
  bank_name TEXT,
  branch_name TEXT,
  customer_id INTEGER DEFAULT NULL,
  vendor_id INTEGER DEFAULT NULL,
  company_id INTEGER DEFAULT NULL,
  is_enabled INTEGER NOT NULL DEFAULT 1,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(customer_id) REFERENCES customers(id),
  FOREIGN KEY(vendor_id) REFERENCES vendors(id),
  FOREIGN KEY(company_id) REFERENCES companies(id)
);
```

## Columns

- `id` (INTEGER, PK): Auto-increment primary key.
- `account_holder_name` (TEXT, NOT NULL): Name printed on the bank account.
- `account_number` (TEXT, NOT NULL): Bank account number. Stored as TEXT to preserve leading zeros.
- `ifsc_code` (TEXT): Bank IFSC code.
- `bank_name` (TEXT): Name of the bank.
- `branch_name` (TEXT): Branch name or location.
- `customer_id` (INTEGER, NULLABLE): Optional FK to `customers(id)` — use when account belongs to a customer.
- `vendor_id` (INTEGER, NULLABLE): Optional FK to `vendors(id)` — use when account belongs to a vendor.
- `company_id` (INTEGER, NULLABLE): Optional FK to `companies(id)` — use when account belongs to a company.
- `is_enabled` (INTEGER, NOT NULL, DEFAULT 1): Flag indicating enabled/disabled (1 = enabled, 0 = disabled).
- `is_deleted` (INTEGER, NOT NULL, DEFAULT 0): Soft-delete flag (0 = active, 1 = deleted).
- `created_at` (TEXT, NOT NULL): Timestamp when the row was created. Defaults to current UTC time via `datetime('now')`.
- `updated_at` (TEXT, NOT NULL): Timestamp when the row was last updated. Defaults to current time; update this manually in application logic when row changes.

## Notes & Conventions

- Soft delete policy: Do not physically delete rows. Use `UPDATE bank SET is_deleted = 1 WHERE id = ?` to soft-delete and `UPDATE bank SET is_deleted = 0 WHERE id = ?` to restore.
- Boolean flags: `is_enabled` and `is_deleted` use `INTEGER` 0/1 values. Default enabled is `1`.
- Timestamps: SQLite does not auto-update `updated_at` on row updates; application code should set `updated_at = datetime('now')` when updating records.
- Foreign keys: The FK references assume `customers`, `vendors`, and `companies` tables exist with `id` primary keys. Foreign key enforcement depends on SQLite `PRAGMA foreign_keys = ON`; ensure repository uses parameterized queries.

## Example: Insert a dummy company bank account (already added programmatically)

```sql
INSERT INTO bank (account_holder_name, account_number, ifsc_code, bank_name, branch_name, company_id)
VALUES ('Demo Company Account', '000111222333', 'DEMO0000001', 'Demo Bank', 'Demo Branch', 1);
```

This inserts a row associated with `company_id = 1` and uses default values for `is_enabled` (1), `is_deleted` (0) and timestamps.

## Example: Query

- Select active bank accounts for a company:

```sql
SELECT * FROM bank
WHERE company_id = ? AND is_deleted = 0;
```

- Soft delete a bank account:

```sql
UPDATE bank SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;
```

## Suggested repository layer (brief)

- Create `lib/repository/bank_repository.dart` with methods:
  - `Future<int> insertBank(Bank bank)`
  - `Future<List<Bank>> getBanksForCompany(int companyId)`
  - `Future<Bank?> getBankById(int id)`
  - `Future<void> updateBank(Bank bank)` (update `updated_at` on write)
  - `Future<void> softDeleteBank(int id)`

Follow existing repository patterns in the project (parameterized queries, try-catch, return model objects).

---

If you'd like, I can also:
- Add a Dart model `lib/model/bank.dart` and a repository `lib/repository/bank_repository.dart` following your project's conventions.
- Add a small migration/seed script (if you prefer bundleable seeds) or a provider for bank repository.

Tell me if you want any of those next steps and I'll implement them.