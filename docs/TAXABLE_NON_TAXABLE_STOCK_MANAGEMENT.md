# Taxable & Non-Taxable Stock Management System

**Date Created:** January 15, 2025
**Status:** In Implementation
**Version:** 1.0

---

## 📋 Overview

The MotoBill system implements a **dual-track stock management** approach where products can have **separate inventory pools for taxable and non-taxable stock**. This allows for sophisticated inventory tracking based on the tax status of both purchases and sales.

### Core Concept

**The same product can exist in TWO separate stock pools:**
- 🟢 **Taxable Stock** - Stock purchased via taxable purchase bills
- 🟠 **Non-Taxable Stock** - Stock purchased via non-taxable purchase bills

This separation enables:
1. Accurate tax reporting and compliance
2. Flexible billing options (taxable or non-taxable sales)
3. Proper cost tracking per tax category
4. FIFO (First In First Out) within each stock category

---

## 🎯 Business Rules

### Rule 1: Purchase Determines Stock Category
When products are purchased, they are categorized based on the purchase bill type:

- **Taxable Purchase Bill** → Stock goes into **taxable stock pool**
- **Non-Taxable Purchase Bill** → Stock goes into **non-taxable stock pool**

**Example:**
```
Purchase A (Taxable):   5 units of Product_X → Taxable Stock = 5
Purchase B (Non-Taxable): 5 units of Product_X → Non-Taxable Stock = 5

Total Stock for Product_X:
├── Taxable Stock: 5 units
├── Non-Taxable Stock: 5 units
└── Total Available: 10 units
```

### Rule 2: Bill Type Determines Stock Deduction

#### ✅ Non-Taxable Bill (tax_amount = 0)
- **CAN use ALL available stock** (both taxable and non-taxable)
- Priority: Non-taxable stock first (FIFO), then taxable stock
- **Flexibility:** Maximum selling capacity

**Example:**
```
Available Stock:
├── Taxable Stock: 5 units
└── Non-Taxable Stock: 5 units

Creating Non-Taxable Bill for 10 units:
✅ SUCCESS - Uses all 10 units (5 non-taxable + 5 taxable)
```

#### ⚠️ Taxable Bill (tax_amount > 0)
- **CAN ONLY use taxable stock**
- **CANNOT use non-taxable stock**
- **Restricted:** Limited to taxable stock quantity only

**Example:**
```
Available Stock:
├── Taxable Stock: 5 units
└── Non-Taxable Stock: 5 units

Creating Taxable Bill for 10 units:
❌ FAIL - Only 5 taxable units available
✅ Can only sell up to 5 units in taxable bill

Creating Taxable Bill for 5 units:
✅ SUCCESS - Uses 5 taxable units
```

### Rule 3: Stock Validation at Bill Creation

**Before bill creation, system validates:**

```dart
// For Taxable Bills
if (billItem.taxAmount > 0) {
  // Can only use taxable stock
  availableStock = taxableStockForProduct

  if (requiredQty > availableStock) {
    if (product.negativeAllow == true) {
      // Create auto-purchase for shortage
      createAutoPurchase(shortage)
    } else {
      // Throw error - insufficient stock
      throw Exception("Insufficient taxable stock")
    }
  }
}

// For Non-Taxable Bills
if (billItem.taxAmount == 0) {
  // Can use both taxable and non-taxable stock
  availableStock = taxableStock + nonTaxableStock

  if (requiredQty > availableStock) {
    if (product.negativeAllow == true) {
      // Create auto-purchase for shortage
      createAutoPurchase(shortage)
    } else {
      // Throw error - insufficient stock
      throw Exception("Insufficient stock")
    }
  }
}
```

---

## 🗄️ Database Schema

### Tables Involved

#### 1. `stock_batches` Table
Stores individual stock batches with tax categorization:

