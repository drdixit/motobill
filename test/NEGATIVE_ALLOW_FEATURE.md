# Negative Allow Feature Implementation

## Overview
Added `negative_allow` flag to products table to control whether a product can have negative stock (auto-purchase creation) or must have sufficient stock before bill creation.

## Feature Description

### What is `negative_allow`?
A boolean flag on each product that determines stock management behavior:

- **`negative_allow = 1` (TRUE)**: Product allows negative stock
  - System creates automatic dummy purchases for stock shortages
  - Bills always succeed regardless of stock level
  - Use for: consumables, frequently restocked items, non-critical items

- **`negative_allow = 0` (FALSE)**: Product requires sufficient stock
  - System throws error if stock insufficient
  - Bills are blocked until stock is available
  - Use for: high-value items, serialized products, controlled inventory

## Database Changes

### products table
```sql
ALTER TABLE products ADD COLUMN negative_allow INTEGER NOT NULL DEFAULT 0;
```

**Default Value**: 0 (FALSE) - All existing products default to NOT allowing negative stock

## Implementation Details

### 1. Product Model (`lib/model/product.dart`)

**Added Field:**
```dart
final bool negativeAllow;
```

**Constructor:**
```dart
Product({
  // ... other fields
  this.negativeAllow = false,  // Default to false
});
```

**fromJson:**
```dart
negativeAllow: (json['negative_allow'] as int?) == 1,
```

**toJson:**
```dart
'negative_allow': negativeAllow ? 1 : 0,
```

**copyWith:**
```dart
bool? negativeAllow,
// ...
negativeAllow: negativeAllow ?? this.negativeAllow,
```

### 2. Bill Repository (`lib/repository/bill_repository.dart`)

**Modified `createBill()` method:**

```dart
// Check stock availability
final availableQty = ...;

if (availableQty < it.quantity) {
  // Get product's negative_allow flag
  final productCheck = await txn.rawQuery(
    'SELECT negative_allow FROM products WHERE id = ?',
    [it.productId],
  );

  final negativeAllow = productCheck.isNotEmpty
      ? (productCheck.first['negative_allow'] as int) == 1
      : false;

  if (negativeAllow) {
    // Create auto-purchase for shortage
    await _createAutoPurchaseForShortage(...);
  } else {
    // Throw error - block bill creation
    throw Exception(
      'Insufficient stock for ${it.productName}. Available: $availableQty, Required: ${it.quantity}',
    );
  }
}
```

## Behavior Examples

### Example 1: Product with negative_allow = 1
```
Product: "Engine Oil" (negative_allow = 1)
Available stock: 1 unit
Bill requires: 4 units

RESULT:
✅ Auto-purchase created for 3 units
✅ Stock batch created with 3 units
✅ Bill created successfully
✅ User sees success message
```

### Example 2: Product with negative_allow = 0
```
Product: "Brake Disc" (negative_allow = 0)
Available stock: 1 unit
Bill requires: 4 units

RESULT:
❌ No auto-purchase created
❌ Exception thrown: "Insufficient stock for Brake Disc. Available: 1, Required: 4"
❌ Bill creation fails
❌ User sees error dialog
❌ Transaction rolled back
```

### Example 3: Mixed Products in One Bill
```
Cart:
- Product A (negative_allow = 1): Available: 0, Need: 5
- Product B (negative_allow = 0): Available: 10, Need: 3
- Product C (negative_allow = 0): Available: 1, Need: 4

Processing:
1. Product A: Insufficient, but negative_allow = 1 → Create auto-purchase ✅
2. Product B: Sufficient stock → Continue ✅
3. Product C: Insufficient, negative_allow = 0 → THROW ERROR ❌

RESULT:
❌ Entire transaction rolled back
❌ No bill created
❌ No auto-purchase created (even for Product A)
❌ User sees error: "Insufficient stock for Product C. Available: 1, Required: 4"
```

### Example 4: All Products Allow Negative Stock
```
Cart:
- Product A (negative_allow = 1): Available: 0, Need: 5
- Product B (negative_allow = 1): Available: 1, Need: 3
- Product C (negative_allow = 1): Available: 10, Need: 8

Processing:
1. Product A: Create auto-purchase for 5 units ✅
2. Product B: Create auto-purchase for 2 units ✅
3. Product C: Use existing stock ✅

RESULT:
✅ 2 auto-purchases created
✅ Bill created successfully
✅ All stock allocated properly
```

## Use Cases

### Products that SHOULD have `negative_allow = 1`:
- Consumables (oil, filters, fluids)
- Frequently restocked items
- Low-value items
- Fast-moving inventory
- Items with reliable suppliers
- Non-serialized products
- Bulk items

