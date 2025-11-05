# Taxable/Non-Taxable Stock - Implementation TODO

**Priority:** 🔴 HIGH
**Estimated Time:** 2-4 hours
**Status:** Ready to implement

---

## 🎯 Problem Statement

Currently, the bill creation process does NOT respect the taxable/non-taxable stock separation. All stock is treated as available regardless of whether the bill item is taxable or not.

**What's Working:**
- ✅ Stock batches are created with `is_taxable` flag
- ✅ POS displays separate taxable/non-taxable stock counts
- ✅ Auto-purchase system exists

**What's Broken:**
- ❌ Taxable bills can use non-taxable stock (should be blocked)
- ❌ Stock availability check doesn't consider tax type
- ❌ Auto-purchases don't inherit correct tax type

---

## 🔧 Required Changes

### File: `lib/repository/bill_repository.dart`

#### Change 1: Update Stock Availability Check (Line ~88)

**Current Code:**
```dart
// First, check stock availability
final stockCheck = await txn.rawQuery(
  '''SELECT COALESCE(SUM(quantity_remaining), 0) as available
     FROM stock_batches
     WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0''',
  [it.productId],
);
```

**New Code:**
```dart
// First, check stock availability based on bill item tax type
final isTaxableBillItem = it.taxAmount > 0;

String availabilityQuery;
if (isTaxableBillItem) {
  // Taxable bill item: Check only taxable stock
  availabilityQuery = '''
    SELECT COALESCE(SUM(quantity_remaining), 0) as available
    FROM stock_batches
    WHERE product_id = ?
      AND is_deleted = 0
      AND quantity_remaining > 0
      AND is_taxable = 1
  ''';
} else {
  // Non-taxable bill item: Check all stock (both taxable and non-taxable)
  availabilityQuery = '''
    SELECT COALESCE(SUM(quantity_remaining), 0) as available
    FROM stock_batches
    WHERE product_id = ?
      AND is_deleted = 0
      AND quantity_remaining > 0
  ''';
}

final stockCheck = await txn.rawQuery(availabilityQuery, [it.productId]);
```

#### Change 2: Update Auto-Purchase Call (Line ~117)

**Current Code:**
```dart
if (negativeAllow) {
  // Product allows negative stock - create auto-purchase
  final shortage = it.quantity - availableQty;
  await _createAutoPurchaseForShortage(
    txn,
    billId,
    it.productId,
    it.productName,
    it.partNumber,
    it.hsnCode,
    it.uqcCode,
    it.costPrice,
    shortage,
  );
}
```

**New Code:**
```dart
if (negativeAllow) {
  // Product allows negative stock - create auto-purchase
  final shortage = it.quantity - availableQty;
  await _createAutoPurchaseForShortage(
    txn,
    billId,
    it.productId,
    it.productName,
    it.partNumber,
    it.hsnCode,
    it.uqcCode,
    it.costPrice,
    shortage,
    isTaxableBillItem,  // ← NEW PARAMETER: Pass tax type
  );
}
```

#### Change 3: Update Stock Batch Query (Line ~167)

**Current Code:**
```dart
// Get stock batches ordered by ID (oldest first)
final batches = await txn.rawQuery(
  '''SELECT id, quantity_remaining, cost_price
     FROM stock_batches
     WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
     ORDER BY id ASC''',
  [it.productId],
);
```

**New Code:**
```dart
// Get stock batches ordered by ID (oldest first), filtered by tax type
String stockQuery;
if (isTaxableBillItem) {
  // Taxable bill item: ONLY use taxable stock
  stockQuery = '''
    SELECT id, quantity_remaining, cost_price, is_taxable
    FROM stock_batches
    WHERE product_id = ?
      AND is_deleted = 0
      AND quantity_remaining > 0
      AND is_taxable = 1
    ORDER BY id ASC
  ''';
} else {
  // Non-taxable bill item: Use ALL stock
  // Priority: Non-taxable first (0), then taxable (1)
  stockQuery = '''
    SELECT id, quantity_remaining, cost_price, is_taxable
    FROM stock_batches
    WHERE product_id = ?
      AND is_deleted = 0
      AND quantity_remaining > 0
    ORDER BY is_taxable ASC, id ASC
  ''';
}

final batches = await txn.rawQuery(stockQuery, [it.productId]);
```

