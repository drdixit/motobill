# Taxable/Non-Taxable Stock System - Visual Guide

**Quick Reference for Understanding Stock Flow**

---

## 📊 Stock Pools Visualization

```
┌─────────────────────────────────────────────────┐
│              PRODUCT: Product_A                  │
│                  (id = 123)                      │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────────────────┐  ┌─────────────────┐ │
│  │  🟢 TAXABLE STOCK    │  │ 🟠 NON-TAXABLE  │ │
│  │      POOL            │  │    STOCK POOL   │ │
│  ├──────────────────────┤  ├─────────────────┤ │
│  │  Batch 1: 10 units   │  │ Batch 3: 5 units│ │
│  │  Batch 2: 15 units   │  │ Batch 4: 8 units│ │
│  ├──────────────────────┤  ├─────────────────┤ │
│  │  Total: 25 units     │  │ Total: 13 units │ │
│  └──────────────────────┘  └─────────────────┘ │
│                                                  │
│  📦 Total Stock Available: 38 units              │
└─────────────────────────────────────────────────┘
```

---

## 🔄 Purchase Flow

### Scenario A: Taxable Purchase
```
📋 Purchase Bill
├── Vendor: Vendor_A
├── is_taxable_bill: 1 (TRUE)
├── tax_amount: ₹450
└── Items:
    └── Product_A: 10 units @ ₹100

              ⬇️  CREATE

🗄️ Stock Batch Created
├── product_id: 123
├── quantity_received: 10
├── quantity_remaining: 10
├── cost_price: ₹100
└── is_taxable: 1  ← Goes to TAXABLE pool
```

### Scenario B: Non-Taxable Purchase
```
📋 Purchase Bill
├── Vendor: Vendor_B
├── is_taxable_bill: 0 (FALSE)
├── tax_amount: ₹0
└── Items:
    └── Product_A: 5 units @ ₹95

              ⬇️  CREATE

🗄️ Stock Batch Created
├── product_id: 123
├── quantity_received: 5
├── quantity_remaining: 5
├── cost_price: ₹95
└── is_taxable: 0  ← Goes to NON-TAXABLE pool
```

---

## 💳 Bill Creation Flow

### Flow A: Non-Taxable Bill (Flexible)

```
Available Stock:
┌─────────────────────┐
│ 🟢 Taxable: 25      │
│ 🟠 Non-Taxable: 13  │
│ 📦 Total: 38        │
└─────────────────────┘

Customer wants: 30 units
Bill type: Non-Taxable (tax_amount = 0)

              ⬇️  CHECK

✅ Available: 38 units ≥ Required: 30 units
✅ Can use BOTH pools

              ⬇️  ALLOCATE (FIFO)

Step 1: Use Non-Taxable first
├── Batch 3 (NT): 5 units → Used completely
├── Batch 4 (NT): 8 units → Used completely
└── Non-taxable depleted: 13 units used

Step 2: Use Taxable next
├── Batch 1 (T): 10 units → Used completely
├── Batch 2 (T): 7 units → Partial use
└── Taxable used: 17 units

Total allocated: 13 + 17 = 30 units ✅

              ⬇️  RESULT

Remaining Stock:
┌─────────────────────┐
│ 🟢 Taxable: 8       │
│ 🟠 Non-Taxable: 0   │
│ 📦 Total: 8         │
└─────────────────────┘
```

### Flow B: Taxable Bill (Restricted)

```
Available Stock:
┌─────────────────────┐
│ 🟢 Taxable: 25      │
│ 🟠 Non-Taxable: 13  │
│ 📦 Total: 38        │
└─────────────────────┘

Customer wants: 30 units
Bill type: Taxable (tax_amount > 0)

              ⬇️  CHECK

❌ Available TAXABLE: 25 units < Required: 30 units
⚠️  Can ONLY use taxable pool

              ⬇️  DECISION

If negative_allow = 0:
  ❌ Throw Error: "Insufficient taxable stock"

If negative_allow = 1:
  ✅ Create auto-purchase for shortage: 5 units

              ⬇️  AUTO-PURCHASE

📋 Auto-Purchase Created
├── purchase_number: AUTO-14012500001
├── is_auto_purchase: 1
├── is_taxable_bill: 1  ← Inherits from bill item
├── source_bill_id: 456
└── quantity: 5 units

              ⬇️  ALLOCATE

Step 1: Use existing taxable stock
├── Batch 1 (T): 10 units → Used completely
├── Batch 2 (T): 15 units → Used completely
└── Old stock used: 25 units

Step 2: Use new auto-purchase stock
└── Batch 5 (T, new): 5 units → Used completely

Total allocated: 25 + 5 = 30 units ✅

              ⬇️  RESULT

Remaining Stock:
┌─────────────────────┐
│ 🟢 Taxable: 0       │
│ 🟠 Non-Taxable: 13  │
│ 📦 Total: 13        │
└─────────────────────┘
```

