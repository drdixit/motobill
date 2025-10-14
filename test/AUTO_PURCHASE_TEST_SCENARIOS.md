# Auto-Purchase Feature Test Scenarios

## Feature Overview
When creating a bill, if any product has insufficient stock, the system automatically creates a dummy purchase bill for the shortage amount. This allows sales to proceed without manual stock management.

## Implementation Details
- **Auto-purchase vendor**: AUTO-STOCK-ADJUSTMENT (id=7)
- **Purchase number format**: AUTO-PUR-YYYYMMDD-XXX
- **Flags**: is_auto_purchase=1, source_bill_id=<bill_id>
- **Cost price**: Uses the cost_price from the bill item
- **Tax amounts**: Set to 0 for auto-purchases
- **Stock batches**: Created automatically with quantity = shortage

## Test Scenarios

### Scenario 1: Single Product with Partial Stock
**Setup:**
- Product: Product1
- Available stock: 1 unit
- Required in bill: 4 units
- Expected shortage: 3 units

**Expected Result:**
1. Auto-purchase created for 3 units of Product1
2. Purchase number: AUTO-PUR-20250114-001 (date will vary)
3. Vendor: AUTO-STOCK-ADJUSTMENT
4. Stock batch created with 3 units
5. Bill created successfully
6. Total stock after: 4 units (1 original + 3 auto-added)

**Verification Steps:**
- Check purchases table: is_auto_purchase=1, source_bill_id=<bill_id>
- Check stock_batches: New batch with 3 units
- Check bill creation: No error thrown
- Check batch_usage: Bill uses stock from all batches (FIFO)

### Scenario 2: Single Product with Zero Stock
**Setup:**
- Product: Product2
- Available stock: 0 units
- Required in bill: 5 units
- Expected shortage: 5 units

**Expected Result:**
1. Auto-purchase created for 5 units of Product2
2. Stock batch created with 5 units
3. Bill created successfully
4. Total stock after: 5 units (all from auto-purchase)

### Scenario 3: Multiple Products with Mixed Stock Levels
**Setup:**
- Product1: Available=3, Required=3 (sufficient)
- Product2: Available=1, Required=4 (shortage=3)
- Product3: Available=0, Required=2 (shortage=2)

**Expected Result:**
1. No auto-purchase for Product1 (sufficient stock)
2. Auto-purchase for 3 units of Product2
3. Auto-purchase for 2 units of Product3
4. Two separate auto-purchase bills created
5. Bill created successfully with all 3 products

**Verification Steps:**
- Check 2 auto-purchases created
- Both have same source_bill_id
- Sequential purchase numbers (001, 002)
- All products in bill have stock allocated

### Scenario 4: Product with Sufficient Stock
**Setup:**
- Product: Product1
- Available stock: 10 units
- Required in bill: 5 units

**Expected Result:**
1. No auto-purchase created
2. Bill created successfully using existing stock
3. Stock deducted from existing batches (FIFO)
4. No entries in purchases with is_auto_purchase=1

### Scenario 5: Multiple Bills on Same Day
**Setup:**
- Create 3 bills with shortages on the same day
- Each bill has 1 product with shortage

**Expected Result:**
1. Auto-purchase numbers increment properly:
   - AUTO-PUR-20250114-001
   - AUTO-PUR-20250114-002
   - AUTO-PUR-20250114-003
2. Each auto-purchase linked to correct source_bill_id
3. No number conflicts

### Scenario 6: Cost Price Variations
**Setup:**
- Product with default cost_price=100
- Create bill with custom cost_price=120

**Expected Result:**
1. Auto-purchase uses cost_price from bill item (120)
2. Stock batch created with cost_price=120
3. Purchase total amount = 120 × shortage quantity

### Scenario 7: Edge Case - Concurrent Bill Creation
**Setup:**
- Two users create bills simultaneously
- Both bills have same product with shortage
- Both require auto-purchase

**Expected Result:**
1. Both auto-purchases created successfully
2. Unique purchase numbers assigned
3. No transaction conflicts
4. Stock batches created for both

