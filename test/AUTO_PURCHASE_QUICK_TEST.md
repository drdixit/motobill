# Quick Start: Testing Auto-Purchase Feature

## What Was Implemented?
The system now **automatically creates dummy purchase bills** when selling products with insufficient stock. You can now create bills even when stock is low or zero!

## How It Works (Behind the Scenes)
```
You sell 4 units, only 1 available → System auto-creates purchase for 3 units → Bill created successfully!
```

## Quick Test (5 Minutes)

### Step 1: Check Current Stock
```sql
-- Check stock for a product
SELECT
  p.name,
  p.part_number,
  COALESCE(SUM(sb.quantity_remaining), 0) as available_stock
FROM products p
LEFT JOIN stock_batches sb ON p.id = sb.product_id AND sb.is_deleted = 0
WHERE p.id = 1  -- Change to any product ID
GROUP BY p.id;
```

### Step 2: Create Bill with Shortage
1. Open the running MotoBill app
2. Navigate to POS screen
3. Select any customer
4. Add a product to cart with quantity > available stock
   - Example: If product has 1 unit available, add 4 units to cart
5. Click "Create Bill"

### Step 3: Verify Success
Bill should be created without any error!

### Step 4: Verify Auto-Purchase Created
```sql
-- Check the auto-purchase was created
SELECT
  p.purchase_number,
  p.total_amount,
  v.name as vendor,
  p.created_at
FROM purchases p
LEFT JOIN vendors v ON p.vendor_id = v.id
WHERE p.is_auto_purchase = 1
ORDER BY p.created_at DESC
LIMIT 1;
```

You should see:
- Purchase number like: `AUTO-PUR-20250114-001`
- Vendor: `AUTO-STOCK-ADJUSTMENT`
- Recent timestamp

### Step 5: Verify Stock Batch Created
```sql
-- Check stock batch from auto-purchase
SELECT
  sb.batch_number,
  sb.quantity_received,
  sb.quantity_remaining,
  p.purchase_number
FROM stock_batches sb
LEFT JOIN purchase_items pi ON sb.purchase_item_id = pi.id
LEFT JOIN purchases p ON pi.purchase_id = p.id
WHERE p.is_auto_purchase = 1
ORDER BY sb.created_at DESC
LIMIT 1;
```

You should see a new stock batch with the shortage quantity.

### Step 6: Verify Bill Used the Stock
```sql
-- Check bill item allocation
SELECT
  bi.product_name,
  bi.quantity as required,
  bu.quantity_used,
  sb.batch_number,
  p.purchase_number,
  p.is_auto_purchase
FROM bill_items bi
LEFT JOIN stock_batch_usage bu ON bi.id = bu.bill_item_id
LEFT JOIN stock_batches sb ON bu.stock_batch_id = sb.id
LEFT JOIN purchase_items pi ON sb.purchase_item_id = pi.id
LEFT JOIN purchases p ON pi.purchase_id = p.id
WHERE bi.bill_id = (SELECT id FROM bills ORDER BY id DESC LIMIT 1)
ORDER BY bi.id, bu.id;
```

You should see:
- Stock used from existing batches (if any)
- Stock used from auto-purchase batch
- Total quantity matches required quantity

## Test Scenarios

### Scenario A: Zero Stock
- Product has 0 units
- Add 5 units to bill
- Result: Auto-purchase for 5 units created ✅

### Scenario B: Partial Stock
- Product has 1 unit
- Add 4 units to bill
- Result: Auto-purchase for 3 units created ✅

### Scenario C: Multiple Products
- Product A: 0 available, need 2
- Product B: 1 available, need 5
- Product C: 10 available, need 3
- Result:
  - Auto-purchase for 2 units of Product A ✅
  - Auto-purchase for 4 units of Product B ✅
  - No auto-purchase for Product C ✅

### Scenario D: Multiple Bills Same Day
- Create 3 bills with shortages
- Result: Sequential auto-purchase numbers:
  - AUTO-PUR-20250114-001
  - AUTO-PUR-20250114-002
  - AUTO-PUR-20250114-003 ✅

## What to Look For

### ✅ Success Indicators
- Bill creates without error
- Auto-purchase visible in purchases table
- Vendor shows as "AUTO-STOCK-ADJUSTMENT"
- Stock batch created with shortage quantity
- Bill uses stock from all batches (FIFO)
- Sequential purchase numbers