#### Change 4: Update Auto-Purchase Method Signature (Line ~523)

**Current Code:**
```dart
Future<void> _createAutoPurchaseForShortage(
  Transaction txn,
  int sourceBillId,
  int productId,
  String productName,
  String? partNumber,
  String? hsnCode,
  String? uqcCode,
  double costPrice,
  int shortage,
) async {
```

**New Code:**
```dart
Future<void> _createAutoPurchaseForShortage(
  Transaction txn,
  int sourceBillId,
  int productId,
  String productName,
  String? partNumber,
  String? hsnCode,
  String? uqcCode,
  double costPrice,
  int shortage,
  bool isTaxable,  // ← NEW PARAMETER
) async {
```

#### Change 5: Update Auto-Purchase Creation (Line ~575)

**Current Code:**
```dart
// Insert purchase
final purchaseId = await txn.rawInsert(
  '''INSERT INTO purchases
  (purchase_number, purchase_reference_number, purchase_reference_date,
  vendor_id, subtotal, tax_amount, total_amount, is_auto_purchase, source_bill_id,
  created_at, updated_at)
  VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)''',
  [
    purchaseNumber,
    null,
    null,
    autoStockVendorId,
    subtotal,
    0.0,
    totalAmount,
    sourceBillId,
    now.toIso8601String(),
    now.toIso8601String(),
  ],
);
```

**New Code:**
```dart
// Insert purchase with correct tax type
final purchaseId = await txn.rawInsert(
  '''INSERT INTO purchases
  (purchase_number, purchase_reference_number, purchase_reference_date,
  vendor_id, subtotal, tax_amount, total_amount, is_auto_purchase, source_bill_id,
  is_taxable_bill, created_at, updated_at)
  VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)''',
  [
    purchaseNumber,
    null,
    null,
    autoStockVendorId,
    subtotal,
    0.0,
    totalAmount,
    sourceBillId,
    isTaxable ? 1 : 0,  // ← NEW: Set tax type
    now.toIso8601String(),
    now.toIso8601String(),
  ],
);
```

#### Change 6: Update Stock Batch Creation (Line ~623)

**Current Code:**
```dart
await txn.rawInsert(
  '''INSERT INTO stock_batches
  (product_id, purchase_item_id, batch_number, quantity_received,
  quantity_remaining, cost_price, created_at, updated_at)
  VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
  [productId, purchaseItemId, batchNumber, shortage, shortage, costPrice],
);
```

**New Code:**
```dart
await txn.rawInsert(
  '''INSERT INTO stock_batches
  (product_id, purchase_item_id, batch_number, quantity_received,
  quantity_remaining, cost_price, is_taxable, created_at, updated_at)
  VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
  [
    productId,
    purchaseItemId,
    batchNumber,
    shortage,
    shortage,
    costPrice,
    isTaxable ? 1 : 0,  // ← NEW: Set tax type
  ],
);
```

---

## ✅ Testing Checklist

After implementing changes, run these tests:

### Test 1: Taxable Bill with Mixed Stock
```
Setup:
- Product: Test_Product_A
- Taxable Stock: 5 units
- Non-Taxable Stock: 5 units

Action: Create taxable bill for 10 units

Expected Result:
❌ Error: "Insufficient stock for Test_Product_A. Available: 5, Required: 10"
```

### Test 2: Taxable Bill Within Taxable Stock
```
Setup:
- Product: Test_Product_A
- Taxable Stock: 10 units
- Non-Taxable Stock: 5 units

Action: Create taxable bill for 10 units

Expected Result:
✅ Bill created successfully
✅ Uses 10 taxable units
✅ Non-taxable stock remains 5 units

SQL Check:
SELECT
  SUM(CASE WHEN is_taxable = 1 THEN quantity_remaining ELSE 0 END) as taxable,
  SUM(CASE WHEN is_taxable = 0 THEN quantity_remaining ELSE 0 END) as non_taxable
FROM stock_batches
WHERE product_id = ?;

Expected: taxable = 0, non_taxable = 5
```

### Test 3: Non-Taxable Bill Uses All Stock
```
Setup:
- Product: Test_Product_A
- Taxable Stock: 5 units
- Non-Taxable Stock: 3 units

Action: Create non-taxable bill for 8 units

Expected Result:
✅ Bill created successfully
✅ Uses 3 non-taxable units first (FIFO)
✅ Then uses 5 taxable units
✅ All stock consumed

SQL Check:
SELECT
  SUM(quantity_remaining)
FROM stock_batches
WHERE product_id = ?;

Expected: 0
```

