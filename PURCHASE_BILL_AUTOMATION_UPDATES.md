# Purchase Bill Automation Updates

## Summary of Changes

### 1. **Bill-Level Taxable/Non-Taxable Toggle** ✅
- **Change**: Replaced per-item taxable toggle with a single bill-level toggle
- **Location**: At the top of the preview screen, after vendor information
- **Behavior**:
  - Toggle applies to entire bill (all stock entries)
  - Options: "Taxable" or "Non-Taxable"
  - Default: Taxable
  - All approved items will be marked with the same stock type

**Visual**:
```
┌─────────────────────────────────────────┐
│ 📦 Stock Type (Entire Bill):           │
│              [Taxable] [Non-Taxable]    │
└─────────────────────────────────────────┘
```

---

### 2. **Vendor Selection Dropdown** ✅
- **Change**: If vendor not found by GSTIN, show dropdown to select from existing vendors
- **Location**: In the Vendor Information card
- **Behavior**:
  - If GSTIN match found → Shows "Found" badge, vendor pre-selected
  - If GSTIN not found → Shows "Not Found" badge + dropdown list
  - Dropdown shows: Vendor name + GSTIN
  - Must select a vendor before creating purchase bill

**Visual**:
```
┌─────────────────────────────────────────┐
│ Vendor Information          [Not Found] │
├─────────────────────────────────────────┤
│ Name: ABC Motors                        │
│ GSTIN: 29ABCDE1234F1Z5                  │
│ City: Bangalore                         │
│ State: Karnataka                        │
│                                         │
│ Select Existing Vendor:                 │
│ ┌─────────────────────────────────────┐ │
│ │ Choose a vendor...            ▼     │ │
│ └─────────────────────────────────────┘ │
│ ⚠ Please select a vendor to continue.  │
└─────────────────────────────────────────┘
```

---

### 3. **Product Selection Dropdown** ✅
- **Change**: If product not found by part number, show dropdown to select from existing products
- **Location**: Within each line item card
- **Behavior**:
  - If part number match found → Shows "Found" badge
  - If not found → Shows "Not Found" badge + dropdown list
  - Dropdown shows: Product name, part number, cost price
  - Searchable via typing in dropdown
  - Must select product for all approved items before creating bill

**Visual**:
```
┌─────────────────────────────────────────────┐
│ ☑ PART-123               [Not Found]       │
│   Engine Oil Filter                         │
├─────────────────────────────────────────────┤
│ Select Product:                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Choose a product...              ▼      │ │
│ └─────────────────────────────────────────┘ │
│ HSN: 8421   Qty: 10   UQC: NOS   ₹500.00  │
└─────────────────────────────────────────────┘
```

Dropdown items show:
```
Oil Filter - Premium Quality
PN: PART-456      ₹45.50
```

---

## Technical Implementation

### State Management Updates

#### New State Fields in `PurchaseBillAutomationState`:
```dart
final int? selectedVendorId;          // Manually selected vendor
final bool isBillTaxable;              // Global taxable flag (default: true)
final List<Vendor> availableVendors;  // All vendors for selection
final List<Product> availableProducts; // All products for selection
```

#### New ViewModel Methods:
```dart
void toggleBillTaxable()                    // Toggle bill-level taxable flag
void setVendor(int vendorId)                // Set selected vendor
void setProductForItem(int index, int id)   // Set product for specific item
```

---

## Workflow Changes

### Before:
```
1. Parse invoice
2. Auto-match vendor by GSTIN (required exact match)
3. Auto-match products by part number (required exact match)
4. Toggle each item as taxable/non-taxable individually
5. Approve items
6. Create purchase bill
```

### After:
```
1. Parse invoice
2. Load ALL vendors and products
3. Auto-match vendor by GSTIN
   ├─ If found: Pre-select vendor ✓
   └─ If NOT found: Show dropdown → User selects vendor
4. Auto-match products by part number
   ├─ If found: Mark as "Found" ✓
   └─ If NOT found: Show dropdown → User selects product
5. Set stock type for ENTIRE BILL (Taxable/Non-Taxable)
6. Approve items (checkbox per item)
7. Create purchase bill
   └─ Validation: Vendor selected? All approved items have product?
```

---

## Validation Rules

### Before Creating Purchase Bill:
1. ✅ **Vendor Selected**: Must have `selectedVendorId` set
   - Error: "Please select a vendor before creating the purchase bill"

2. ✅ **At Least One Approved Item**: Must approve at least one line item
   - Error: "No items approved. Please approve at least one item."

3. ✅ **All Approved Items Have Products**: Each approved item must have product selected
   - Error: "Item 'PART-123' needs a product selection. Please select a product."

4. ✅ **Invoice Data Valid**: Must have parsed invoice with items
   - Error: "Missing invoice data"

---

## UI Components Added

### 1. Bill Taxable Toggle (`_buildBillTaxableToggle`)
- Container with ChoiceChips
- Two options: Taxable (blue) / Non-Taxable (orange)
- Icon: 📦 (inventory icon)
- Calls: `viewModel.toggleBillTaxable()`

### 2. Vendor Selector (in `_buildVendorInfo`)
- Dropdown with all active vendors
- Shows vendor name + GSTIN
- Only visible when vendor not found
- Calls: `viewModel.setVendor(vendorId)`

### 3. Product Selector (`_buildProductSelector`)
- Dropdown with all products
- Shows product name, part number, cost price
- Red border to indicate action required
- Only visible when product not found
- Calls: `viewModel.setProductForItem(index, productId)`