### Scenario 8: Large Quantity Shortage
**Setup:**
- Product with 0 stock
- Bill requires 1000 units

**Expected Result:**
1. Auto-purchase created for 1000 units
2. Stock batch with 1000 units
3. Bill created successfully
4. No performance issues

## Verification Queries

### Check Auto-Purchases
```sql
SELECT * FROM purchases
WHERE is_auto_purchase = 1
ORDER BY created_at DESC;
```

### Check Auto-Purchase Details
```sql
SELECT
  p.purchase_number,
  p.source_bill_id,
  b.bill_number,
  pi.product_name,
  pi.quantity,
  pi.cost_price,
  p.total_amount
FROM purchases p
LEFT JOIN bills b ON p.source_bill_id = b.id
LEFT JOIN purchase_items pi ON p.id = pi.purchase_id
WHERE p.is_auto_purchase = 1
ORDER BY p.created_at DESC;
```

### Check Stock Batches from Auto-Purchase
```sql
SELECT
  sb.*,
  pi.purchase_id,
  p.purchase_number,
  p.is_auto_purchase
FROM stock_batches sb
LEFT JOIN purchase_items pi ON sb.purchase_item_id = pi.id
LEFT JOIN purchases p ON pi.purchase_id = p.id
WHERE p.is_auto_purchase = 1
ORDER BY sb.created_at DESC;
```

### Check Bill Item Allocation
```sql
SELECT
  bi.bill_id,
  bi.product_name,
  bi.quantity as required_qty,
  bu.quantity_used,
  sb.batch_number,
  p.purchase_number,
  p.is_auto_purchase
FROM bill_items bi
LEFT JOIN stock_batch_usage bu ON bi.id = bu.bill_item_id
LEFT JOIN stock_batches sb ON bu.stock_batch_id = sb.id
LEFT JOIN purchase_items pi ON sb.purchase_item_id = pi.id
LEFT JOIN purchases p ON pi.purchase_id = p.id
WHERE bi.bill_id = ?
ORDER BY bi.id, bu.id;
```

## Manual Testing Checklist

- [ ] Scenario 1: Partial stock - 3 unit shortage
- [ ] Scenario 2: Zero stock - full shortage
- [ ] Scenario 3: Multiple products - mixed shortages
- [ ] Scenario 4: Sufficient stock - no auto-purchase
- [ ] Scenario 5: Multiple bills same day - sequential numbering
- [ ] Scenario 6: Custom cost price - uses bill item price
- [ ] Scenario 7: Concurrent creation - no conflicts
- [ ] Scenario 8: Large quantity - 1000 units

## Expected UI Behavior

### POS Screen
1. User adds products to cart
2. User clicks "Create Bill"
3. Bill number generated
4. Behind the scenes:
   - Stock checked for each product
   - Auto-purchases created for shortages (silent)
   - Bill created successfully
5. User sees success message
6. Cart cleared
7. User unaware of auto-purchase magic

### Purchase Reports
1. Auto-purchases visible in purchase list
2. Can be filtered by is_auto_purchase flag
3. Shows vendor: AUTO-STOCK-ADJUSTMENT
4. Shows source_bill_id link
5. Purchase number format: AUTO-PUR-YYYYMMDD-XXX

## Known Limitations

1. **No UI indicator**: User not notified about auto-purchases during bill creation
2. **Cost price source**: Uses bill item's cost price (not product's default)
3. **No tax breakdown**: Auto-purchases have 0 tax amounts
4. **Vendor hardcoded**: AUTO-STOCK-ADJUSTMENT (id=7) must exist
5. **No rollback on partial failure**: If auto-purchase creation fails, entire transaction rolls back

## Future Enhancements

1. Show notification when auto-purchase created
2. Add setting to enable/disable auto-purchase feature
3. Add option to use product's default cost_price vs bill item's cost_price
4. Add tax calculation for auto-purchases
5. Add UI to view/edit auto-purchases
6. Add report showing all auto-purchases with source bills
7. Add warning if auto-purchase would exceed certain threshold
