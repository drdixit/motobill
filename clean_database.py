import sqlite3
import time

# Connect to database with timeout
conn = sqlite3.connect(r'C:\motobill\database\motobill.db', timeout=10.0)
cursor = conn.cursor()

# Disable foreign keys
cursor.execute('PRAGMA foreign_keys = OFF')

# Delete all transactional data in correct order
tables_to_clean = [
    'debit_note_batch_returns',
    'debit_note_refunds',
    'debit_note_items',
    'debit_notes',
    'credit_note_batch_returns',
    'credit_note_refunds',
    'credit_note_items',
    'credit_notes',
    'stock_batch_usage',
    'purchase_payments',
    'purchase_items',
    'purchase_attachments',
    'purchases',
    'bill_payments',
    'bill_items',
    'bills',
    'stock_batches',
    'excel_uploads'
]

print("Cleaning database...")
for table in tables_to_clean:
    cursor.execute(f'DELETE FROM {table}')
    count = cursor.rowcount
    print(f"  Deleted {count} records from {table}")

# Re-enable foreign keys
cursor.execute('PRAGMA foreign_keys = ON')

# Commit changes
try:
    conn.commit()
    print("\n✅ Changes committed successfully!")
except sqlite3.OperationalError as e:
    print(f"\n❌ Error committing: {e}")
    print("   The database might be locked by the application.")
    print("   Please close the Flutter app and try again.")
    conn.rollback()
    conn.close()
    exit(1)

# Verify
print("\nVerification:")
verification_tables = [
    'bills', 'purchases', 'credit_notes', 'debit_notes',
    'stock_batches', 'bill_items', 'purchase_items'
]
for table in verification_tables:
    cursor.execute(f'SELECT COUNT(*) FROM {table}')
    count = cursor.fetchone()[0]
    print(f"  {table}: {count} records")

conn.close()
print("\n✅ Database cleaned successfully!")
