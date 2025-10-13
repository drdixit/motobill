# Stock Batch Management Issue Report

**Date:** October 13, 2025
**Issue Type:** Critical - Data Integrity
**Affected Module:** Sales/Bills Module

## Executive Summary

The Bill (Sales Invoice) creation is **NOT properly updating stock batches**. When a sale is made, the system does not:
1. Reduce inventory from `stock_batches.quantity_remaining`
2. Create `stock_batch_usage` records to track FIFO (First In First Out) consumption

This means:
- ❌ Stock levels remain unchanged after sales
- ❌ No FIFO tracking for cost of goods sold (COGS)
- ❌ Cannot calculate profit margins
- ❌ Inventory reports will be incorrect
- ❌ Credit notes cannot properly return stock (depends on stock_batch_usage)

## Modules Analysis

### ✅ **Purchase Creation - WORKING CORRECTLY**
**File:** `lib/repository/purchase_repository.dart`

When a purchase is created:
- ✓ Creates `stock_batches` records with full quantity
- ✓ Sets `quantity_received` and `quantity_remaining`
- ✓ Stores cost_price for FIFO tracking

### ❌ **Bill Creation (Sales) - BROKEN**
**File:** `lib/repository/purchase_repository.dart` - Line 68-117

**Current Implementation:**
```dart
Future<int> createBill(Bill bill, List<BillItem> items) async {
  return await _db.transaction((txn) async {
    // Insert bill
    final billId = await txn.rawInsert(...);

    // Insert bill_items
    for (final it in items) {
      await txn.rawInsert(
        'INSERT INTO bill_items ...',
        [...]
      );
    }

    return billId;
  });
}
```

**MISSING:**
1. No stock batch lookup (FIFO - oldest first)
2. No reduction of `quantity_remaining`
3. No creation of `stock_batch_usage` records

### ✅ **Credit Notes (Sales Returns) - WORKING CORRECTLY**
**File:** `lib/repository/bill_repository.dart` - Line 207-364

When credit note is created:
- ✓ Validates quantities against original bill
- ✓ Retrieves `stock_batch_usage` records from original bill
- ✓ Adds quantity back to `stock_batches.quantity_remaining`
- ✓ Creates `credit_note_batch_returns` records
- ✓ Creates new batch if needed for excess returns

**Issue:** This relies on `stock_batch_usage` records which are NOT being created during bill creation!

### ✅ **Debit Notes (Purchase Returns) - WORKING CORRECTLY**
**File:** `lib/repository/debit_note_repository.dart` - Line 62-207

When debit note is created:
- ✓ Validates quantities against original purchase
- ✓ Reduces `stock_batches.quantity_remaining` using FIFO (oldest first)
- ✓ Creates `debit_note_batch_returns` records
- ✓ Handles multiple batches if needed

## Required Fix for Bill Creation

### Implementation Steps

The `createBill` method needs to be updated to:

1. **After inserting each bill_item**, implement FIFO stock deduction:

```dart
// Get available stock batches for this product (FIFO - oldest first)
final batches = await txn.rawQuery(
  '''SELECT id, quantity_remaining, cost_price
     FROM stock_batches
     WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
     ORDER BY created_at ASC''',  // FIFO: oldest first
  [it.productId],
);

int remainingToAllocate = it.quantity;

for (final batch in batches) {
  if (remainingToAllocate <= 0) break;

  final batchId = batch['id'] as int;
  final available = (batch['quantity_remaining'] as num).toInt();
  final costPrice = (batch['cost_price'] as num).toDouble();

  if (available <= 0) continue;

  final allocate = remainingToAllocate > available
      ? available
      : remainingToAllocate;

  // 1. Reduce batch quantity
  await txn.rawUpdate(
    '''UPDATE stock_batches
       SET quantity_remaining = quantity_remaining - ?,
           updated_at = datetime('now')
       WHERE id = ?''',
    [allocate, batchId],
  );

  // 2. Record usage
  await txn.rawInsert(
    '''INSERT INTO stock_batch_usage
       (bill_item_id, stock_batch_id, quantity_used, cost_price, created_at)
       VALUES (?, ?, ?, ?, datetime('now'))''',
    [billItemId, batchId, allocate, costPrice],
  );

  remainingToAllocate -= allocate;
}

// 3. Check if all quantity was allocated
if (remainingToAllocate > 0) {
  throw Exception(
    'Insufficient stock for product ${it.productName}. '
    'Required: ${it.quantity}, Available: ${it.quantity - remainingToAllocate}'
  );
}
```

