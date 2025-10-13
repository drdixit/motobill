# POS Last Custom Price Feature - Manual Test Scenarios

## Overview
This feature displays the last price (per unit with tax) that was charged to a customer for each product in the POS cart. It helps users quickly reference previous pricing when creating new bills.

## Feature Behavior
- When a customer is selected, the system fetches last custom prices for all products
- The last custom price is displayed as a small badge between the quantity and per-unit price fields
- The badge only appears if a custom price exists for that customer-product combination
- If no previous sale exists, no badge is shown (uses default product price)
- When customer is changed, all badges update automatically

---

## Test Scenarios

### Scenario 1: No Previous Sale
**Steps:**
1. Open POS screen
2. Select a customer who has never purchased before
3. Add any product to cart

**Expected Result:**
- No price badge appears between quantity and price fields
- Product uses default selling price

**Status:** ✅ Automated test passing

---

### Scenario 2: Previous Sale with Same Price
**Steps:**
1. Create a bill for Customer A with Product X at ₹100 (with tax: ₹118)
2. Save the bill
3. Create a new bill for Customer A
4. Add Product X to cart

**Expected Result:**
- Blue badge showing "₹118.00" appears between quantity and price
- Price field shows ₹118.00 as default

**Status:** ✅ Automated test passing

---

### Scenario 3: Previous Sale with Custom Price
**Steps:**
1. Create a bill for Customer B with Product Y
2. Change per-unit price to ₹150 (custom price, with tax becomes ₹177)
3. Save the bill
4. Create a new bill for Customer B
5. Add Product Y to cart

**Expected Result:**
- Blue badge showing "₹177.00" appears
- System "remembers" the custom price
- Price field shows ₹177.00 as default

**Status:** ✅ Automated test passing

---

### Scenario 4: Multiple Quantity Sale
**Steps:**
1. Create a bill for Customer C with Product Z
2. Set quantity to 5, total with tax becomes ₹590 (₹118 per unit)
3. Save the bill
4. Create a new bill for Customer C
5. Add Product Z to cart (quantity 1)

**Expected Result:**
- Blue badge showing "₹118.00" (per unit price, not total)
- System correctly calculates per-unit price from bulk sale

**Status:** ✅ Automated test passing

---

### Scenario 5: Most Recent Price
**Steps:**
1. Create first bill: Customer D buys Product P at ₹100 (with tax: ₹118) on Jan 1
2. Create second bill: Customer D buys Product P at ₹120 (with tax: ₹141.60) on Jan 15
3. Create third bill: Customer D buys Product P at ₹110 (with tax: ₹129.80) on Jan 20
4. Create a new bill for Customer D
5. Add Product P to cart

**Expected Result:**
- Blue badge showing "₹129.80" (most recent price from Jan 20)
- System ignores older prices

**Status:** ✅ Automated test passing

---

### Scenario 6: Different Customers
**Steps:**
1. Create bill for Customer E with Product Q at custom price ₹200 (with tax: ₹236)
2. Create bill for Customer F with Product Q at custom price ₹150 (with tax: ₹177)
3. Create new bill for Customer E and add Product Q
4. Create new bill for Customer F and add Product Q

**Expected Result:**
- For Customer E: Badge shows "₹236.00"
- For Customer F: Badge shows "₹177.00"
- Each customer has their own pricing history

**Status:** ✅ Automated test passing

---

### Scenario 7: Customer Change in Cart
**Steps:**
1. Create bills with custom prices:
   - Customer G bought Product R at ₹150 (with tax: ₹177)
   - Customer H bought Product R at ₹200 (with tax: ₹236)
2. Create new bill
3. Select Customer G
4. Add Product R to cart (badge shows ₹177)
5. Change customer to Customer H without clearing cart

**Expected Result:**
- Badge updates from "₹177.00" to "₹236.00"
- Price field updates automatically
- GST calculations recalculate based on new customer state

**Status:** ✅ Automated test passing (via ViewModel logic)

---