### ❌ Failure Indicators
- Bill creation throws error
- No auto-purchase created
- Stock batch not created
- Bill item allocation incomplete
- Purchase number conflicts

## Troubleshooting

### Problem: Vendor not found error
**Solution:** Verify vendor exists:
```sql
SELECT * FROM vendors WHERE name = 'AUTO-STOCK-ADJUSTMENT';
```
Should return id=7. If not, re-run vendor creation:
```sql
INSERT INTO vendors (name, legal_name, address, city, state, country, contact_person, email, is_enabled)
VALUES ('AUTO-STOCK-ADJUSTMENT', 'System Auto-Stock Adjustment', 'System Generated', 'N/A', 'N/A', 'N/A', 'System', 'system@motobill.local', 1);
```

### Problem: No auto-purchase created
**Solution:** Check if product actually had shortage:
```sql
-- Check available stock before bill
SELECT
  p.name,
  COALESCE(SUM(sb.quantity_remaining), 0) as available
FROM products p
LEFT JOIN stock_batches sb ON p.id = sb.product_id AND sb.is_deleted = 0
WHERE p.id = ?
GROUP BY p.id;
```

### Problem: Transaction rollback
**Solution:** Check error in app logs. Common causes:
- Database constraints
- Invalid data
- Concurrent access issues

## Database Views for Monitoring

### View All Auto-Purchases
```sql
CREATE VIEW IF NOT EXISTS v_auto_purchases AS
SELECT
  p.id,
  p.purchase_number,
  p.source_bill_id,
  b.bill_number,
  c.name as customer_name,
  p.total_amount,
  p.created_at
FROM purchases p
LEFT JOIN bills b ON p.source_bill_id = b.id
LEFT JOIN customers c ON b.customer_id = c.id
WHERE p.is_auto_purchase = 1
ORDER BY p.created_at DESC;

-- Usage
SELECT * FROM v_auto_purchases;
```

### View Auto-Purchase Details
```sql
CREATE VIEW IF NOT EXISTS v_auto_purchase_details AS
SELECT
  p.purchase_number,
  pi.product_name,
  pi.quantity,
  pi.cost_price,
  pi.total_amount,
  b.bill_number as source_bill,
  c.name as customer,
  p.created_at
FROM purchases p
LEFT JOIN purchase_items pi ON p.id = pi.purchase_id
LEFT JOIN bills b ON p.source_bill_id = b.id
LEFT JOIN customers c ON b.customer_id = c.id
WHERE p.is_auto_purchase = 1
ORDER BY p.created_at DESC;

-- Usage
SELECT * FROM v_auto_purchase_details;
```

## Performance Considerations

### For Large-Scale Testing
1. **Test with 100+ products**: Verify no performance degradation
2. **Test concurrent bills**: Multiple users creating bills simultaneously
3. **Test daily rollover**: Create bills on different days, verify numbering resets
4. **Test large quantities**: 1000+ units shortage, verify no issues

### Monitoring Queries
```sql
-- Count auto-purchases by date
SELECT
  DATE(created_at) as date,
  COUNT(*) as auto_purchase_count,
  SUM(total_amount) as total_amount
FROM purchases
WHERE is_auto_purchase = 1
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Top products with auto-purchases
SELECT
  pi.product_name,
  COUNT(*) as times_auto_purchased,
  SUM(pi.quantity) as total_auto_quantity,
  SUM(pi.total_amount) as total_auto_amount
FROM purchase_items pi
INNER JOIN purchases p ON pi.purchase_id = p.id
WHERE p.is_auto_purchase = 1
GROUP BY pi.product_id
ORDER BY times_auto_purchased DESC;
```

## Next Steps After Testing

1. ✅ Verify all test scenarios pass
2. ✅ Check database integrity
3. ✅ Monitor auto-purchase creation in production
4. ⏳ Consider adding UI notification (future)
5. ⏳ Consider adding toggle setting (future)
6. ⏳ Consider adding approval workflow (future)

## Summary

The auto-purchase feature is **fully implemented and ready to use**. The app is currently running on Windows. Test it by creating bills with products that have insufficient stock, and verify that auto-purchases are created automatically.

**Expected outcome**: Bills create successfully, auto-purchases appear in database, stock is properly allocated, and users experience seamless operation without manual stock management.