### Test 4: Auto-Purchase Inherits Tax Type
```
Setup:
- Product: Test_Product_B (negative_allow = 1)
- Taxable Stock: 2 units
- Non-Taxable Stock: 0 units

Action: Create taxable bill for 5 units

Expected Result:
✅ Bill created successfully
✅ Uses 2 existing taxable units
✅ Auto-purchase created for 3 units
✅ Auto-purchase has is_taxable_bill = 1
✅ New stock batch has is_taxable = 1

SQL Check:
SELECT
  p.purchase_number,
  p.is_auto_purchase,
  p.is_taxable_bill,
  sb.is_taxable,
  sb.quantity_remaining
FROM purchases p
LEFT JOIN purchase_items pi ON p.id = pi.purchase_id
LEFT JOIN stock_batches sb ON pi.id = sb.purchase_item_id
WHERE p.is_auto_purchase = 1
ORDER BY p.id DESC
LIMIT 1;

Expected:
- is_auto_purchase = 1
- is_taxable_bill = 1
- is_taxable = 1
- quantity_remaining = 3
```

### Test 5: FIFO Order Within Category
```
Setup:
- Batch 1: Non-taxable, 3 units, created first
- Batch 2: Non-taxable, 2 units, created second
- Batch 3: Taxable, 4 units

Action: Create non-taxable bill for 6 units

Expected Result:
✅ Uses Batch 1 completely (3 units)
✅ Uses Batch 2 completely (2 units)
✅ Uses Batch 3 partially (1 unit)
✅ Batch 3 remaining: 3 units

SQL Check:
SELECT
  sbu.stock_batch_id,
  sbu.quantity_used,
  sb.is_taxable,
  sb.quantity_remaining
FROM stock_batch_usage sbu
LEFT JOIN stock_batches sb ON sbu.stock_batch_id = sb.id
WHERE sbu.bill_item_id = ?
ORDER BY sbu.id;
```

---

## 🚀 Implementation Steps

1. **Backup current code** (git commit)
2. **Make changes** in order (Change 1 through 6)
3. **Run dart format** on `bill_repository.dart`
4. **Test each scenario** from the checklist
5. **Verify SQL queries** match expectations
6. **Update documentation** with any findings
7. **Commit changes** with descriptive message

---

## 📋 Commit Message Template

```
feat: Implement taxable/non-taxable stock segregation in bill creation

- Add tax-aware stock availability checks
- Filter stock batches based on bill item tax type
- Taxable bills now only use taxable stock
- Non-taxable bills use all stock (non-taxable first)
- Auto-purchases inherit tax type from originating bill item
- Update stock batch queries with proper FIFO within tax categories

Fixes:
- Prevents taxable bills from using non-taxable stock
- Ensures accurate stock reporting per tax category
- Maintains proper FIFO order within each stock pool

Related: TAXABLE_NON_TAXABLE_STOCK_MANAGEMENT.md
```

---

## 🐛 Potential Edge Cases

1. **Mixed batches in FIFO**
   - Non-taxable bill with both stock types should consume non-taxable first
   - Test with multiple batches of same type

2. **Partial auto-purchase**
   - If 2 taxable units available, need 5, should create auto-purchase for 3
   - Verify both old and new stock are used correctly

3. **Zero stock scenarios**
   - Product with 0 taxable stock, 5 non-taxable stock
   - Taxable bill should fail (or auto-purchase if allowed)

4. **Multiple products in one bill**
   - Some taxable items, some non-taxable items
   - Each should use appropriate stock pool

---

## 📞 Questions to Consider

1. **Should auto-purchase always be taxable?**
   - Current approach: Inherit from bill item (recommended)
   - Alternative: Always non-taxable (simpler but less accurate)

2. **What if mixed bill (taxable + non-taxable items)?**
   - Current: Each item uses appropriate stock
   - This is correct behavior

3. **Should we show warning if taxable stock is low?**
   - Future enhancement: POS could warn "Only X taxable units available"
   - Not required for initial implementation

---

**Ready to implement?** Follow the changes above in order, test thoroughly, and update documentation!
