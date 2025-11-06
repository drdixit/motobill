# Purchase Bill Automation Enhancements

## Summary of Changes

### 1. Case-Insensitive Part Number Matching
**Problem**: "Dk181092" and "DK181092" were treated as different products.

**Solution**: Updated product repository to use case-insensitive matching.

**File**: `lib/repository/product_repository.dart`
```dart
// Before:
WHERE part_number = ?

// After:
WHERE LOWER(part_number) = LOWER(?)
```

**Result**: Part numbers now match regardless of case (DK181092 = dk181092 = Dk181092).

---

### 2. Auto-Fill HSN Code from Database
**Problem**: If invoice response doesn't include HSN code, items had empty HSN values.

**Solution**: When matching a product, if HSN code is missing from invoice, fetch it from the database.

**Files Modified**:
- `lib/view_model/purchase_bill_automation_viewmodel.dart`
  - Added `HsnCodeRepository` dependency
  - Enriches matched items with database HSN code when invoice HSN is empty

**Logic Flow**:
```
1. Match product by part number
2. If invoice HSN is empty:
   → Fetch HSN code from database using product.hsnCodeId
   → Use database HSN code
3. Create enriched item with correct HSN code
```

**Console Output**:
```
✓ MATCHED - Found product ID: 123, Name: Sample Product
→ Using HSN code from database: 84159090
```

---

### 3. Display Quantity as Integer
**Problem**: Quantities displayed with decimals (5.00, 10.00) unnecessarily.

**Solution**: Changed quantity display from `toStringAsFixed(2)` to `toString()`.

**Files Modified**:
- `lib/view/screens/dashboard/purchase_bill_preview_screen.dart`

**Result**:
- Before: 5.00, 10.00, 1.00
- After: 5, 10, 1

---

### 4. Expand Tables to Screen Edge
**Problem**: DataTables didn't utilize full width, leaving empty space.

**Solution**: Wrapped DataTables with LayoutBuilder and ConstrainedBox to expand to container width.

**Implementation**:
```dart
LayoutBuilder(
  builder: (context, constraints) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: constraints.maxWidth,
        ),
        child: DataTable(...)
      ),
    );
  },
)
```

**Result**: Tables now expand to fill available width while maintaining horizontal scroll for overflow.

---

### 5. Dynamic Total Recalculation
**Problem**: Totals remained static when approving/rejecting items.

**Solution**: Added `_recalculateTotals()` method that recalculates based on approved items only.

**Files Modified**:
- `lib/view_model/purchase_bill_automation_viewmodel.dart`

**Logic**:
```dart
void toggleItemApproval(int index) {
  // Toggle item
  items[index] = items[index].copyWith(isApproved: !isApproved);

  // Recalculate totals based on approved items only
  final updatedInvoice = _recalculateTotals(items);

  state = state.copyWith(parsedInvoice: updatedInvoice);
}

ParsedInvoice _recalculateTotals(List<ParsedInvoiceItem> items) {
  double subtotal = 0;
  double cgstAmount = 0;
  double sgstAmount = 0;
  double totalAmount = 0;

  for (final item in items) {
    if (item.isApproved) {
      subtotal += item.quantity * item.rate;
      cgstAmount += item.cgstAmount;
      sgstAmount += item.sgstAmount;
      totalAmount += item.totalAmount;
    }
  }

  return ParsedInvoice(...);
}
```

**Result**: Totals update dynamically as items are approved/rejected.

---

### 6. "Select All" Button
**Problem**: No quick way to approve all matched products.

**Solution**: Added "Select All Valid Products" button in matched items header.

**Files Modified**:
- `lib/view/screens/dashboard/purchase_bill_preview_screen.dart`
- `lib/view_model/purchase_bill_automation_viewmodel.dart`

**UI Placement**:
```
┌──────────────────────────────────────────────┐
│ ✓ Matched Items (5)  [Select All]  Products │
│                       found in database      │
└──────────────────────────────────────────────┘
```

**Implementation**:
```dart
// UI Button
ElevatedButton.icon(
  onPressed: () => viewModel.selectAllValidProducts(),
  icon: const Icon(Icons.check_box, size: 18),
  label: const Text('Select All'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green[600],
    foregroundColor: Colors.white,
  ),
)

// ViewModel Method
void selectAllValidProducts() {
  final items = state.parsedInvoice!.items
      .map((item) => item.copyWith(isApproved: true))
      .toList();

  final updatedInvoice = _recalculateTotals(items);
  state = state.copyWith(parsedInvoice: updatedInvoice);
}
```

**Result**: Single click approves all matched products and recalculates totals.

---

## Technical Implementation Details