---

## 🚫 Restriction Rules

### ❌ What CANNOT Happen

```
┌─────────────────────────────────────────────┐
│  TAXABLE BILL                                │
├─────────────────────────────────────────────┤
│  Required: 10 units                          │
│  Bill Item tax_amount: ₹180 (> 0)           │
│                                              │
│  Available Stock:                            │
│  ├── 🟢 Taxable: 3 units                    │
│  └── 🟠 Non-Taxable: 20 units               │
│                                              │
│        ⬇️  VALIDATION                        │
│                                              │
│  ❌ BLOCKED: Cannot use non-taxable stock   │
│  ❌ ERROR: Only 3 taxable units available   │
│                                              │
│  Options:                                    │
│  1. ✅ Reduce quantity to 3 units           │
│  2. ✅ If negative_allow, auto-purchase 7   │
│  3. ❌ Cannot proceed with 10 units as-is   │
└─────────────────────────────────────────────┘
```

### ✅ What CAN Happen

```
┌─────────────────────────────────────────────┐
│  NON-TAXABLE BILL                            │
├─────────────────────────────────────────────┤
│  Required: 10 units                          │
│  Bill Item tax_amount: ₹0 (= 0)             │
│                                              │
│  Available Stock:                            │
│  ├── 🟢 Taxable: 3 units                    │
│  └── 🟠 Non-Taxable: 20 units               │
│                                              │
│        ⬇️  VALIDATION                        │
│                                              │
│  ✅ ALLOWED: Can use ALL stock              │
│  ✅ Total: 23 units available               │
│                                              │
│  Allocation:                                 │
│  1. ✅ Use 10 non-taxable first             │
│  2. 🟠 Taxable untouched (3 remain)         │
│  3. 🟠 Non-taxable reduced to 10            │
└─────────────────────────────────────────────┘
```

---

## 🎨 POS Display

```
┌──────────────────────────────────────────┐
│  📦 Product Card                          │
│  ─────────────────────                   │
│                                           │
│  Product Name: Motor Oil 5W-30            │
│  Price: ₹450                              │
│                                           │
│  Stock Status:                            │
│  ┌────────────────────────────────────┐  │
│  │ 🟢 T:15  🟠 N:8  📦 Total: 23     │  │
│  └────────────────────────────────────┘  │
│     ↑        ↑          ↑                 │
│  Taxable  Non-Tax    Combined             │
│                                           │
└──────────────────────────────────────────┘

Legend:
🟢 T:15  = Taxable stock: 15 units
🟠 N:8   = Non-taxable stock: 8 units
📦 Total = Combined available: 23 units
```

---

## 🔢 Database Relationships

```
┌─────────────────────┐
│   purchases         │
├─────────────────────┤
│ id                  │
│ is_taxable_bill  ━━━┓
└─────────────────────┘ ┃
           │            ┃
           │ 1:N        ┃ Determines
           ↓            ┃ stock category
┌─────────────────────┐ ┃
│  purchase_items     │ ┃
├─────────────────────┤ ┃
│ id                  │ ┃
│ purchase_id         │ ┃
└─────────────────────┘ ┃
           │            ┃
           │ 1:1        ┃
           ↓            ┃
┌─────────────────────┐ ┃
│  stock_batches      │ ┃
├─────────────────────┤ ┃
│ id                  │ ┃
│ purchase_item_id    │ ┃
│ is_taxable  ◀━━━━━━━┛
│ quantity_remaining  │
└─────────────────────┘
           │
           │ N:N (via usage)
           ↓
┌─────────────────────┐
│ stock_batch_usage   │
├─────────────────────┤
│ bill_item_id        │
│ stock_batch_id      │
│ quantity_used       │
└─────────────────────┘
           │
           │ N:1
           ↓
┌─────────────────────┐
│   bill_items        │
├─────────────────────┤
│ id                  │
│ bill_id             │
│ tax_amount  ━━━━━━━┓
└─────────────────────┘ ┃
                        ┃ Determines
                        ┃ which stock
                        ┃ can be used
                        ↓
            ┌──────────────────────┐
            │ tax_amount > 0:      │
            │   Use ONLY taxable   │
            │                      │
            │ tax_amount = 0:      │
            │   Use ALL stock      │
            └──────────────────────┘
```

---

## 📈 Stock Movement Timeline

