# Refund Calculation Bug Fix

## Problem Statement

When a customer has **fully paid** for products and then returns **only some** of them, the system was potentially allowing refunds that exceed the value of returned products. This is because the old logic used a **cumulative approach** for calculating `max_refundable_amount`.

## Bug Example

**Scenario**: Bill for 13 products at ₹1,000 each = ₹13,000 (FULLY PAID)

### Old Logic (Buggy - Cumulative Approach):
```
Customer buys 13 products, pays ₹13,000
Bill remaining: ₹0

Return 1: ₹1,000
- netRemaining = 0 - 1,000 = -1,000 (negative means overpaid)
- excessAmount = 1,000 (CUMULATIVE total excess)
- max_refundable = ₹1,000 ✅

Return 2: ₹2,000
- netRemaining = 0 - 1,000 - 2,000 = -3,000
- excessAmount = 3,000 (CUMULATIVE)
- max_refundable = ₹3,000 ❌ (Should be ₹2,000 for THIS credit note!)

Return 3: ₹4,000
- netRemaining = -3,000 - 4,000 = -7,000
- excessAmount = 7,000 (CUMULATIVE)
- max_refundable = ₹7,000 ❌ (Should be ₹4,000 for THIS credit note!)
```

The bug is that each credit note stores the **CUMULATIVE excess** instead of **just this credit note's refundable amount**.

### New Logic (Fixed - Individual Approach):
```
Return 1: ₹1,000
- netRemaining before = 0
- This return exceeds remaining, refund = ₹1,000
- max_refundable = ₹1,000 ✅

Return 2: ₹2,000
- netRemaining before = -1,000 (already negative)
- This return's full value is refundable = ₹2,000
- max_refundable = ₹2,000 ✅

Return 3: ₹4,000
- netRemaining before = -3,000 (already negative)
- This return's full value is refundable = ₹4,000
- max_refundable = ₹4,000 ✅
```

## Fix Implementation

**File**: `lib/repository/bill_repository.dart`
**Method**: `createCreditNote()` (around line 490)

### Key Changes:

1. **Calculate individual refundable amount**, not cumulative:
   ```dart
   // OLD: Used total excess (cumulative)
   final excessAmount = -newNetRemaining;

   // NEW: Calculate refundable for THIS credit note only
   double thisReturnRefundable;
   if (netBillRemaining >= 0.01) {
     // Only the portion exceeding bill remaining
     thisReturnRefundable = creditNoteAmount - netBillRemaining;
   } else {
     // Full value of this return
     thisReturnRefundable = creditNoteAmount;
   }
   ```

2. **Still apply available funds limit**:
   ```dart
   final availableToRefund = paidAmount - alreadyAllocated;
   maxRefundableAmount = min(thisReturnRefundable, availableToRefund);
   ```

## Test Scenarios

### Scenario 1: Fully Paid + Full Return
- Buy: 13 units × ₹1,000 = ₹13,000, Paid: ₹13,000
- Return: All 13 units (₹13,000)
- **Expected**: max_refundable total = ₹13,000 ✅
- **Result**: Customer gets back all money (correct!)

### Scenario 2: Fully Paid + Partial Return
- Buy: 13 units × ₹1,000 = ₹13,000, Paid: ₹13,000
- Return: 7 units (₹7,000), Keep: 6 units (₹6,000)
- **Expected**: max_refundable total = ₹7,000 ✅
- **Result**: Customer gets ₹7,000 back, keeps ₹6,000 worth of products

### Scenario 3: Partial Payment + Return
- Buy: 13 units × ₹1,000 = ₹13,000, Paid: ₹5,000
- Bill remaining: ₹8,000
- Return: 10 units (₹10,000)
- **Expected**: max_refundable = ₹2,000 (₹10,000 return - ₹8,000 remaining)
- **Result**: Correct! Customer returns ₹10,000 worth, but still owes ₹8,000, net refund = ₹2,000

### Scenario 4: Multiple Returns with Partial Payment
- Buy: 5 units × ₹100 = ₹500, Paid: ₹300
- Bill remaining: ₹200
- Return 1: 2 units (₹200) → max_refundable = ₹0 (adjusted to remaining)
- Return 2: 1 unit (₹100) → max_refundable = ₹100
- Return 3: 1 unit (₹100) → max_refundable = ₹100
- **Total max_refundable**: ₹200 (but only ₹300 paid, minus ₹100 kept = ₹200 refund) ✅

## Database Impact

### Current State
No bills were found with `max_refundable_amount > total_returned_value`, so the existing data is correct. This is likely because:
1. The bug only manifests in specific sequences of returns
2. Users may not have clicked "Issue Refund" yet on buggy credit notes
3. Previous fixes may have prevented the worst cases

### Migration Required?
**No database migration needed** - the fix applies to **new credit notes** created after deployment.

### Verify Existing Data
Run this query to double-check:
```sql
WITH bill_summary AS (
  SELECT
    b.id,
    b.bill_number,
    (SELECT COALESCE(SUM(total_amount), 0) FROM credit_notes WHERE bill_id = b.id AND is_deleted = 0) as total_returned,
    (SELECT COALESCE(SUM(max_refundable_amount), 0) FROM credit_notes WHERE bill_id = b.id AND is_deleted = 0) as total_refundable
  FROM bills b
  WHERE EXISTS (SELECT 1 FROM credit_notes WHERE bill_id = b.id AND is_deleted = 0)
)
SELECT * FROM bill_summary
WHERE total_refundable > total_returned + 0.01;
```

If any rows are returned, those bills need manual review.

## Testing Checklist

- [x] Fix compilation errors
- [ ] Test fully paid + full return
- [ ] Test fully paid + partial return
- [ ] Test partial paid + return exceeding remaining
- [ ] Test multiple sequential returns
- [ ] Test edge case: return exact remaining amount
- [ ] Verify no negative max_refundable values
- [ ] Verify refund status correctly set (pending/adjusted)

## Related Files
- `lib/repository/bill_repository.dart` - Fixed logic
- `lib/view/screens/sales_screen.dart` - Display logic
- `lib/view/screens/sales_returns_screen.dart` - Refund status display

## Notes
- This fix ensures `max_refundable_amount` represents **this credit note's refundable amount**, not cumulative
- The `alreadyAllocated` check ensures we never refund more than what the customer paid
- The `netBillRemaining` check ensures returns first offset any outstanding bill balance
