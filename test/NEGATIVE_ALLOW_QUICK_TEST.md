# Quick Test: negative_allow Flag

## What Was Implemented?
Added `negative_allow` flag to products table. This controls whether a product can trigger automatic purchase creation (negative stock) or must have sufficient stock before bill creation.

## Quick Setup

### Step 1: Enable negative_allow for Test Product
```sql
-- Enable negative_allow for product ID 1
UPDATE products SET negative_allow = 1 WHERE id = 1;

-- Check it was set
SELECT id, name, negative_allow FROM products WHERE id = 1;
```

### Step 2: Disable negative_allow for Another Product
```sql
-- Disable negative_allow for product ID 2
UPDATE products SET negative_allow = 0 WHERE id = 2;

-- Check it was set
SELECT id, name, negative_allow FROM products WHERE id = 2;
```

## Test Scenarios

### Test A: negative_allow = 1 (Allows Auto-Purchase)
**Setup:**
```sql
UPDATE products SET negative_allow = 1 WHERE id = 1;
```

**Steps:**
1. Open POS screen
2. Select customer
3. Add product (id=1) with quantity > available stock
4. Click "Create Bill"

**Expected Result:**
✅ Auto-purchase created for shortage
✅ Bill created successfully
✅ No error shown

**Verify:**
```sql
-- Check last auto-purchase
SELECT * FROM purchases
WHERE is_auto_purchase = 1
ORDER BY id DESC LIMIT 1;
```

### Test B: negative_allow = 0 (Blocks Bill Creation)
**Setup:**
```sql
UPDATE products SET negative_allow = 0 WHERE id = 2;
```

**Steps:**
1. Open POS screen
2. Select customer
3. Add product (id=2) with quantity > available stock
4. Click "Create Bill"

**Expected Result:**
❌ Error dialog shown
❌ Error message: "Insufficient stock for [Product]. Available: X, Required: Y"
❌ Bill NOT created
❌ No auto-purchase created

**Verify:**
```sql
-- Check no bill was created
SELECT * FROM bills ORDER BY id DESC LIMIT 1;
-- (Should not show new bill with current timestamp)
```

### Test C: Mixed Products - One Blocks Bill
**Setup:**
```sql
UPDATE products SET negative_allow = 1 WHERE id = 1;
UPDATE products SET negative_allow = 0 WHERE id = 2;
```

**Steps:**
1. Open POS screen
2. Add product 1 (negative_allow=1) with insufficient stock
3. Add product 2 (negative_allow=0) with insufficient stock
4. Click "Create Bill"

**Expected Result:**
❌ Error for product 2 (negative_allow=0)
❌ Entire bill fails (transaction rolled back)
❌ No auto-purchase created (even for product 1)

### Test D: Both Products Allow Negative
**Setup:**
```sql
UPDATE products SET negative_allow = 1 WHERE id IN (1, 2);
```

**Steps:**
1. Open POS screen
2. Add both products with insufficient stock
3. Click "Create Bill"

**Expected Result:**
✅ 2 auto-purchases created
✅ Bill created successfully

**Verify:**
```sql
-- Check auto-purchases
SELECT
  p.purchase_number,
  pi.product_name,
  pi.quantity
FROM purchases p
JOIN purchase_items pi ON p.id = pi.purchase_id
WHERE p.is_auto_purchase = 1
ORDER BY p.id DESC LIMIT 2;
```

## View Current Settings

### All Products with Their Stock Policy
```sql
SELECT
  id,
  name,
  part_number,
  cost_price,
  negative_allow,
  CASE negative_allow
    WHEN 1 THEN '✅ Auto-Purchase Enabled'
    ELSE '❌ Requires Sufficient Stock'
  END as policy
FROM products
WHERE is_deleted = 0
ORDER BY negative_allow DESC, name;
```

### Products Allowing Negative Stock
```sql
SELECT id, name, part_number, cost_price
FROM products
WHERE negative_allow = 1 AND is_deleted = 0;
```

### Products Requiring Sufficient Stock
```sql
SELECT id, name, part_number, cost_price
FROM products
WHERE negative_allow = 0 AND is_deleted = 0;
```

## Bulk Updates

### Enable for All Consumables
```sql
-- Example: Enable for products with "Oil" or "Filter" in name
UPDATE products
SET negative_allow = 1
WHERE (name LIKE '%Oil%' OR name LIKE '%Filter%')
AND is_deleted = 0;
```

### Enable for Low-Value Items
```sql
-- Enable for products under ₹1000
UPDATE products
SET negative_allow = 1
WHERE cost_price < 1000
AND is_deleted = 0;
```

### Disable for High-Value Items
```sql
-- Disable for products over ₹5000
UPDATE products
SET negative_allow = 0
WHERE cost_price > 5000
AND is_deleted = 0;
```

## Troubleshooting

### Issue: All bills are failing
**Cause:** Products have negative_allow = 0 (default)

**Solution:**
```sql
-- Enable negative_allow for products you want to allow auto-purchase
UPDATE products SET negative_allow = 1 WHERE id IN (1, 2, 3);
```

### Issue: Bills succeed but shouldn't
**Cause:** Product has negative_allow = 1

**Solution:**
```sql
-- Disable negative_allow for products requiring strict stock control
UPDATE products SET negative_allow = 0 WHERE id = 5;
```

### Issue: Mixed results in one bill
**Cause:** Some products allow negative, others don't

**Behavior:** Bill fails if ANY product with negative_allow=0 has insufficient stock

**Solution:** Either:
1. Enable negative_allow for all products in cart, OR
2. Ensure sufficient stock for products with negative_allow=0, OR
3. Remove products with insufficient stock from cart

## Recommended Settings

### Products to Enable (negative_allow = 1):
- Engine oil, brake fluid, coolant
- Air filters, oil filters
- Consumables and maintenance items
- Low-value spare parts
- Frequently restocked items

### Products to Disable (negative_allow = 0):
- Engines, transmissions, major components
- Electronics and electrical parts
- High-value items (>₹5000)
- Serialized products
- Items requiring physical verification
- Warranty-tracked items

## Current Status

✅ Database column added: `products.negative_allow`
✅ Product model updated with negativeAllow field
✅ Bill creation logic updated to check flag
✅ Default value: 0 (requires sufficient stock)
✅ Transaction safety maintained
✅ Error messages preserved for blocked bills
✅ Auto-purchase creation works for allowed products

## Summary

The `negative_allow` flag gives you control over which products can trigger automatic purchases:

- **0 (Default)**: Strict stock control - Bills blocked if insufficient
- **1**: Flexible stock - Auto-purchase created if insufficient

Choose based on your business needs for each product type!