### Repository Changes
**File**: `lib/repository/product_repository.dart`
- Changed `part_number = ?` to `LOWER(part_number) = LOWER(?)`
- Added `.trim()` to remove whitespace

### ViewModel Changes
**File**: `lib/view_model/purchase_bill_automation_viewmodel.dart`

**New Dependencies**:
- Added `HsnCodeRepository` import
- Added `_hsnRepoProvider`
- Updated constructor to accept HSN repository

**Enhanced Product Matching**:
```dart
for (item in parsed.items) {
  product = await getProductByPartNumber(item.partNumber);

  if (product != null) {
    // Get HSN from database if missing
    String finalHsnCode = item.hsnCode;
    if (finalHsnCode.isEmpty) {
      hsnCodeObj = await _hsnRepository.getHsnCodeById(product.hsnCodeId);
      if (hsnCodeObj != null) {
        finalHsnCode = hsnCodeObj.code;
      }
    }

    // Create enriched item
    enrichedItem = ParsedInvoiceItem(..., hsnCode: finalHsnCode);
    matchedItems.add(enrichedItem);
  } else {
    unmatchedItems.add(item);
  }
}
```

**New Methods**:
1. `selectAllValidProducts()` - Approves all items and recalculates
2. `_recalculateTotals()` - Private helper to sum approved items

### UI Changes
**File**: `lib/view/screens/dashboard/purchase_bill_preview_screen.dart`

**Matched Items Table**:
- Added "Select All" button in header
- Wrapped DataTable with LayoutBuilder → SingleChildScrollView → ConstrainedBox
- Changed quantity display from `.toStringAsFixed(2)` to `.toString()`

**Unmatched Items Table**:
- Same layout improvements (LayoutBuilder + ConstrainedBox)
- Same quantity display change

---

## Testing Checklist

### Case-Insensitive Matching
- [ ] Invoice with "DK181092" matches database "dk181092"
- [ ] Invoice with "dk181092" matches database "DK181092"
- [ ] Invoice with "Dk181092" matches database "DK181092"

### HSN Code Auto-Fill
- [ ] Invoice without HSN code → Product matched → HSN filled from database
- [ ] Invoice with HSN code → Product matched → Invoice HSN used (not overwritten)
- [ ] Invoice without HSN code → Product not found → Empty HSN shown

### Quantity Display
- [ ] Matched items show integer quantities (5, not 5.00)
- [ ] Unmatched items show integer quantities (10, not 10.00)

### Table Width
- [ ] Matched items table expands to full width
- [ ] Unmatched items table expands to full width
- [ ] Horizontal scroll appears when content too wide

### Total Recalculation
- [ ] Initial totals match invoice total
- [ ] Uncheck one item → Totals decrease
- [ ] Check item again → Totals increase
- [ ] Uncheck all items → Totals show zero
- [ ] Check all items → Totals match original

### Select All Button
- [ ] Button visible in matched items header
- [ ] Click button → All items checked
- [ ] Totals update to include all items
- [ ] Green highlighting applied to all rows

---

## User Experience Flow

### Complete Workflow
1. User uploads invoice PDF
2. Azure parses invoice (may have mixed case part numbers, missing HSN)
3. System matches products **case-insensitively**
4. System **auto-fills missing HSN codes** from database
5. Matched items appear with:
   - Correct HSN codes
   - **Integer quantities**
   - Full-width table
6. User can:
   - Click individual checkboxes (totals update)
   - Click **"Select All"** button (all checked, totals update)
   - Review unmatched items in separate section
7. User clicks "Create Purchase Bill"
8. Only approved items included in final bill

---

## Code Quality Notes

### Performance
- ✅ HSN lookup only occurs for matched items with missing HSN
- ✅ No extra queries for items that already have HSN
- ✅ Totals recalculated in memory (no database queries)

### Maintainability
- ✅ Case-insensitive matching isolated to repository
- ✅ HSN enrichment happens during parse phase
- ✅ Total recalculation is a pure function
- ✅ Select All uses existing toggle logic

### Error Handling
- ✅ Gracefully handles missing HSN in database
- ✅ Handles null/empty part numbers with trim()
- ✅ Totals always reflect current state

---

## Future Enhancements (Not Implemented)

### Potential Improvements
1. **Fuzzy Matching**: Match "DK-181092" with "DK181092" (ignore hyphens)
2. **Partial Selection**: "Select Taxable Only" or "Select Non-Taxable Only"
3. **Bulk Edit**: Change UQC or rate for multiple items at once
4. **Sort Columns**: Click column headers to sort
5. **Filter Items**: Search/filter items in table
6. **Export Preview**: Export to Excel before creating bill

---

## Breaking Changes
**None** - All changes are backward compatible.

## Migration Required
**None** - No database schema changes or data migration needed.
