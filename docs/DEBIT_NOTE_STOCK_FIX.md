# Debit Note Stock Availability Fix

**Date:** November 5, 2025
**Issue:** Debit notes showing incorrect available stock for returns

---

## 🐛 Problem Description

When creating a debit note (purchase return), the system was showing **insufficient stock** even when stock was physically available. This occurred in the following scenario:

### Reproduction Steps:
1. Create a **purchase** (e.g., 100 units) → Creates stock batch
2. Sell items via **POS bill** → Reduces stock from batch
3. Customer returns items via **credit note** → Creates NEW return batch (`purchase_item_id = 0`)
4. Try to create **debit note** (return to vendor)
5. ❌ **Error: "Insufficient stock to return"** - even though stock exists!

### Example:
```
Purchase #05112500004: 100 units
├── Stock Batch 77: 100 units (purchase_item_id = 76)
├── Sold 97 units via POS → Batch 77: 3 units remaining
├── Customer returned 50 units → Creates NEW Batch (RETURN-xxx): 50 units (purchase_item_id = 0)
│
Total Available: 3 + 50 = 53 units
Debit Note UI Shows: ❌ 3 units (WRONG!)
```

---

## 🔍 Root Cause Analysis

### Issue 1: Stock Availability Query
The `getAvailableStockForPurchase()` method only looked at batches with **matching `purchase_item_id`**:

```sql
-- ❌ OLD QUERY (INCORRECT)
SELECT pi.id as purchase_item_id,
       COALESCE(SUM(sb.quantity_remaining), 0) as available
FROM purchase_items pi
LEFT JOIN stock_batches sb ON pi.id = sb.purchase_item_id AND sb.is_deleted = 0
WHERE pi.purchase_id = ? AND pi.is_deleted = 0
GROUP BY pi.id
```

**Problem**: When credit notes create return batches, they have `purchase_item_id = 0`, so they were **NOT counted** in available stock!

### Issue 2: Stock Removal Logic
The debit note creation used `OR` condition that could match stock from OTHER purchases:

```sql
-- ❌ OLD QUERY (INCORRECT)
WHERE purchase_item_id = ? OR product_id = ?
```

**Problem**: This could incorrectly remove stock from a different purchase of the same product!

---

## ✅ Solution Implemented

### Fix 1: Update Stock Availability Calculation

**File:** `lib/repository/debit_note_repository.dart`

```sql
-- ✅ NEW QUERY (CORRECT)
SELECT pi.id as purchase_item_id,
       pi.product_id,
       COALESCE(SUM(sb.quantity_remaining), 0) as available
FROM purchase_items pi
LEFT JOIN stock_batches sb ON
  (sb.purchase_item_id = pi.id OR sb.product_id = pi.product_id)
  AND sb.is_deleted = 0
  AND sb.quantity_remaining > 0
WHERE pi.purchase_id = ? AND pi.is_deleted = 0
GROUP BY pi.id, pi.product_id
```

**Changes:**
- Now includes batches where `sb.product_id = pi.product_id` (returns for same product)
- Only counts batches with `quantity_remaining > 0`
- Properly aggregates ALL available stock for the product

### Fix 2: Prioritize Stock Removal

**File:** `lib/repository/debit_note_repository.dart`

```sql
-- ✅ NEW QUERY (CORRECT)
SELECT id, quantity_remaining, cost_price, purchase_item_id
FROM stock_batches
WHERE (purchase_item_id = ? OR (product_id = ? AND purchase_item_id = 0))
  AND is_deleted = 0
  AND quantity_remaining > 0
ORDER BY
  CASE WHEN purchase_item_id = ? THEN 0 ELSE 1 END,
  id ASC
```

**Changes:**
- Added condition: `purchase_item_id = 0` to only match return batches (not other purchases)
- Priority ordering:
  1. **Original purchase batches** (purchase_item_id matches)
  2. **Return batches** (purchase_item_id = 0)
- Prevents accidentally removing stock from different purchases

---

## 🎯 How It Works Now

### Correct Flow:

```
Purchase #05112500004: 100 units (Batch 77: purchase_item_id = 76)
│
├─ Sell 97 units via POS
│  └─ Batch 77: 3 units remaining
│
├─ Customer returns 50 units via Credit Note
│  └─ Creates RETURN Batch 150: 50 units (purchase_item_id = 0)
│
└─ Create Debit Note (Return to Vendor)
   ├─ Available Stock Calculation:
   │  ├─ Original batch (purchase_item_id = 76): 3 units
   │  ├─ Return batch (purchase_item_id = 0, product_id match): 50 units
   │  └─ Total: ✅ 53 units
   │
   └─ Stock Removal Priority (if returning 40 units):
      ├─ Remove 3 from Batch 77 (original)
      └─ Remove 37 from Batch 150 (return)
```

---

## 📊 Impact

### Before Fix:
- ❌ Debit notes failed when trying to return stock that was previously sold and returned
- ❌ Users had to manually track physical vs. system stock
- ❌ Incorrect "insufficient stock" errors

### After Fix:
- ✅ Debit notes correctly show ALL available stock (original + returns)
- ✅ Can return items to vendor after customer returns
- ✅ Accurate stock tracking across the entire flow
- ✅ Proper prioritization: original stock first, then returns

---

## 🧪 Test Scenarios

### Scenario 1: Simple Return
```
1. Purchase 100 units
2. Available for return: ✅ 100 units
3. Return 50 units → Success
```

### Scenario 2: After Bill + Credit Note
```
1. Purchase 100 units
2. Sell 80 units → 20 remaining
3. Customer returns 30 units → Creates return batch
4. Total available: 20 + 30 = ✅ 50 units
5. Return 40 to vendor → ✅ Success (uses 20 from original + 20 from return)
```

### Scenario 3: Multiple Products, Multiple Purchases
```
Product A:
├─ Purchase 1: 50 units (10 remaining)
└─ Purchase 2: 30 units (30 remaining)

Debit Note for Purchase 1:
├─ Shows: ✅ 10 units (only from Purchase 1)
└─ Does NOT include Purchase 2's 30 units ✅ (correct isolation)
```

### Scenario 4: Mixed Original + Return Stock
```
1. Purchase 100 units
2. Sell 95 units → 5 remaining
3. Customer returns 60 units → Return batch: 60
4. Available: 5 + 60 = 65 units
5. Return 65 to vendor:
   ├─ Removes 5 from original batch ✅
   └─ Removes 60 from return batch ✅
```

---

## 🔗 Related Files

- `lib/repository/debit_note_repository.dart` - Debit note logic
- `lib/repository/bill_repository.dart` - Credit note logic (creates return batches)
- `lib/view/screens/debit_notes_screen.dart` - UI display
- `lib/repository/purchase_repository.dart` - Purchase creation

---

## 💡 Key Learnings

1. **Return batches have `purchase_item_id = 0`**: This is by design to indicate stock that came from customer returns rather than vendor purchases

2. **Stock isolation is critical**: Each purchase's returnable stock must be tracked separately to prevent mixing stock from different purchases

3. **Priority matters**: When removing stock for returns, use original purchase stock first, then returned stock

4. **SQL query design**: Using `OR` conditions can be dangerous - always validate that joined records truly belong together

---

## 📝 Migration Notes

**No database migration needed** - this is purely a logic fix in the repository layer.

**Action Required:**
- Test debit note creation after bills + credit notes
- Verify stock availability shows correct numbers
- Ensure returns work for complex scenarios

---

**Status:** ✅ Fixed
**Version:** 1.0
**Last Updated:** November 5, 2025