2. **Add stock validation BEFORE creating bill**:
- Check if sufficient stock exists for all products
- Prevent overselling

3. **Update bill_items to store billItemId**:
```dart
final billItemId = await txn.rawInsert(
  'INSERT INTO bill_items ...',
  [...]
);

// Then use billItemId in stock_batch_usage
```

## Database Schema Reference

### stock_batches
```sql
CREATE TABLE stock_batches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL,
  purchase_item_id INTEGER NOT NULL,
  batch_number TEXT NOT NULL UNIQUE,
  quantity_received INTEGER NOT NULL,
  quantity_remaining INTEGER NOT NULL,  -- THIS needs to be reduced on sale
  cost_price REAL NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### stock_batch_usage (Currently NOT populated)
```sql
CREATE TABLE stock_batch_usage (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_item_id INTEGER NOT NULL,
  stock_batch_id INTEGER NOT NULL,
  quantity_used INTEGER NOT NULL,
  cost_price REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

## Impact Analysis

### Current State (Broken)
- Bills are created
- Bill items are recorded
- **Stock batches unchanged** ❌
- **No FIFO tracking** ❌
- Credit notes will fail to return stock properly ❌

### After Fix
- Bills are created
- Bill items are recorded
- **Stock batches reduced (FIFO)** ✅
- **Stock batch usage tracked** ✅
- **COGS calculated** ✅
- **Profit margins calculable** ✅
- Credit notes work correctly ✅
- Accurate inventory reports ✅

## Testing Checklist

After implementing the fix, test:

1. ☐ Create bill with single product
   - Verify stock_batches.quantity_remaining reduced
   - Verify stock_batch_usage record created

2. ☐ Create bill with multiple products
   - Verify all products' stock reduced
   - Verify multiple stock_batch_usage records

3. ☐ Create bill that spans multiple batches
   - Verify FIFO order (oldest batch used first)
   - Verify multiple batches reduced correctly

4. ☐ Try to create bill with insufficient stock
   - Should throw error with clear message
   - No partial updates to database

5. ☐ Create credit note after fix
   - Should now work properly with stock_batch_usage
   - Verify stock added back correctly

## Priority

**CRITICAL - HIGH PRIORITY**

This issue affects:
- Data integrity
- Inventory accuracy
- Financial reporting (COGS, profit margins)
- Customer returns processing

## Recommended Action

1. **Immediate:** Implement the fix in `bill_repository.dart`
2. **Testing:** Run comprehensive tests on test database
3. **Data Migration:** If bills already exist without stock_batch_usage:
   - May need to retroactively create stock_batch_usage records
   - Or mark existing bills as "pre-migration" and exclude from stock reports
4. **Documentation:** Update API documentation and user guide

## Files to Modify

1. **lib/repository/bill_repository.dart**
   - Method: `createBill()`
   - Add: Stock batch FIFO allocation logic
   - Add: Stock batch usage recording
   - Add: Stock validation

2. **lib/view_model/** (if needed)
   - Add stock validation before allowing bill creation
   - Show available stock to user

3. **lib/view/screens/dashboard/create_bill_screen.dart** (if needed)
   - Display available stock per product
   - Prevent adding more quantity than available

## Related Documentation

- `.github/docs/DATABASE_SCHEMA.md` - Lines 1381-1520 (stock_batches)
- `.github/docs/DATABASE_SCHEMA.md` - Lines 1528-1677 (stock_batch_usage)
- `lib/repository/debit_note_repository.dart` - Reference implementation for stock reduction
- `lib/repository/bill_repository.dart` - Credit note implementation (depends on fix)

---

**Report Generated:** $(date)
**Severity:** CRITICAL
**Status:** NEEDS IMMEDIATE ATTENTION
