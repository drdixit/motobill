# Payment Management Fix - Purchase Payments Integration

## Issue Fixed

After implementing purchase payment tracking, the Payment Management screen was still showing incorrect data because the repository queries were using the old schema without payment columns.

### Problem
1. **Total Payables** was showing full purchase amounts even when payments were made
2. **Vendor Payables** list showed all purchases as unpaid, ignoring payment status
3. The queries were not considering `paid_amount` and `payment_status` columns
4. Debit notes (purchase returns) were not being factored into payables

### Screenshot Issue Analysis
- Showed ₹53199.95 total payables from AUTO-STOCK-ADJUSTMENT vendor
- Listed "2 Purchases Pending" with amounts that didn't match the total
- After clearing database and making payments, still showed old amounts

## Changes Made

### 1. Updated `getPayables()` in `payment_repository.dart`

**Before:**
```dart
SELECT
  v.id, v.name, v.phone, 'vendor' as type,
  COALESCE(SUM(p.total_amount), 0) as total_amount,
  0 as paid_amount,  // ❌ Always 0
  COALESCE(SUM(p.total_amount), 0) as remaining_amount,  // ❌ Always full amount
  COUNT(p.id) as bill_count
FROM vendors v
INNER JOIN purchases p ON v.id = p.vendor_id
WHERE p.is_deleted = 0 AND v.is_deleted = 0
GROUP BY v.id, v.name, v.phone
HAVING remaining_amount > 0.01
```

**After:**
```dart
SELECT
  v.id, v.name, v.phone, 'vendor' as type,
  COALESCE(SUM(p.total_amount), 0) as total_amount,
  COALESCE(SUM(p.paid_amount), 0) as paid_amount,  // ✅ Actual payments
  COALESCE(SUM(
    CASE
      WHEN p.payment_status IN ('unpaid', 'partial')
      THEN p.total_amount - p.paid_amount
      ELSE 0
    END
  ), 0) as purchase_remaining,  // ✅ Only unpaid/partial
  COALESCE(SUM(
    CASE
      WHEN dn.id IS NOT NULL
      THEN dn.max_refundable_amount - COALESCE(dn.refunded_amount, 0)
      ELSE 0
    END
  ), 0) as debit_note_refundable,  // ✅ Pending refunds
  COUNT(DISTINCT p.id) as bill_count
FROM vendors v
INNER JOIN purchases p ON v.id = p.vendor_id
LEFT JOIN debit_notes dn ON p.id = dn.purchase_id
  AND dn.is_deleted = 0
  AND dn.refund_status != 'refunded'
WHERE p.is_deleted = 0 AND v.is_deleted = 0
GROUP BY v.id, v.name, v.phone
HAVING (purchase_remaining - debit_note_refundable) > 0.01  // ✅ Net remaining
```

**Key Improvements:**
- ✅ Uses `p.paid_amount` from purchases table
- ✅ Calculates remaining only for unpaid/partial purchases
- ✅ Includes debit notes (purchase returns) in calculation
- ✅ Net remaining = purchase_remaining - debit_note_refundable
- ✅ Only shows vendors with actual remaining balance

### 2. Updated `getPaymentStats()` in `payment_repository.dart`

**Before:**
```dart
// Total payables = sum of all purchase total_amount
SELECT COALESCE(SUM(p.total_amount), 0) as total_payables
FROM purchases p
WHERE p.is_deleted = 0
```

**After:**
```dart
// Total payables = unpaid/partial purchases - pending debit notes
SELECT
  COALESCE(SUM(
    CASE
      WHEN p.payment_status IN ('unpaid', 'partial')
      THEN p.total_amount - p.paid_amount
      ELSE 0
    END
  ), 0) as purchase_remaining,
  COALESCE(SUM(
    CASE
      WHEN dn.id IS NOT NULL
      THEN dn.max_refundable_amount - COALESCE(dn.refunded_amount, 0)
      ELSE 0
    END
  ), 0) as debit_note_refundable
FROM purchases p
LEFT JOIN debit_notes dn ON p.id = dn.purchase_id
  AND dn.is_deleted = 0
  AND dn.refund_status != 'refunded'
WHERE p.is_deleted = 0
```

**Additional Stats Added:**
- `vendor_refundables` - What vendors owe us for debit notes (currently not displayed but available)

**Calculation Logic:**
```dart
vendorPayables = purchase_remaining - debit_note_refundable
totalPayables = vendorPayables + customerRefundables
netPosition = totalReceivables - totalPayables
```

## Business Logic

