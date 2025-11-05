# Quick Reference: Taxable/Non-Taxable Stock System

**One-Page Summary for GitHub Copilot Context**

---

## 🎯 What This Is

A **dual-track inventory system** where products maintain separate stock pools based on whether they were purchased via taxable or non-taxable purchase bills.

---

## 📦 Two Stock Pools

### Same Product = Two Inventories

```
Product_A
├── 🟢 Taxable Stock: 10 units (from taxable purchases)
└── 🟠 Non-Taxable Stock: 5 units (from non-taxable purchases)
```

---

## 🔑 Key Rules

| Bill Type | Can Use Which Stock? | Example |
|-----------|---------------------|---------|
| **Taxable Bill**<br>(tax_amount > 0) | 🟢 **ONLY taxable stock** | Available: T:5, NT:10<br>Can sell: **Max 5 units** |
| **Non-Taxable Bill**<br>(tax_amount = 0) | 🟢🟠 **ALL stock**<br>(NT first, then T) | Available: T:5, NT:10<br>Can sell: **Max 15 units** |

---

## 🗄️ Database Key

### `stock_batches` Table
```sql
is_taxable INTEGER NOT NULL DEFAULT 1
```
- `1` = Taxable stock (from taxable purchase)
- `0` = Non-taxable stock (from non-taxable purchase)

Set during purchase creation from `purchases.is_taxable_bill`

---

## 🔄 Flow

### Purchase → Stock Creation
```
Taxable Purchase (is_taxable_bill = 1)
  → Creates stock_batches with is_taxable = 1

Non-Taxable Purchase (is_taxable_bill = 0)
  → Creates stock_batches with is_taxable = 0
```

### Bill Creation → Stock Usage
```
Taxable Bill Item (tax_amount > 0)
  → Query: WHERE is_taxable = 1
  → Uses ONLY taxable stock

Non-Taxable Bill Item (tax_amount = 0)
  → Query: (no filter on is_taxable)
  → Uses ALL stock (NT first via ORDER BY)
```

---

## ⚠️ Current Status

### ✅ Working
- Stock batches created with correct `is_taxable` flag
- POS displays separate T/NT stock counts
- Auto-purchase system exists

### ❌ Not Yet Implemented
- Stock queries don't filter by `is_taxable` ← **CRITICAL**
- Taxable bills can incorrectly use non-taxable stock
- Auto-purchases don't inherit tax type

---

## 🔧 Implementation Needed

**File:** `lib/repository/bill_repository.dart`

### 3 Key Changes:

1. **Stock availability check** (Line ~88)
   - If taxable bill item: Check only `WHERE is_taxable = 1`
   - If non-taxable bill item: Check all stock

2. **Stock allocation query** (Line ~167)
   - If taxable bill item: `WHERE is_taxable = 1 ORDER BY id ASC`
   - If non-taxable bill item: `ORDER BY is_taxable ASC, id ASC`

3. **Auto-purchase tax type** (Line ~523+)
   - Add `isTaxable` parameter to method
   - Set `purchases.is_taxable_bill` based on bill item
   - Set `stock_batches.is_taxable` accordingly

---

## 🧪 Test Case

```
Setup:
  Product_A: T:5, NT:5 (Total: 10)

Test 1 - Non-Taxable Bill for 10:
  ✅ SUCCESS - Uses all 10 (5 NT + 5 T)

Test 2 - Taxable Bill for 10:
  ❌ FAIL - Only 5 taxable available

Test 3 - Taxable Bill for 5:
  ✅ SUCCESS - Uses 5 taxable only
  Result: T:0, NT:5 (5 remaining)
```

---

## 📊 POS Display

```dart
// Shows both stock types
'T:${product.taxableStock}'      // Green
'N:${product.nonTaxableStock}'   // Orange
```

**Query calculates:**
```sql
SUM(CASE WHEN sb.is_taxable = 1 ...) as taxable_stock,
SUM(CASE WHEN sb.is_taxable = 0 ...) as non_taxable_stock
```

---

## 🎯 Business Value

1. **Compliance**: Accurate tax reporting per stock category
2. **Flexibility**: Non-taxable bills can use all inventory
3. **Control**: Taxable bills restricted to taxable stock only
4. **Transparency**: Users see both stock types in POS

---

## 📚 Full Documentation

- **Complete Guide**: `docs/TAXABLE_NON_TAXABLE_STOCK_MANAGEMENT.md`
- **Implementation TODO**: `docs/TAXABLE_STOCK_IMPLEMENTATION_TODO.md`
- **Visual Guide**: `docs/TAXABLE_STOCK_VISUAL_GUIDE.md`

---

## 💡 Remember

**The key concept**: When creating a bill, check the bill item's `tax_amount`:
- `tax_amount > 0` → Filter stock to `is_taxable = 1` only
- `tax_amount = 0` → Use all stock, non-taxable first

**Currently missing**: These filters in `bill_repository.dart` stock queries

---

**Use this as quick reference when implementing or debugging the taxable/non-taxable stock system.**