```sql
CREATE TABLE stock_batches (
  id INTEGER PRIMARY KEY,
  product_id INTEGER NOT NULL,
  purchase_item_id INTEGER NOT NULL,
  batch_number TEXT NOT NULL,
  quantity_received INTEGER NOT NULL,
  quantity_remaining INTEGER NOT NULL,
  cost_price REAL NOT NULL,
  is_taxable INTEGER NOT NULL DEFAULT 1,  -- 🔑 KEY FIELD
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Key Field: `is_taxable`**
- `1` = Taxable stock (from taxable purchase)
- `0` = Non-taxable stock (from non-taxable purchase)

#### 2. `purchases` Table
```sql
CREATE TABLE purchases (
  id INTEGER PRIMARY KEY,
  purchase_number TEXT NOT NULL,
  vendor_id INTEGER NOT NULL,
  subtotal REAL NOT NULL,
  tax_amount REAL NOT NULL,
  total_amount REAL NOT NULL,
  is_taxable_bill INTEGER NOT NULL DEFAULT 1,  -- 🔑 Determines stock category
  is_auto_purchase INTEGER NOT NULL DEFAULT 0,
  source_bill_id INTEGER,
  -- ... other fields
);
```

#### 3. `bill_items` Table
```sql
CREATE TABLE bill_items (
  id INTEGER PRIMARY KEY,
  bill_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  tax_amount REAL NOT NULL,  -- 🔑 Determines which stock can be used
  -- ... other fields
);
```

#### 4. `stock_batch_usage` Table
Tracks which batches were used for each bill:

```sql
CREATE TABLE stock_batch_usage (
  id INTEGER PRIMARY KEY,
  bill_item_id INTEGER NOT NULL,
  stock_batch_id INTEGER NOT NULL,
  quantity_used INTEGER NOT NULL,
  cost_price REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

---

## 🔄 Stock Flow Lifecycle

### Phase 1: Purchase → Stock Creation

```
Purchase Bill Created
├── is_taxable_bill = 1 (Taxable)
│   └── stock_batches.is_taxable = 1
│
└── is_taxable_bill = 0 (Non-Taxable)
    └── stock_batches.is_taxable = 0
```

**Code Reference:** `lib/repository/purchase_repository.dart`
```dart
await txn.rawInsert(
  '''INSERT INTO stock_batches
  (product_id, purchase_item_id, batch_number, quantity_received,
  quantity_remaining, cost_price, is_taxable, created_at, updated_at)
  VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
  [
    item.productId,
    purchaseItemId,
    batchNumber,
    item.quantity,
    item.quantity,
    item.costPrice,
    purchase.isTaxableBill ? 1 : 0,  // ← Sets stock category
  ],
);
```

### Phase 2: Bill Creation → Stock Allocation

#### For Taxable Bills (tax_amount > 0)
```sql
-- Get ONLY taxable stock batches (FIFO order)
SELECT id, quantity_remaining, cost_price
FROM stock_batches
WHERE product_id = ?
  AND is_deleted = 0
  AND quantity_remaining > 0
  AND is_taxable = 1  -- ← Only taxable stock
ORDER BY id ASC  -- FIFO
```

#### For Non-Taxable Bills (tax_amount = 0)
```sql
-- Get ALL stock batches (FIFO order)
-- Priority: Non-taxable first, then taxable
SELECT id, quantity_remaining, cost_price, is_taxable
FROM stock_batches
WHERE product_id = ?
  AND is_deleted = 0
  AND quantity_remaining > 0
ORDER BY is_taxable ASC, id ASC  -- Non-taxable (0) first, then taxable (1)
```

### Phase 3: Stock Deduction
```dart
// Allocate stock using FIFO
for (final batch in batches) {
  if (remainingQty <= 0) break;

  final allocate = min(remainingQty, batch.quantityRemaining);

  // Deduct from stock batch
  await txn.rawUpdate(
    '''UPDATE stock_batches
       SET quantity_remaining = quantity_remaining - ?,
           updated_at = datetime('now')
       WHERE id = ?''',
    [allocate, batchId],
  );

  // Record usage
  await txn.rawInsert(
    '''INSERT INTO stock_batch_usage
       (bill_item_id, stock_batch_id, quantity_used, cost_price, created_at)
       VALUES (?, ?, ?, ?, datetime('now'))''',
    [billItemId, batchId, allocate, batchCostPrice],
  );

  remainingQty -= allocate;
}
```

---

## 📊 POS Display - Stock Visibility

### Product Card Shows Both Stock Types

**File:** `lib/view/widgets/pos/pos_product_card.dart`

```dart
// Display separate stock counts
Row(
  children: [
    // Taxable stock (green)
    if (product.taxableStock > 0)
      Text(
        'T:${product.taxableStock}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.green.shade700,
        ),
      ),
    // Non-taxable stock (orange)
    if (product.nonTaxableStock > 0)
      Text(
        'N:${product.nonTaxableStock}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.orange.shade700,
        ),
      ),
  ],
)
```

### Stock Query for POS

**File:** `lib/repository/pos_repository.dart`

```sql
SELECT
  p.id,
  p.name,
  -- Calculate separate stock counts
  COALESCE(SUM(sb.quantity_remaining), 0) as stock,
  COALESCE(SUM(CASE WHEN sb.is_taxable = 1 THEN sb.quantity_remaining ELSE 0 END), 0) as taxable_stock,
  COALESCE(SUM(CASE WHEN sb.is_taxable = 0 THEN sb.quantity_remaining ELSE 0 END), 0) as non_taxable_stock
FROM products p
LEFT JOIN stock_batches sb ON p.id = sb.product_id AND sb.is_deleted = 0
WHERE p.is_deleted = 0 AND p.is_enabled = 1
GROUP BY p.id
```

---

## 🧪 Test Scenarios

### Scenario 1: Purchase Creates Separate Stocks
```
Action: Create 2 purchases for Product_A
├── Purchase 1: Taxable, 5 units
└── Purchase 2: Non-Taxable, 5 units

Expected Result:
├── Taxable Stock: 5 units
├── Non-Taxable Stock: 5 units
└── Total Stock: 10 units

SQL Verification:
SELECT
  product_id,
  SUM(CASE WHEN is_taxable = 1 THEN quantity_remaining ELSE 0 END) as taxable,
  SUM(CASE WHEN is_taxable = 0 THEN quantity_remaining ELSE 0 END) as non_taxable
FROM stock_batches
WHERE product_id = ? AND is_deleted = 0
GROUP BY product_id;
```

### Scenario 2: Non-Taxable Bill Uses All Stock
```
Setup:
├── Taxable Stock: 5 units
└── Non-Taxable Stock: 5 units

Action: Create non-taxable bill for 10 units

Expected:
✅ Bill created successfully
✅ Uses 5 non-taxable units first (FIFO)
✅ Then uses 5 taxable units
✅ Remaining: 0 units

SQL Verification:
SELECT
  bi.product_name,
  bi.quantity as required,
  bu.quantity_used,
  sb.is_taxable,
  sb.quantity_remaining
FROM bill_items bi
LEFT JOIN stock_batch_usage bu ON bi.id = bu.bill_item_id
LEFT JOIN stock_batches sb ON bu.stock_batch_id = sb.id
WHERE bi.bill_id = ?
ORDER BY bu.id;
```

### Scenario 3: Taxable Bill Restricted to Taxable Stock
```
Setup:
├── Taxable Stock: 5 units
└── Non-Taxable Stock: 5 units

Action: Create taxable bill for 10 units

Expected:
❌ Error: "Insufficient taxable stock. Available: 5, Required: 10"

Action: Create taxable bill for 5 units

Expected:
✅ Bill created successfully
✅ Uses 5 taxable units only
✅ Non-taxable stock untouched
✅ Remaining: 5 non-taxable units

SQL Verification:
SELECT
  SUM(CASE WHEN is_taxable = 1 THEN quantity_remaining ELSE 0 END) as taxable,
  SUM(CASE WHEN is_taxable = 0 THEN quantity_remaining ELSE 0 END) as non_taxable
FROM stock_batches
WHERE product_id = ?
  AND is_deleted = 0;
```

### Scenario 4: Auto-Purchase with Negative Allow
```
Setup:
├── Taxable Stock: 2 units
├── Non-Taxable Stock: 0 units
└── Product.negative_allow = 1 (TRUE)

Action: Create taxable bill for 5 units

Expected:
✅ Bill created successfully
✅ Uses 2 existing taxable units
✅ Auto-purchase created for 3 units
✅ Auto-purchase is TAXABLE (matches bill type)
✅ New batch: 3 taxable units created

SQL Verification:
SELECT
  p.purchase_number,
  p.is_auto_purchase,
  p.is_taxable_bill,
  p.source_bill_id,
  pi.quantity,
  sb.is_taxable,
  sb.quantity_remaining
FROM purchases p
LEFT JOIN purchase_items pi ON p.id = pi.purchase_id
LEFT JOIN stock_batches sb ON pi.id = sb.purchase_item_id
WHERE p.is_auto_purchase = 1
ORDER BY p.id DESC
LIMIT 1;
```

---

## ⚠️ Current Implementation Status

### ✅ Implemented Features

1. **Stock Batch Creation with Tax Category**
   - ✅ `stock_batches.is_taxable` field exists
   - ✅ Set during purchase creation based on `purchases.is_taxable_bill`
   - ✅ Location: `lib/repository/purchase_repository.dart` (Line 116)

2. **POS Stock Display**
   - ✅ Shows separate taxable and non-taxable stock counts
   - ✅ Query calculates both stock types
   - ✅ Location: `lib/repository/pos_repository.dart` (Lines 43-44)

3. **Auto-Purchase System**
   - ✅ Creates dummy purchases for stock shortages
   - ✅ Respects `negative_allow` flag
   - ✅ Location: `lib/repository/bill_repository.dart` (Line 523+)

### 🚧 TODO: Missing Implementation

#### ❌ Stock Allocation Based on Bill Tax Type
**Current Issue:**
The `createBill()` method in `bill_repository.dart` does NOT filter stock batches by `is_taxable` status.

**Current Code (Line 167):**
```dart
final batches = await txn.rawQuery(
  '''SELECT id, quantity_remaining, cost_price
     FROM stock_batches
     WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
     ORDER BY id ASC''',  // ← Missing is_taxable filter!
  [it.productId],
);
```

**Required Fix:**
```dart
// Determine if this is a taxable bill item
final isTaxableBillItem = it.taxAmount > 0;

String stockQuery;
if (isTaxableBillItem) {
  // Taxable bill: ONLY use taxable stock
  stockQuery = '''SELECT id, quantity_remaining, cost_price, is_taxable
     FROM stock_batches
     WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
       AND is_taxable = 1
     ORDER BY id ASC''';
} else {
  // Non-taxable bill: Use ALL stock (non-taxable first, then taxable)
  stockQuery = '''SELECT id, quantity_remaining, cost_price, is_taxable
     FROM stock_batches
     WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
     ORDER BY is_taxable ASC, id ASC''';
}

final batches = await txn.rawQuery(stockQuery, [it.productId]);
```

#### ❌ Stock Availability Check
**Current Issue:**
The stock check (Line 88-93) only checks total stock, not separated by tax type.

**Current Code:**
```dart
final stockCheck = await txn.rawQuery(
  '''SELECT COALESCE(SUM(quantity_remaining), 0) as available
     FROM stock_batches
     WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0''',
  [it.productId],
);
```

**Required Fix:**
```dart
final isTaxableBillItem = it.taxAmount > 0;

String availabilityQuery;
if (isTaxableBillItem) {
  // Check only taxable stock
  availabilityQuery = '''SELECT COALESCE(SUM(quantity_remaining), 0) as available
     FROM stock_batches
     WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
       AND is_taxable = 1''';
} else {
  // Check all stock
  availabilityQuery = '''SELECT COALESCE(SUM(quantity_remaining), 0) as available
     FROM stock_batches
     WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0''';
}

final stockCheck = await txn.rawQuery(availabilityQuery, [it.productId]);
```

#### ❌ Auto-Purchase Tax Category
**Current Issue:**
Auto-purchases don't inherit the tax category from the originating bill item.

**Required Fix:**
In `_createAutoPurchaseForShortage()` method, add parameter for tax status:

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
  // ... existing code ...

  // Insert purchase with correct tax status
  final purchaseId = await txn.rawInsert(
    '''INSERT INTO purchases
    (purchase_number, vendor_id, subtotal, tax_amount, total_amount,
     is_auto_purchase, source_bill_id, is_taxable_bill, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?, ?)''',
    [
      purchaseNumber,
      autoStockVendorId,
      subtotal,
      0.0,
      totalAmount,
      sourceBillId,
      isTaxable ? 1 : 0,  // ← Set based on bill item
      now.toIso8601String(),
      now.toIso8601String(),
    ],
  );

  // ... rest of code ...

  // Stock batch will inherit tax status
  await txn.rawInsert(
    '''INSERT INTO stock_batches
    (product_id, purchase_item_id, batch_number, quantity_received,
    quantity_remaining, cost_price, is_taxable, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
    [productId, purchaseItemId, batchNumber, shortage, shortage, costPrice, isTaxable ? 1 : 0],
  );
}
```

---

## 📝 Implementation Checklist

### Phase 1: Core Stock Allocation ⚠️ HIGH PRIORITY
- [ ] **Modify `createBill()` method** in `bill_repository.dart`
  - [ ] Add logic to detect taxable vs non-taxable bill items
  - [ ] Filter stock batches based on `is_taxable` for taxable bills
  - [ ] Use all stock (non-taxable first) for non-taxable bills
  - [ ] Update stock availability check

### Phase 2: Auto-Purchase Enhancement
- [ ] **Update `_createAutoPurchaseForShortage()` method**
  - [ ] Add `isTaxable` parameter
  - [ ] Set `purchases.is_taxable_bill` correctly
  - [ ] Ensure stock batch inherits correct tax status
  - [ ] Pass tax status from bill item to auto-purchase

### Phase 3: Testing
- [ ] Test taxable bill with mixed stock (should use only taxable)
- [ ] Test non-taxable bill with mixed stock (should use all)
- [ ] Test auto-purchase for taxable bill creates taxable stock
- [ ] Test auto-purchase for non-taxable bill creates non-taxable stock
- [ ] Test FIFO order within each stock category
- [ ] Test error handling for insufficient taxable stock

### Phase 4: Documentation
- [ ] Update API documentation
- [ ] Create user guide with examples
- [ ] Add inline code comments
- [ ] Update database schema documentation

---

## 🎓 Key Takeaways

1. **Two Independent Stock Pools:** Taxable and non-taxable stock are managed separately
2. **Purchase Determines Category:** Stock category is set at purchase time based on `is_taxable_bill`
3. **Bill Type Determines Usage:** Taxable bills can only use taxable stock; non-taxable bills can use all
4. **FIFO Within Category:** Stock is consumed in FIFO order within its tax category
5. **Auto-Purchase Inherits Type:** Auto-generated purchases should match the bill item's tax type
6. **POS Shows Both:** Users see separate counts for better decision-making

---

## 🔗 Related Files

- `lib/repository/bill_repository.dart` - Bill creation and stock allocation
- `lib/repository/purchase_repository.dart` - Purchase creation and stock batch generation
- `lib/repository/pos_repository.dart` - POS product queries with stock counts
- `lib/model/pos_product.dart` - POS product model with tax-separated stock fields
- `lib/view/widgets/pos/pos_product_card.dart` - UI display of stock counts

---

## 📞 Contact & Support

For questions or clarifications about this system, refer to:
- Main project documentation: `README.md`
- Database schema: `.github/docs/DATABASE_SCHEMA.md`
- GitHub Copilot instructions: `.github/copilot-instructions.md`

---

**Last Updated:** January 15, 2025
**Document Version:** 1.0
**Next Review:** After Phase 1 implementation completion