```
TIME ──────────────────────────────────────────────────▶

DAY 1: Purchase A (Taxable)
┌────────────────────┐
│ + 10 units (T)     │
└────────────────────┘
Stock: T:10, NT:0

DAY 2: Purchase B (Non-Taxable)
┌────────────────────┐
│ + 5 units (NT)     │
└────────────────────┘
Stock: T:10, NT:5

DAY 3: Bill #1 (Taxable) - Sell 7 units
┌────────────────────┐
│ - 7 units (T)      │
└────────────────────┘
Stock: T:3, NT:5
       └─ Used taxable only

DAY 4: Bill #2 (Non-Taxable) - Sell 6 units
┌────────────────────┐
│ - 5 units (NT)     │ First: Non-taxable
│ - 1 unit  (T)      │ Then: Taxable
└────────────────────┘
Stock: T:2, NT:0
       └─ Used non-taxable first, then taxable

DAY 5: Bill #3 (Taxable) - Attempt 5 units
┌────────────────────┐
│ Need: 5 units (T)  │
│ Have: 2 units (T)  │
│ ❌ Insufficient!   │
└────────────────────┘

If negative_allow = 1:
  Auto-purchase: 3 units (T)
  Stock: T:5, NT:0  → Bill succeeds

If negative_allow = 0:
  ❌ Bill fails
  Stock: T:2, NT:0  → No change
```

---

## 🔍 SQL Query Patterns

### Query 1: Get Separate Stock Counts
```sql
SELECT
  product_id,
  SUM(CASE WHEN is_taxable = 1 THEN quantity_remaining ELSE 0 END) as taxable_stock,
  SUM(CASE WHEN is_taxable = 0 THEN quantity_remaining ELSE 0 END) as non_taxable_stock,
  SUM(quantity_remaining) as total_stock
FROM stock_batches
WHERE product_id = ? AND is_deleted = 0
GROUP BY product_id;
```

### Query 2: Get Taxable Stock Only (for taxable bills)
```sql
SELECT id, quantity_remaining, cost_price
FROM stock_batches
WHERE product_id = ?
  AND is_deleted = 0
  AND quantity_remaining > 0
  AND is_taxable = 1  ← KEY FILTER
ORDER BY id ASC;  -- FIFO
```

### Query 3: Get All Stock (for non-taxable bills)
```sql
SELECT id, quantity_remaining, cost_price, is_taxable
FROM stock_batches
WHERE product_id = ?
  AND is_deleted = 0
  AND quantity_remaining > 0
ORDER BY is_taxable ASC, id ASC;  -- Non-taxable first, then FIFO
           ↑
           └─ 0 before 1, so non-taxable batches come first
```

---

## 🎯 Decision Tree

```
                    CREATE BILL ITEM
                          ↓
              ┌───────────────────────┐
              │  Check tax_amount     │
              └───────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            ↓                           ↓
    tax_amount > 0               tax_amount = 0
    (TAXABLE BILL)              (NON-TAXABLE BILL)
            │                           │
            ↓                           ↓
   ┌─────────────────┐         ┌─────────────────┐
   │ Check TAXABLE   │         │ Check ALL stock │
   │ stock only      │         │ (T + NT)        │
   └─────────────────┘         └─────────────────┘
            │                           │
     ┌──────┴──────┐           ┌────────┴────────┐
     ↓             ↓           ↓                 ↓
  Sufficient  Insufficient  Sufficient     Insufficient
     │             │           │                 │
     ↓             ↓           ↓                 ↓
   ✅ Use      Check         ✅ Use           Check
   taxable    negative       NT first,      negative
   stock      allow          then T          allow
     │             │           │                 │
     │      ┌──────┴──────┐   │          ┌──────┴──────┐
     │      ↓             ↓   │          ↓             ↓
     │   = 1           = 0    │       = 1           = 0
     │      │             │   │          │             │
     │      ↓             ↓   │          ↓             ↓
     │   Auto-        ❌       │      Auto-        ❌
     │   purchase     Error    │      purchase     Error
     │   taxable              │      (mixed)
     │   stock                │      stock
     │      │                 │          │
     └──────┴─────────────────┴──────────┘
            │
            ↓
    ✅ BILL CREATED
```

---

## 📚 Key Terms

- **🟢 Taxable Stock (T)**: Stock from taxable purchases (is_taxable = 1)
- **🟠 Non-Taxable Stock (NT)**: Stock from non-taxable purchases (is_taxable = 0)
- **FIFO**: First In First Out - oldest stock used first
- **Auto-Purchase**: System-generated purchase for stock shortages
- **negative_allow**: Product flag allowing sales below zero stock
- **Stock Pool**: Separate inventory category (taxable or non-taxable)

---

**Visual representations created to aid understanding of the taxable/non-taxable stock management system.**