### Scenario 8: Mix of Products
**Steps:**
1. Create bill for Customer I:
   - Product S at ₹100 (with tax: ₹118) - custom price
   - Product T at default price (never sold before)
2. Create new bill for Customer I
3. Add both Product S and Product T to cart

**Expected Result:**
- Product S: Badge shows "₹118.00"
- Product T: No badge (uses default price)
- Mixed display works correctly

**Status:** ✅ Automated test passing

---

### Scenario 9: Deleted Bills
**Steps:**
1. Create bill for Customer J with Product U at custom price ₹150 (with tax: ₹177)
2. Save the bill
3. Soft-delete the bill (is_deleted = 1)
4. Create new bill for Customer J
5. Add Product U to cart

**Expected Result:**
- No badge appears
- System ignores deleted bills
- Uses default product price

**Status:** ✅ Automated test passing

---

### Scenario 10: Empty Cart to Cart with Items
**Steps:**
1. Create bill for Customer K with Product V at ₹200 (with tax: ₹236)
2. Save the bill
3. Create new bill
4. Select Customer K (cart is empty)
5. Add Product V to cart

**Expected Result:**
- Badge appears when product is added
- System loads custom prices when customer is selected (even with empty cart)
- Badge shows "₹236.00"

**Status:** ✅ Automated test passing (via ViewModel logic)

---

### Scenario 11: Zero Quantity Edge Case
**Steps:**
1. Manually create bill_item with quantity = 0 in database
2. Create new bill for that customer
3. Add that product to cart

**Expected Result:**
- No badge appears (edge case handled)
- System doesn't divide by zero
- Uses default product price

**Status:** ✅ Automated test passing

---

### Scenario 12: Clear Cart
**Steps:**
1. Select Customer L
2. Add products to cart (badges appear)
3. Click "Clear Cart" button

**Expected Result:**
- Cart empties
- Customer remains selected
- When products added again, badges reappear with same prices

**Status:** ✅ Manual verification needed

---

### Scenario 13: Visual Design
**Steps:**
1. Add any product with last custom price to cart
2. Observe the badge appearance

**Expected Result:**
- Badge has light blue background (AppColors.info.withOpacity(0.1))
- Badge has blue border (AppColors.info.withOpacity(0.3))
- Badge has blue text (AppColors.info)
- Text shows "₹" symbol followed by price with 2 decimals
- Badge is positioned between quantity and price fields
- Badge is small and doesn't disrupt layout

**Status:** ✅ Visual verification needed

---

## Edge Cases Covered

1. ✅ No previous sale exists
2. ✅ Multiple sales exist (uses most recent)
3. ✅ Quantity > 1 (calculates per unit)
4. ✅ Deleted bills (ignored)
5. ✅ Zero quantity (returns null)
6. ✅ Different customers (isolated pricing)
7. ✅ Customer change (updates automatically)
8. ✅ Empty product list
9. ✅ Mixed products (some with, some without custom prices)

---

## Database Query Optimization

The feature uses two queries:
1. `getLastCustomPrice(customerId, productId)` - Single product query
2. `getLastCustomPrices(customerId, productIds[])` - Batch query (more efficient)

The batch query is used when customer is selected to load all prices at once, avoiding N+1 query problems.

---

## Performance Considerations

- Custom prices are fetched only when customer is selected or changed
- Uses efficient SQL with proper indexing on `customer_id`, `product_id`, and `created_at`
- Badge rendering is conditional (only when price exists)
- No performance impact when no custom prices exist

---

## Integration Points

1. **Repository Layer**: `pos_repository.dart` - SQL queries
2. **ViewModel Layer**: `pos_viewmodel.dart` - State management
3. **View Layer**: `pos_cart.dart` - UI display
4. **State**: `lastCustomPrices` map in PosState

---

## Testing Summary

- **Total Test Cases**: 10 automated tests
- **All Tests Passing**: ✅
- **Code Coverage**: Repository and ViewModel logic fully covered
- **Manual Tests Needed**: UI visual verification and cart clear behavior