---

## Database Behavior

### Stock Entry Creation:
- All approved items get same `is_taxable` flag from bill-level setting
- If bill is **Taxable** → `stock_batches.is_taxable = 1`
- If bill is **Non-Taxable** → `stock_batches.is_taxable = 0`

### Previous Behavior (REMOVED):
- Each item had individual taxable toggle
- Could mix taxable and non-taxable items in same bill
- More complex UI, less common use case

---

## Files Modified

### 1. `lib/view_model/purchase_bill_automation_viewmodel.dart`
**Changes**:
- ✅ Added `selectedVendorId` to state
- ✅ Added `isBillTaxable` to state (default: true)
- ✅ Added `availableVendors` list to state
- ✅ Added `availableProducts` list to state
- ✅ Added `toggleBillTaxable()` method
- ✅ Added `setVendor(int vendorId)` method
- ✅ Added `setProductForItem(int index, int productId)` method
- ✅ Updated `parseInvoiceResponse()` to load all vendors/products
- ✅ Updated `createPurchaseBill()` to:
  - Use `selectedVendorId` instead of `existingVendor.id`
  - Use `isBillTaxable` for all items
  - Validate vendor selection
  - Better error messages for product selection
- ✅ Deprecated `toggleItemTaxable()` method

### 2. `lib/view/screens/dashboard/purchase_bill_preview_screen.dart`
**Changes**:
- ✅ Added `_buildBillTaxableToggle()` widget
- ✅ Added `_buildProductSelector()` widget
- ✅ Updated `_buildVendorInfo()` to show vendor dropdown when not found
- ✅ Updated `_buildItemRow()` to:
  - Remove per-item taxable toggle
  - Add product selector when product not found
  - Show dropdown with product details
- ✅ Added viewModel parameter to `_buildVendorInfo()`

### 3. `lib/view_model/purchase_bill_automation_viewmodel.dart` (imports)
**Changes**:
- ✅ Added `import '../model/product.dart';`

---

## Testing Checklist

### Vendor Selection:
- [ ] Upload invoice with known vendor GSTIN
  - Should auto-select vendor
  - Should show "Found" badge
  - Dropdown should not appear

- [ ] Upload invoice with unknown vendor GSTIN
  - Should show "Not Found" badge
  - Should show dropdown with all vendors
  - Should display vendor name + GSTIN in dropdown
  - Should allow vendor selection

- [ ] Try to create bill without selecting vendor
  - Should show error: "Please select a vendor..."

### Product Selection:
- [ ] Invoice with known part numbers
  - Should show "Found" badge
  - No dropdown should appear

- [ ] Invoice with unknown part numbers
  - Should show "Not Found" badge
  - Should show red-bordered dropdown
  - Should display product name + part number + price
  - Should allow product selection

- [ ] Approve item without product selection
  - Should show error: "Item 'XXX' needs a product selection..."

### Bill Taxable Toggle:
- [ ] Default state should be "Taxable"
- [ ] Should be able to toggle to "Non-Taxable"
- [ ] Create bill with Taxable → verify stock_batches.is_taxable = 1
- [ ] Create bill with Non-Taxable → verify stock_batches.is_taxable = 0

### Complete Flow:
- [ ] Parse invoice successfully
- [ ] Select vendor (if needed)
- [ ] Select products for all items (if needed)
- [ ] Set bill taxable/non-taxable
- [ ] Approve items
- [ ] Create purchase bill
- [ ] Verify purchase created in database
- [ ] Verify stock batches created with correct is_taxable flag

---

## Benefits

### 1. **Simplified Stock Management**
- One decision for entire bill (realistic scenario)
- Less clicks for user
- Clearer intent

### 2. **Flexible Vendor/Product Matching**
- No longer blocks if GSTIN doesn't match
- Can manually select correct vendor
- Can manually map products
- Handles typos and variations in invoice data

### 3. **Better UX**
- Clear visual indicators (Found/Not Found badges)
- Dropdown shows relevant info (GSTIN, part number, price)
- Searchable dropdowns (type to filter)
- Validation messages guide user

### 4. **Database Safety**
- Still maintains data integrity
- Can't create bill without vendor
- Can't create bill with missing products
- All validations in place

---

## Migration Notes

### Breaking Changes:
- ❌ Per-item taxable toggle removed from UI
- ❌ `toggleItemTaxable(index)` marked as @Deprecated
- ✅ Old bills unaffected (existing data preserved)

### Backwards Compatibility:
- ✅ Old purchase bills continue to work
- ✅ Stock batches with mixed taxable flags still valid
- ✅ API response parsing unchanged
- ✅ Database schema unchanged

---

## Future Enhancements

### Possible Improvements:
1. **Search/Filter in Dropdowns**
   - Add TextField above dropdown for filtering
   - Filter by name, part number, GSTIN

2. **Fuzzy Matching**
   - Show "Similar vendors" if no exact GSTIN match
   - Suggest products with similar part numbers

3. **Quick Create Options**
   - "Create New Vendor" button in dropdown
   - "Create New Product" button in dropdown
   - Open dialog without leaving preview screen

4. **Smart Defaults**
   - Remember last selected vendor for next invoice
   - Auto-select if only one vendor/product matches partially

5. **Bulk Actions**
   - "Approve All" button
   - "Select All Products" (if confident in AI parsing)

---

**Last Updated**: November 6, 2025
**Version**: 2.0
**Status**: ✅ Implemented and Ready for Testing