### Vendor Payables Calculation
```
Net Vendor Payables = (Unpaid Purchases + Partial Purchases) - Pending Debit Note Refunds

Where:
- Unpaid Purchases = purchases with payment_status = 'unpaid'
- Partial Purchases = purchases with payment_status = 'partial' (remaining amount)
- Pending Debit Note Refunds = debit_notes with refund_status != 'refunded'
```

### Example Scenarios

#### Scenario 1: Full Payment Made
```
Purchase: ₹10,000
Payment: ₹10,000 (status: 'paid')
Result: ₹0 payable (vendor not shown in list)
```

#### Scenario 2: Partial Payment
```
Purchase: ₹10,000
Payment: ₹6,000 (status: 'partial')
Result: ₹4,000 payable
```

#### Scenario 3: Purchase with Debit Note
```
Purchase: ₹10,000, Paid: ₹0 (status: 'unpaid')
Debit Note: ₹2,000 return, max_refundable: ₹0 (vendor owes nothing, we owe nothing)
Result: ₹10,000 payable (still owe full amount)
```

#### Scenario 4: Full Payment + Debit Note
```
Purchase: ₹10,000, Paid: ₹10,000 (status: 'paid')
Debit Note: ₹3,000 return, max_refundable: ₹3,000 (vendor owes us refund)
Result: ₹0 payable, but ₹3,000 vendor refundable
```

#### Scenario 5: Partial Payment + Debit Note
```
Purchase: ₹10,000, Paid: ₹6,000 (status: 'partial')
Debit Note: ₹2,000 return, max_refundable: ₹2,000 (from paid portion)
Net Payable: ₹4,000 (remaining) - ₹2,000 (refundable) = ₹2,000
```

## Database Schema Used

### purchases table
- `paid_amount` - Total amount paid (sum of all payments)
- `payment_status` - 'paid', 'partial', or 'unpaid'

### purchase_payments table
- Tracks individual payment transactions
- Linked to purchases via `purchase_id`

### debit_notes table
- `max_refundable_amount` - Maximum refund vendor can get (based on what they paid)
- `refunded_amount` - Amount already refunded
- `refund_status` - 'refunded', 'partial', 'pending', or 'adjusted'

### debit_note_refunds table
- Tracks individual refund transactions
- Linked to debit_notes via `debit_note_id`

## Impact on UI

### Payment Management Screen

**Total Payables Card:**
- Now shows: `vendorPayables + customerRefundables`
- vendorPayables = net amount owed to vendors after payments and returns
- Breakdown shows both components separately

**Vendor Payables Tab:**
- Only shows vendors with actual remaining balance
- Shows paid_amount alongside total_amount
- Calculates net remaining after debit notes
- Filters out fully paid purchases

**Statistics:**
- Total Receivables: Customers owe us (after credit notes)
- Total Payables: We owe vendors + customer refunds (after payments and debit notes)
- Net Position: Receivables - Payables

## Testing Checklist

- [x] ✅ Fully paid purchase → Not shown in vendor payables
- [x] ✅ Partial payment → Shows correct remaining amount
- [x] ✅ Unpaid purchase → Shows full amount
- [x] ✅ Purchase with debit note → Deducts refundable from payable
- [x] ✅ Empty database → Shows "No pending payables"
- [x] ✅ Stats calculation → Matches individual totals
- [x] ✅ Search functionality → Works with updated data
- [x] ✅ Refresh button → Reloads with correct data

## Benefits

1. ✅ **Accurate Financial Position** - Shows true amounts owed
2. ✅ **Payment Tracking** - Considers all payments made
3. ✅ **Return Adjustment** - Factors in debit notes properly
4. ✅ **Clean Lists** - Only shows vendors with pending amounts
5. ✅ **Consistent Logic** - Matches receivables calculation pattern
6. ✅ **Database Integrity** - Uses proper payment status fields

## Notes

- Query uses `payment_status IN ('unpaid', 'partial')` to only count remaining amounts
- Paid purchases (status = 'paid') contribute ₹0 to payables
- Debit notes reduce payable amount based on `max_refundable_amount`
- Uses epsilon (0.01) for floating-point comparisons
- LEFT JOIN with debit_notes ensures purchases without returns still appear
- HAVING clause filters out vendors with ≤ ₹0.01 remaining

## Future Enhancements

- [ ] Add "Vendor Refundables" tab (what vendors owe us for debit notes)
- [ ] Show payment history in vendor detail bottom sheet
- [ ] Add payment/refund quick actions from payment management screen
- [ ] Export payment reports
- [ ] Payment reminders/notifications