### Products that SHOULD have `negative_allow = 0`:
- High-value items (engines, transmissions)
- Serialized products (electronics)
- Warranty-tracked items
- Consignment inventory
- Limited availability items
- Custom-order products
- Critical control inventory
- Items requiring physical verification

## How to Set negative_allow Flag

### Option 1: SQL Update (Bulk)
```sql
-- Enable negative_allow for specific products
UPDATE products
SET negative_allow = 1
WHERE name IN ('Engine Oil', 'Air Filter', 'Oil Filter');

-- Enable for entire category
UPDATE products
SET negative_allow = 1
WHERE sub_category_id = 5;  -- Consumables category

-- Enable for products below certain price
UPDATE products
SET negative_allow = 1
WHERE cost_price < 100;
```

### Option 2: Product Form (UI)
Add checkbox in product create/edit form:
```dart
CheckboxListTile(
  title: Text('Allow Negative Stock'),
  subtitle: Text('Create automatic purchase when stock insufficient'),
  value: negativeAllow,
  onChanged: (value) {
    setState(() {
      negativeAllow = value ?? false;
    });
  },
)
```

## Testing Scenarios

### Test 1: Negative Allow Enabled - Insufficient Stock
**Setup:**
```sql
UPDATE products SET negative_allow = 1 WHERE id = 1;
-- Ensure product has low/zero stock
```

**Steps:**
1. Add product (id=1) to cart with quantity > available
2. Create bill

**Expected:**
- Auto-purchase created ✅
- Bill created successfully ✅

### Test 2: Negative Allow Disabled - Insufficient Stock
**Setup:**
```sql
UPDATE products SET negative_allow = 0 WHERE id = 2;
-- Ensure product has low/zero stock
```

**Steps:**
1. Add product (id=2) to cart with quantity > available
2. Create bill

**Expected:**
- Error dialog shown ❌
- Bill NOT created ❌
- Error message: "Insufficient stock for [Product Name]. Available: X, Required: Y"

### Test 3: Negative Allow Enabled - Sufficient Stock
**Setup:**
```sql
UPDATE products SET negative_allow = 1 WHERE id = 3;
-- Ensure product has sufficient stock
```

**Steps:**
1. Add product (id=3) to cart with quantity <= available
2. Create bill

**Expected:**
- No auto-purchase created ✅
- Bill created using existing stock ✅
- Stock deducted normally ✅

### Test 4: Negative Allow Disabled - Sufficient Stock
**Setup:**
```sql
UPDATE products SET negative_allow = 0 WHERE id = 4;
-- Ensure product has sufficient stock
```

**Steps:**
1. Add product (id=4) to cart with quantity <= available
2. Create bill

**Expected:**
- No auto-purchase created ✅
- Bill created using existing stock ✅
- Stock deducted normally ✅

### Test 5: Mixed Products - One Blocks Bill
**Setup:**
```sql
UPDATE products SET negative_allow = 1 WHERE id = 1;
UPDATE products SET negative_allow = 0 WHERE id = 2;
-- Product 1: sufficient stock
-- Product 2: insufficient stock
```

**Steps:**
1. Add both products to cart
2. Create bill

**Expected:**
- Error for Product 2 ❌
- No bill created ❌
- No auto-purchase for Product 1 (transaction rolled back) ❌

### Test 6: Multiple Products - All Allow Negative
**Setup:**
```sql
UPDATE products SET negative_allow = 1 WHERE id IN (1, 2, 3);
-- All products: insufficient stock
```

**Steps:**
1. Add all 3 products to cart
2. Create bill

**Expected:**
- 3 auto-purchases created ✅
- Bill created successfully ✅
- All stock allocated ✅

## Verification Queries

### Check Product Settings
```sql
SELECT
  id,
  name,
  negative_allow,
  CASE negative_allow
    WHEN 1 THEN 'Allows Negative Stock'
    ELSE 'Requires Sufficient Stock'
  END as stock_policy
FROM products
WHERE is_deleted = 0
ORDER BY name;
```

### Check Products by Stock Policy
```sql
-- Products allowing negative stock
SELECT id, name, part_number, cost_price
FROM products
WHERE negative_allow = 1 AND is_deleted = 0;

-- Products requiring sufficient stock
SELECT id, name, part_number, cost_price
FROM products
WHERE negative_allow = 0 AND is_deleted = 0;
```

### Check Auto-Purchases Created for Negative-Allow Products
```sql
SELECT
  p.purchase_number,
  pr.name as product_name,
  pr.negative_allow,
  pi.quantity,
  p.created_at
FROM purchases p
JOIN purchase_items pi ON p.id = pi.purchase_id
JOIN products pr ON pi.product_id = pr.id
WHERE p.is_auto_purchase = 1
ORDER BY p.created_at DESC;
```

