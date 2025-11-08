# Purchase Payment & Refund Flow Implementation

## Overview
Implemented complete payment and refund flow for purchases and purchase returns (debit notes), matching the existing sales/credit notes functionality.

## Database Changes

### 1. New Tables Created

#### `purchase_payments`
Tracks all payments made for purchases.
```sql
CREATE TABLE purchase_payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    purchase_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_date TEXT NOT NULL DEFAULT (datetime('now')),
    notes TEXT,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (purchase_id) REFERENCES purchases(id)
);
```

#### `debit_note_refunds`
Tracks all refunds issued for debit notes (purchase returns).
```sql
CREATE TABLE debit_note_refunds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    debit_note_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    refund_method TEXT NOT NULL DEFAULT 'cash',
    refund_date TEXT NOT NULL DEFAULT (datetime('now')),
    notes TEXT,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (debit_note_id) REFERENCES debit_notes(id)
);
```

### 2. Columns Added to Existing Tables

#### `purchases` table
- `paid_amount REAL NOT NULL DEFAULT 0` - Total amount paid
- `payment_status TEXT NOT NULL DEFAULT 'unpaid'` - Status: 'paid', 'partial', 'unpaid'

#### `debit_notes` table
- `refunded_amount REAL NOT NULL DEFAULT 0` - Total amount refunded
- `refund_status TEXT NOT NULL DEFAULT 'pending'` - Status: 'refunded', 'partial', 'pending', 'adjusted'
- `max_refundable_amount REAL DEFAULT 0` - Maximum refundable based on vendor's paid amount

## Code Changes

### 1. Models Created

#### `lib/model/purchase_payment.dart`
```dart
class PurchasePayment {
  final int? id;
  final int purchaseId;
  final double amount;
  final String paymentMethod; // 'cash', 'upi', 'card', 'bank_transfer', 'cheque'
  final DateTime paymentDate;
  final String? notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Includes fromJson, toJson, and copyWith methods
}
```

#### `lib/model/debit_note_refund.dart`
```dart
class DebitNoteRefund {
  final int? id;
  final int debitNoteId;
  final double amount;
  final String refundMethod; // 'cash', 'upi', 'card', 'bank_transfer', 'cheque'
  final DateTime refundDate;
  final String? notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Includes fromJson and toJson methods
}
```

### 2. Updated Models

#### `lib/model/purchase.dart`
**Added fields:**
- `double paidAmount` - Total amount paid
- `String paymentStatus` - Payment status ('paid', 'partial', 'unpaid')

**Added getters:**
- `double get remainingAmount => totalAmount - paidAmount;`
- `bool get isFullyPaid => paidAmount >= totalAmount;`
- `bool get isPartiallyPaid => paidAmount > 0 && paidAmount < totalAmount;`

### 3. Repository Methods Added

#### `lib/repository/purchase_repository.dart`

**Payment Methods:**
- `addPayment({required int purchaseId, required double amount, ...})` - Add a payment to a purchase
- `getPurchasePayments(int purchaseId)` - Get all payments for a purchase
- `getPurchaseWithPayments(int purchaseId)` - Get purchase with payment info
- `deletePayment(int paymentId)` - Soft delete a payment

**Payment Logic:**
- Automatically calculates `paid_amount` by summing all non-deleted payments
- Updates `payment_status` based on total paid vs total amount:
  - `'paid'` - Total paid >= total amount (with epsilon tolerance of 0.01)
  - `'partial'` - Total paid > 0 but < total amount
  - `'unpaid'` - Total paid = 0
- Uses epsilon (0.01) for floating-point comparison to avoid precision issues

#### `lib/repository/debit_note_repository.dart`

**Refund Methods:**
- `addRefund({required int debitNoteId, required double amount, ...})` - Add a refund for a debit note
- `getDebitNoteRefunds(int debitNoteId)` - Get all refunds for a debit note
- `deleteRefund(int refundId)` - Soft delete a refund

**Refund Logic:**
- Automatically calculates `refunded_amount` by summing all non-deleted refunds
- Updates `refund_status` based on total refunded vs max_refundable_amount:
  - `'refunded'` - Total refunded >= max refundable (with epsilon tolerance)
  - `'partial'` - Total refunded > 0 but < max refundable
  - `'pending'` - Total refunded = 0
- Validates that total refunds don't exceed `max_refundable_amount`

**Max Refundable Amount Calculation:**
Updated `createDebitNote` to calculate `max_refundable_amount` during debit note creation:

```dart
// Business Logic:
// 1. Get purchase total_amount and paid_amount
// 2. Calculate purchase remaining = total_amount - paid_amount
// 3. Get sum of previous debit notes' total_amount and max_refundable_amount
// 4. Calculate net remaining after all returns
// 5. If vendor still owes money after return:
//    - max_refundable_amount = 0
//    - refund_status = 'adjusted'
// 6. If return value exceeds what vendor owes:
//    - Calculate refundable portion
//    - Limit by what vendor actually paid (paid_amount - already_allocated)
//    - refund_status = 'pending' or 'adjusted'
```

