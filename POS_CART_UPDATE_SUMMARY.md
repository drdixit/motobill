# POS Cart UI Update & Stock Management Issue

**Date:** October 13, 2025

## ✅ Completed: POS Cart UI Update

### Changes Made

Updated the POS cart to show products in a single line with the following editable/non-editable fields:

**Layout:**
```
[Product Name] | [Qty] | [Price] | [Tax] | [Total] | [Delete]
               editable  editable  fixed   editable
```

### Files Modified

#### 1. `lib/view/widgets/pos/pos_cart.dart`
- Updated `_buildCartItem()` method to show all fields in one horizontal line
- Added three editable textboxes:
  - **Quantity** - Editable (integers only)
  - **Single Price** - Editable (decimals allowed)
  - **Total** - Editable (decimals allowed)
- Added one non-editable field:
  - **Tax** - Read-only display
- Input validation: Only numeric characters allowed (no foreign characters)
  - Quantity: `FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))`
  - Price/Total: `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))`

#### 2. `lib/view_model/pos_viewmodel.dart`
- Added `updateCartItemPrice()` - Updates price and recalculates tax & total
- Added `updateCartItemTotal()` - Reverse calculates price from total
- Updated `updateCartItemQuantity()` - Now preserves custom price
- Updated `_createBillItem()` - Accepts optional `customPrice` parameter

### Features
- ✅ Real-time calculation on value change
- ✅ Tax recalculation when price/quantity changes
- ✅ Reverse calculation (total → price) when total is edited
- ✅ Proper rounding and decimal handling
- ✅ No foreign characters allowed in numeric fields
- ✅ Clean single-line UI

---

## ⚠️ CRITICAL ISSUE IDENTIFIED: Stock Management

### Problem: Bills Don't Update Stock Batches

**Location:** `lib/repository/bill_repository.dart` - `createBill()` method (lines 68-117)

**Current Implementation:**
```dart
Future<int> createBill(Bill bill, List<BillItem> items) async {
  return await _db.transaction((txn) async {
    // 1. Insert bill
    final billId = await txn.rawInsert(...);

    // 2. Insert bill_items
    for (final it in items) {
      await txn.rawInsert(...);
    }

    // ❌ MISSING: Stock batch updates
    return billId;
  });
}
```

### What's Missing

When a bill is created, the system **DOES NOT**:

1. ❌ Query available `stock_batches` (FIFO - oldest first)
2. ❌ Check if sufficient stock exists
3. ❌ Reduce `stock_batches.quantity_remaining`
4. ❌ Create `stock_batch_usage` records (for COGS tracking)
5. ❌ Prevent overselling

### Impact

- **Inventory Accuracy:** Stock levels never decrease when items are sold
- **Overselling Risk:** Can sell more items than available in stock
- **Financial Reporting:** Cannot calculate Cost of Goods Sold (COGS)
- **Profit Margins:** Cannot determine actual profit per sale
- **Credit Notes Broken:** Credit notes rely on `stock_batch_usage` records which don't exist
- **Audit Trail:** No way to track which batches were used for sales

### Comparison with Other Modules

| Module | Stock Update | Status |
|--------|--------------|--------|
| **Purchase** | ✅ Creates `stock_batches` | Working |
| **Bill (Sales)** | ❌ No stock update | **BROKEN** |
| **Credit Note** | ✅ Returns to `stock_batches` | Working (but relies on missing data) |
| **Debit Note** | ✅ Reduces `stock_batches` | Working |

### Required Fix

The `createBill()` method needs to implement FIFO stock allocation:

```dart
Future<int> createBill(Bill bill, List<BillItem> items) async {
  return await _db.transaction((txn) async {
    final billId = await txn.rawInsert(...);

    for (final it in items) {
      final billItemId = await txn.rawInsert(...);

      // ✅ ADD THIS: FIFO Stock Allocation
      final batches = await txn.rawQuery(
        '''SELECT id, quantity_remaining, cost_price
           FROM stock_batches
           WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
           ORDER BY created_at ASC''',  // FIFO
        [it.productId],
      );

      int remainingToAllocate = it.quantity;

      for (final batch in batches) {
        if (remainingToAllocate <= 0) break;

        final batchId = batch['id'] as int;
        final available = (batch['quantity_remaining'] as num).toInt();
        final allocate = remainingToAllocate > available ? available : remainingToAllocate;

        // Reduce batch quantity
        await txn.rawUpdate(
          'UPDATE stock_batches SET quantity_remaining = quantity_remaining - ? WHERE id = ?',
          [allocate, batchId],
        );

        // Record usage
        await txn.rawInsert(
          '''INSERT INTO stock_batch_usage
             (bill_item_id, stock_batch_id, quantity_used, cost_price, created_at)
             VALUES (?, ?, ?, ?, datetime('now'))''',
          [billItemId, batchId, allocate, batch['cost_price']],
        );

        remainingToAllocate -= allocate;
      }

      // ✅ Check if all quantity was allocated
      if (remainingToAllocate > 0) {
        throw Exception('Insufficient stock for ${it.productName}');
      }
    }

    return billId;
  });
}
```

### Database Tables Involved

**stock_batches**
```sql
CREATE TABLE stock_batches (
  id INTEGER PRIMARY KEY,
  product_id INTEGER NOT NULL,
  quantity_remaining INTEGER NOT NULL,  -- Must be reduced
  cost_price REAL NOT NULL,
  created_at TEXT NOT NULL
);
```

**stock_batch_usage** (Currently NEVER populated)
```sql
CREATE TABLE stock_batch_usage (
  id INTEGER PRIMARY KEY,
  bill_item_id INTEGER NOT NULL,
  stock_batch_id INTEGER NOT NULL,
  quantity_used INTEGER NOT NULL,
  cost_price REAL NOT NULL,
  created_at TEXT NOT NULL
);
```

### Testing Required After Fix

1. ☐ Create bill with sufficient stock
2. ☐ Verify `stock_batches.quantity_remaining` reduced
3. ☐ Verify `stock_batch_usage` records created
4. ☐ Test FIFO order (oldest batch used first)
5. ☐ Try creating bill with insufficient stock (should fail)
6. ☐ Test bill spanning multiple batches
7. ☐ Test credit note after fix (should work properly now)

### Priority

🚨 **CRITICAL** - This breaks the entire inventory management system and must be fixed before production use.

### Related Documentation

- See `STOCK_BATCH_ISSUE_REPORT.md` for detailed analysis
- Reference: `lib/repository/debit_note_repository.dart` for working stock reduction example
- Reference: `lib/repository/bill_repository.dart` lines 207-364 for credit note implementation

---

## Summary

✅ **POS Cart UI** - Fully functional with all requested features
❌ **Bill Creation** - Critical bug that needs immediate attention

**Next Steps:**
1. Review and approve UI changes
2. Implement stock batch fix in `bill_repository.dart`
3. Test thoroughly before using in production