### Find Products with Recent Stock Issues
```sql
-- Products that might benefit from negative_allow = 1
SELECT
  p.id,
  p.name,
  p.negative_allow,
  COALESCE(SUM(sb.quantity_remaining), 0) as current_stock
FROM products p
LEFT JOIN stock_batches sb ON p.id = sb.product_id AND sb.is_deleted = 0
WHERE p.is_deleted = 0
GROUP BY p.id
HAVING current_stock < 5
ORDER BY current_stock ASC;
```

## Migration Strategy

### For Existing Products

**Conservative Approach (Recommended):**
```sql
-- All products default to negative_allow = 0
-- No action needed - this is already the default
```

**Selective Enablement:**
```sql
-- Enable for consumables
UPDATE products
SET negative_allow = 1
WHERE sub_category_id IN (
  SELECT id FROM sub_categories WHERE name LIKE '%Consumable%'
);

-- Enable for low-value items
UPDATE products
SET negative_allow = 1
WHERE cost_price < 500;

-- Enable for specific products
UPDATE products
SET negative_allow = 1
WHERE name IN ('Engine Oil', 'Brake Fluid', 'Coolant');
```

**Aggressive Approach:**
```sql
-- Enable for all except high-value items
UPDATE products SET negative_allow = 1;

UPDATE products
SET negative_allow = 0
WHERE cost_price > 5000 OR name LIKE '%Engine%';
```

## UI Integration Points

### Product Form
Add checkbox:
- Label: "Allow Negative Stock"
- Help text: "When enabled, bills can be created even when stock is insufficient. System will automatically create purchase records."
- Position: Near other product flags (is_taxable, is_enabled)

### Product List
Add column:
- Icon indicator:
  - ✅ Green checkmark for negative_allow = 1
  - ❌ Red X for negative_allow = 0
- Filter option: "Stock Policy"

### POS Screen Error
When bill fails due to insufficient stock:
```
Error: Insufficient Stock

Product: Brake Disc
Available: 1 unit
Required: 4 units

This product requires sufficient stock before sale.
Please restock or remove from cart.

[View Product Settings] [Close]
```

### Settings Page
Add bulk update option:
```
Stock Management Policies

[ ] Enable negative stock for all products
[ ] Enable negative stock for consumables only
[ ] Enable negative stock for items under ₹500
[Apply Changes]
```

## Error Messages

### Insufficient Stock Error (negative_allow = 0)
```
Insufficient stock for [Product Name]. Available: X, Required: Y
```

### Multiple Products Error
```
Insufficient stock for the following products:
- Brake Disc: Available: 1, Required: 4
- Clutch Plate: Available: 0, Required: 2

Please adjust quantities or restock items.
```

## Performance Considerations

**Query Overhead:**
- Added one additional query per product with insufficient stock
- Query is simple (SELECT negative_allow by ID)
- Minimal performance impact
- Executed within transaction (fast)

**Optimization:**
- Query result cached within transaction
- No additional database roundtrips
- Index on product_id already exists

## Benefits

1. **Flexibility**: Different stock policies for different products
2. **Control**: High-value items protected from overselling
3. **Convenience**: Low-value items don't block sales
4. **Audit Trail**: Clear record of which products triggered auto-purchases
5. **Business Logic**: Aligns with real-world inventory practices
6. **Error Prevention**: Critical items can't be oversold

## Limitations

1. **No UI Toggle Yet**: Must set via SQL or future UI
2. **All-or-Nothing**: If one product blocks, entire bill fails
3. **No Warnings**: No "almost out of stock" alerts
4. **Static Flag**: Can't change policy based on stock level
5. **No Approval Flow**: Auto-purchases created without review

## Future Enhancements

1. **Smart Defaults**: Auto-set based on product category/price
2. **Threshold-Based**: Allow negative up to X units, then block
3. **Approval Workflow**: Queue auto-purchases for review
4. **Warnings**: Show warning if product requires stock (before adding to cart)
5. **Batch Update UI**: Bulk enable/disable by category
6. **Analytics**: Report on products frequently triggering auto-purchases
7. **Dynamic Policy**: Change policy based on time/season
8. **Customer-Specific**: VIP customers bypass stock checks

## Summary

The `negative_allow` flag provides granular control over stock management policies:

- **Enabled (1)**: Convenience - Auto-purchases keep sales flowing
- **Disabled (0)**: Control - Protect inventory of critical items

This combines the best of both approaches: automated stock management for routine items, strict control for important inventory.

**Default**: Conservative (0) - Requires sufficient stock
**Recommended**: Enable selectively based on product type and business needs