This ensures vendors only get refunds for what they've actually paid, similar to customer credit notes.

## Payment Methods Supported

Both payments and refunds support these methods:
- `'cash'` (default)
- `'upi'`
- `'card'`
- `'bank_transfer'`
- `'cheque'`

## Features & Safeguards

### 1. Partial Payments
- Purchases can be paid in multiple installments
- Each payment is tracked separately with date, method, and notes
- Payment status updates automatically based on total paid

### 2. Partial Refunds
- Debit notes can be refunded in multiple transactions
- Each refund is tracked separately with date, method, and notes
- Refund status updates automatically based on total refunded

### 3. Soft Delete Pattern
- All payments and refunds use soft delete (is_deleted flag)
- When deleted, system recalculates totals and statuses automatically
- No data is permanently lost

### 4. Floating-Point Precision Handling
- Uses epsilon tolerance (0.01) for all amount comparisons
- Prevents issues with floating-point arithmetic
- Status calculations use epsilon to avoid incorrect 'partial' status

### 5. Business Logic Validation
- Refunds cannot exceed max_refundable_amount
- max_refundable_amount is based on vendor's actual payment, not return value
- Previous allocations are considered when calculating refundable amount

### 6. Transaction Safety
- All operations use database transactions
- Ensures data consistency even if errors occur
- Multiple table updates happen atomically

## Integration with Existing System

### Matches Sales Pattern
The purchase payment flow exactly mirrors the sales pattern:
- **Sales Bills** ↔ **Purchase Bills** (bill_payments ↔ purchase_payments)
- **Credit Notes** ↔ **Debit Notes** (credit_note_refunds ↔ debit_note_refunds)
- Same payment/refund methods
- Same status logic
- Same epsilon tolerance for floating-point comparison

### Compatible with Stock Management
- Purchase payments don't affect stock levels
- Stock is added when purchase is created
- Stock is reduced when debit note is created
- Payment/refund tracking is separate from inventory

### Compatible with Auto-Purchase
- Auto-purchases can have payment status
- Works with manual purchases and auto-purchases
- No special handling needed for auto-purchases

## Usage Examples

### Add Payment to Purchase
```dart
await purchaseRepository.addPayment(
  purchaseId: 123,
  amount: 5000.00,
  paymentMethod: 'upi',
  paymentDate: DateTime.now(),
  notes: 'First installment',
);
```

### Get Purchase with Payments
```dart
final data = await purchaseRepository.getPurchaseWithPayments(123);
// Returns purchase data with 'payments' list
```

### Add Refund to Debit Note
```dart
await debitNoteRepository.addRefund(
  debitNoteId: 456,
  amount: 2000.00,
  refundMethod: 'cash',
  refundDate: DateTime.now(),
  notes: 'Partial refund to vendor',
);
```

### Get Debit Note Refunds
```dart
final refunds = await debitNoteRepository.getDebitNoteRefunds(456);
// Returns list of all refunds for this debit note
```

## Testing Recommendations

1. **Test Partial Payments:**
   - Create purchase with total 10,000
   - Add payment of 3,000 → status should be 'partial'
   - Add payment of 7,000 → status should be 'paid'

2. **Test Refund Logic:**
   - Create purchase with total 10,000, paid 6,000
   - Create debit note with return value 8,000
   - max_refundable should be 6,000 (what vendor paid)
   - Add refund of 6,000 → status should be 'refunded'

3. **Test Multiple Returns:**
   - Create purchase with total 10,000, paid 10,000
   - Create first debit note with return 3,000 → max_refundable = 3,000
   - Create second debit note with return 2,000 → max_refundable = 2,000
   - Total refundable = 5,000 (both returns fully refundable)

4. **Test Adjusted Status:**
   - Create purchase with total 10,000, paid 0
   - Create debit note with return 2,000
   - max_refundable should be 0 (vendor hasn't paid anything)
   - refund_status should be 'adjusted'

5. **Test Payment Deletion:**
   - Add payment → status becomes 'partial'
   - Delete payment → status should revert to 'unpaid'

## Notes

- All amounts use REAL type in SQLite (double in Dart)
- All dates stored as ISO 8601 strings in SQLite
- All queries exclude soft-deleted records (WHERE is_deleted = 0)
- Epsilon tolerance of 0.01 used throughout for amount comparisons
- Compatible with existing sales/credit note flow
- No UI changes needed initially (backend ready)

## Next Steps (UI Implementation)

To complete the feature, you'll need to add UI for:
1. Purchase details screen - show payment status and add payment button
2. Purchase payment modal/screen - enter payment details
3. Purchase payment list - show all payments with edit/delete
4. Debit note details screen - show refund status and add refund button
5. Debit note refund modal/screen - enter refund details
6. Debit note refund list - show all refunds with edit/delete
7. Purchase list screen - show payment status badge/indicator
8. Purchase returns screen - show refund status badge/indicator

All UI can follow the exact same pattern as bills/credit notes screens.
