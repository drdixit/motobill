# Create Bill Screen - negative_allow Integration

## Overview
The "Create Bill" screen (Dashboard > Sales > Create Bill button) now properly integrates with the `negative_allow` flag validation. This screen shares the same bill creation logic as the POS screen, ensuring consistent behavior across the application.

## Location
**Path:** `lib/view/screens/dashboard/create_bill_screen.dart`

**Access:** Dashboard → Sales → Create Bill button

## Implementation

### Changes Made

#### 1. Added negative_allow to Product Query
```dart
final productListForBillProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    final db = await ref.watch(databaseProvider);
    return await db.rawQuery('''
      SELECT p.id, p.name, p.part_number, p.cost_price, p.selling_price,
             p.is_taxable, p.negative_allow,  -- ADDED
             h.code as hsn_code, u.code as uqc_code
      FROM products p
      LEFT JOIN hsn_codes h ON p.hsn_code_id = h.id
      LEFT JOIN uqcs u ON p.uqc_id = u.id
      WHERE p.is_deleted = 0 AND p.is_enabled = 1
      ORDER BY p.name
    ''');
  }
);
```

**Purpose:** Load negative_allow flag along with product data (though it's used by repository, not UI directly)

#### 2. Changed Error Display to AlertDialog
**Before:**
```dart
catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
  );
}
```

**After:**
```dart
catch (e) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Error Creating Bill'),
      content: Text(e.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

**Reason:** AlertDialog provides better visibility and consistency with POS screen

### Existing Implementation (Already Working)

#### Bill Creation Flow
```dart
final items = validRows.map((row) => row.toBillItem()).toList();
await repository.createBill(bill, items);
```

**This already uses `BillRepository.createBill()` which contains:**
- ✅ Stock availability check
- ✅ negative_allow flag validation
- ✅ Auto-purchase creation for allowed products
- ✅ Error throwing for disallowed products
- ✅ FIFO stock allocation
- ✅ Batch usage tracking
- ✅ Transaction safety

## How It Works

### Flow Diagram
```
User fills bill form in Create Bill Screen
         ↓
Clicks "Save Bill"
         ↓
Validation checks (customer, items, etc.)
         ↓
Calls: repository.createBill(bill, items)
         ↓
BillRepository.createBill() (shared with POS)
         ↓
For each item:
    Check stock availability
         ↓
    Insufficient stock?
         ↓
    Check product.negative_allow
         ↓
  = 1 (TRUE)                = 0 (FALSE)
         ↓                         ↓
Create auto-purchase         Throw Exception
         ↓                         ↓
Insert bill item            Rollback transaction
         ↓                         ↓
Allocate stock (FIFO)       Show error dialog
         ↓
Bill created successfully
         ↓
Show success message
         ↓
Navigate back to dashboard
```

## Behavior Examples

### Example 1: Product with negative_allow = 1
**Scenario:**
- Product: "Engine Oil" (negative_allow = 1)
- Available stock: 2 units
- Bill requires: 5 units

**Result:**
1. User fills form and clicks "Save Bill"
2. System detects shortage: 5 - 2 = 3 units
3. System creates auto-purchase for 3 units
4. Bill created successfully
5. Success message shown
6. Navigate back to dashboard

**User Experience:** Seamless - unaware of auto-purchase

### Example 2: Product with negative_allow = 0
**Scenario:**
- Product: "Brake Disc" (negative_allow = 0)
- Available stock: 1 unit
- Bill requires: 3 units

**Result:**
1. User fills form and clicks "Save Bill"
2. System detects shortage: 3 - 1 = 2 units
3. System checks negative_allow = 0 (not allowed)
4. Exception thrown: "Insufficient stock for Brake Disc. Available: 1, Required: 3"
5. **AlertDialog shown with error message**
6. User can click "OK" to close dialog
7. Bill NOT created
8. User remains on form to adjust

**User Experience:** Clear error message in dialog, can adjust and retry

### Example 3: Mixed Products in One Bill
**Scenario:**
- Row 1: "Oil Filter" (negative_allow = 1), Available: 0, Need: 10
- Row 2: "Air Filter" (negative_allow = 1), Available: 5, Need: 5
- Row 3: "Spark Plug" (negative_allow = 0), Available: 2, Need: 8

**Result:**
1. User fills form with 3 products
2. Clicks "Save Bill"
3. Processing:
   - Oil Filter: Create auto-purchase for 10 units ✅
   - Air Filter: Sufficient stock ✅
   - Spark Plug: Insufficient stock, negative_allow = 0 → **ERROR** ❌
4. **Transaction rolled back** (all or nothing)
5. **AlertDialog shown:** "Insufficient stock for Spark Plug. Available: 2, Required: 8"
6. User adjusts Spark Plug quantity to 2 or removes it
7. Saves again successfully

**User Experience:** One product blocks entire bill, clear error shown

## Features Inherited from BillRepository

### 1. Stock Validation
- Checks available stock for each product
- Compares with required quantity

### 2. negative_allow Flag Check
- Queries database for product's negative_allow flag
- Decides whether to create auto-purchase or throw error

### 3. Auto-Purchase Creation
- Creates dummy purchase with AUTO-STOCK-ADJUSTMENT vendor
- Purchase number format: AUTO-PUR-YYYYMMDD-XXX
- Flags: is_auto_purchase = 1, source_bill_id = bill.id
- Creates stock batch with shortage quantity

### 4. FIFO Stock Allocation
- Uses oldest stock first (First In, First Out)
- Allocates from multiple batches if needed
- Records batch usage for audit trail

### 5. Transaction Safety
- All operations in single transaction
- Rollback on any failure
- Maintains database consistency

### 6. Error Handling
- Clear error messages
- Shows affected product name
- Shows available vs required quantity

## UI Components

### Product Autocomplete
- Searches by product name or part number
- Auto-fills: HSN code, UQC, rate, tax rates
- Supports duplicate merging (same product + rate)

### Error Dialog
```
┌────────────────────────────────────────┐
│ Error Creating Bill                    │
├────────────────────────────────────────┤
│ Exception: Insufficient stock for      │
│ Brake Disc. Available: 1, Required: 3 │
│                                        │
│                            [OK]        │
└────────────────────────────────────────┘
```

### Success Message
```
Toast (SnackBar):
✓ Bill B12345678 created successfully!
```

## Testing Scenarios

### Test 1: Create Bill with negative_allow = 1 (Insufficient Stock)
**Setup:**
```sql
UPDATE products SET negative_allow = 1 WHERE id = 1;
-- Ensure product has 0 or low stock
```

**Steps:**
1. Open Create Bill screen
2. Select customer
3. Add product (id=1) with quantity > available
4. Click "Save Bill"

**Expected:**
- ✅ Bill created successfully
- ✅ Auto-purchase created
- ✅ Success message shown
- ✅ Navigate back to dashboard

**Verify:**
```sql
-- Check bill created
SELECT * FROM bills ORDER BY id DESC LIMIT 1;

-- Check auto-purchase
SELECT * FROM purchases WHERE is_auto_purchase = 1 ORDER BY id DESC LIMIT 1;

-- Check stock batch
SELECT * FROM stock_batches ORDER BY id DESC LIMIT 1;
```

### Test 2: Create Bill with negative_allow = 0 (Insufficient Stock)
**Setup:**
```sql
UPDATE products SET negative_allow = 0 WHERE id = 2;
-- Ensure product has 0 or low stock
```

**Steps:**
1. Open Create Bill screen
2. Select customer
3. Add product (id=2) with quantity > available
4. Click "Save Bill"

**Expected:**
- ❌ Error dialog shown
- ❌ Message: "Insufficient stock for [Product]. Available: X, Required: Y"
- ❌ Bill NOT created
- ❌ No auto-purchase created
- ❌ User remains on form

**Verify:**
```sql
-- Check no new bill
SELECT * FROM bills ORDER BY id DESC LIMIT 1;
-- (Should show old bill, not new one)

-- Check no auto-purchase
SELECT * FROM purchases WHERE is_auto_purchase = 1 ORDER BY id DESC LIMIT 1;
-- (Should show old or no auto-purchase)
```

### Test 3: Create Bill with Sufficient Stock
**Setup:**
```sql
-- Any product with sufficient stock
```

**Steps:**
1. Open Create Bill screen
2. Select customer
3. Add product with quantity <= available
4. Click "Save Bill"

**Expected:**
- ✅ Bill created successfully
- ✅ No auto-purchase created
- ✅ Stock deducted from existing batches
- ✅ Success message shown

**Verify:**
```sql
-- Check bill created
SELECT * FROM bills ORDER BY id DESC LIMIT 1;

-- Check no auto-purchase
SELECT COUNT(*) FROM purchases
WHERE is_auto_purchase = 1
AND created_at > datetime('now', '-1 minute');
-- Should be 0

-- Check stock deducted
SELECT * FROM stock_batch_usage ORDER BY id DESC LIMIT 5;
```

### Test 4: Create Bill with Multiple Products (Mixed)
**Setup:**
```sql
UPDATE products SET negative_allow = 1 WHERE id IN (1, 2);
UPDATE products SET negative_allow = 0 WHERE id = 3;
-- Product 1, 2: insufficient stock
-- Product 3: insufficient stock
```

**Steps:**
1. Open Create Bill screen
2. Add all 3 products with insufficient stock
3. Click "Save Bill"

**Expected:**
- ❌ Error dialog shown for Product 3
- ❌ Entire bill fails (transaction rollback)
- ❌ No auto-purchase created (even for Products 1, 2)
- ❌ User remains on form

## Comparison: POS Screen vs Create Bill Screen

| Feature | POS Screen | Create Bill Screen |
|---------|------------|-------------------|
| **Access** | Dashboard → POS | Dashboard → Sales → Create Bill |
| **Layout** | 3-panel (Filters, Products, Cart) | Single form with rows |
| **Product Selection** | Click products in grid | Autocomplete search |
| **Validation Logic** | Uses BillRepository | Uses BillRepository ✅ |
| **negative_allow** | Supported ✅ | Supported ✅ |
| **Auto-Purchase** | Creates when needed ✅ | Creates when needed ✅ |
| **Error Display** | AlertDialog | AlertDialog ✅ |
| **Stock Allocation** | FIFO ✅ | FIFO ✅ |
| **Batch Tracking** | Yes ✅ | Yes ✅ |

**Conclusion:** Both screens use the same underlying logic (BillRepository.createBill), ensuring consistent behavior.

## Benefits

1. **Consistency:** Same validation logic as POS screen
2. **No Code Duplication:** Reuses existing BillRepository
3. **Maintainability:** Changes to bill logic apply to both screens
4. **User Experience:** Clear error messages, seamless auto-purchase
5. **Data Integrity:** Transaction safety, proper stock tracking

## Files Involved

- ✅ `lib/view/screens/dashboard/create_bill_screen.dart` - Updated error display, added negative_allow to query
- ✅ `lib/repository/bill_repository.dart` - Contains validation logic (already implemented)
- ✅ `lib/model/product.dart` - Contains negativeAllow field (already implemented)

## Status

🟢 **FULLY INTEGRATED**

The Create Bill Screen now properly uses the negative_allow validation and auto-purchase creation through the shared BillRepository. No additional changes needed - it automatically benefits from the existing implementation.

---

**Integration Date:** October 14, 2025
**Feature:** negative_allow validation in Create Bill Screen
**Implementation:** Uses shared BillRepository (no new code needed)
**Status:** ✅ Complete and working
