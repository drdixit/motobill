# UI Improvements: Tabular Format & Unmatched Items Display

## Changes Made

### 1. Fixed Vendor Dropdown Overflow
**File**: `lib/view/screens/dashboard/purchase_bill_preview_screen.dart`

**Problem**: Multi-line dropdown items with vendor name and GSTIN were causing bottom overflow when many vendors existed.

**Solution**:
- Simplified dropdown items to single line showing "Name (GSTIN)"
- Added `menuMaxHeight: 300` to constrain dropdown height
- Added `overflow: TextOverflow.ellipsis` for long names

```dart
DropdownButton<int>(
  menuMaxHeight: 300, // Fixed height to prevent overflow
  items: state.availableVendors.map((vendor) {
    return DropdownMenuItem<int>(
      value: vendor.id,
      child: Text(
        vendor.gstNumber != null && vendor.gstNumber!.isNotEmpty
            ? '${vendor.name} (${vendor.gstNumber})'
            : vendor.name,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }).toList(),
)
```

### 2. Converted Items Display to DataTable Format
**File**: `lib/view/screens/dashboard/purchase_bill_preview_screen.dart`

**Changes**:
- Replaced ListView with card-based items with `DataTable` widget
- Added horizontal scrolling for wide tables
- Columns: Approve checkbox, Part Number, Description, HSN, Qty, UQC, Rate, Amount
- Green background for approved items
- Better scanability and professional appearance

**Matched Items Table**:
```dart
DataTable(
  columns: [
    'Approve', 'Part Number', 'Description',
    'HSN', 'Qty', 'UQC', 'Rate', 'Amount'
  ],
  rows: List.generate(invoice.items.length, (index) {
    final item = invoice.items[index];
    return DataRow(
      color: item.isApproved ? Colors.green[50] : null,
      cells: [/* ... */],
    );
  }),
)
```

### 3. Added Unmatched Items Section
**Files**:
- `lib/view_model/purchase_bill_automation_viewmodel.dart`
- `lib/view/screens/dashboard/purchase_bill_preview_screen.dart`

**State Changes**:
- Added `unmatchedItems` list to `PurchaseBillAutomationState`
- Updated `parseInvoiceResponse()` to store unmatched items in state
- Added to `copyWith()` method for immutable state updates

**UI Changes**:
- Created new `_buildUnmatchedItemsSection()` widget
- Orange-themed section to distinguish from matched items
- Shows warning icon and count
- Displays explanation message
- Shows unmatched items in separate DataTable (no approval checkboxes)
- Only visible if `state.unmatchedItems.isNotEmpty`

**Visual Design**:
- Orange background (`Colors.orange[50]`)
- Orange border (`Colors.orange[200]`)
- Warning icon for visibility
- Clear messaging: "Products NOT found in database"
- Instructions: "Add them to your database and re-parse to include them"

### 4. Layout Order
```
1. Invoice Header (number, date)
2. Vendor Info (with selection dropdown if not found)
3. Bill-Level Taxable Toggle
4. Matched Items Table (green section)
5. Unmatched Items Section (orange section) - conditional
6. Totals Summary
7. Create Purchase Bill Button (bottom)
```

## Benefits

### User Experience
✅ No more dropdown overflow - smooth vendor selection
✅ Tabular format easier to scan and read
✅ Clear visual distinction between matched (green) and unmatched (orange) items
✅ Full transparency - user sees what will be included and what won't
✅ Helpful guidance on how to include excluded items

### Data Visibility
✅ All parsed items are now visible (previously unmatched were only in console)
✅ User can review excluded items before creating bill
✅ Can manually add missing products and re-parse

### Performance
✅ No changes to existing performance optimizations
✅ Still using filter-during-parse approach
✅ Still lazy-loading vendors only when needed

## Testing Checklist

- [ ] Upload invoice with all products in database
  - Should show all items in "Matched Items" table
  - "Excluded Items" section should not appear

- [ ] Upload invoice with some products missing
  - Should show matched products in green section
  - Should show unmatched products in orange section
  - Counts should be accurate

- [ ] Test vendor dropdown with many vendors
  - Should not overflow screen
  - Should scroll within constrained height (300px)
  - Should show vendor name and GSTIN in single line

- [ ] Test item approval checkboxes
  - Should toggle on/off
  - Row should turn green when approved
  - Should work in DataTable format

- [ ] Test horizontal scrolling
  - Tables should scroll horizontally if too wide
  - All columns should be visible with scrolling

## Code Structure

### State Management (Riverpod)
```dart
class PurchaseBillAutomationState {
  final ParsedInvoice? parsedInvoice;      // Only matched items
  final List<ParsedInvoiceItem> unmatchedItems; // Items not found
  final List<Vendor> availableVendors;
  // ... other fields
}
```

### ViewModel Logic
```dart
// During parse:
for (item in parsed.items) {
  product = await getProductByPartNumber(item.partNumber);
  if (product != null) {
    matchedItems.add(item);
    productMatches[index] = product.id;
  } else {
    unmatchedItems.add(item);
  }
}

// Store both lists in state
state = state.copyWith(
  parsedInvoice: ParsedInvoice(items: matchedItems),
  unmatchedItems: unmatchedItems,
);
```

### UI Components
1. `_buildItemsTable()` - Matched items DataTable
2. `_buildUnmatchedItemsSection()` - Excluded items DataTable
3. Conditional rendering based on `state.unmatchedItems.isNotEmpty`

## Notes

- Removed old `_buildItemRow()` method (no longer used)
- DataTable uses `SingleChildScrollView` with `Axis.horizontal`
- Description column has fixed width (200px) with ellipsis overflow
- Amount field uses `totalAmount` from `ParsedInvoiceItem` model
- Both tables use same column structure (except matched has approval checkbox)
