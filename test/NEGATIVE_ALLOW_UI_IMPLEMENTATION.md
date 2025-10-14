# negative_allow UI Implementation - Product Form

## Overview
Added UI checkbox in the Product Form Dialog to allow users to set/update the `negative_allow` flag when creating or editing products.

## Implementation

### Location
`lib/view/widgets/product_form_dialog.dart`

### Changes Made

#### 1. Added State Variable
```dart
late bool _negativeAllow;
```

#### 2. Initialized from Product Data
```dart
_negativeAllow = widget.product?.negativeAllow ?? false;
```
- New products: Default to `false` (requires sufficient stock)
- Editing products: Load current value from database

#### 3. Added Checkbox UI
**Position:** After "Taxable" and "Enabled" checkboxes

**UI Components:**
- Checkbox control
- Label: "Allow Negative Stock"
- Help text: "When enabled, bills can be created even when stock is insufficient. System will automatically create purchase records."

**Visual Layout:**
```
[ ] Allow Negative Stock
    When enabled, bills can be created even when stock is insufficient.
    System will automatically create purchase records.
```

#### 4. Updated Product Constructor
```dart
Product(
  // ... other fields
  negativeAllow: _negativeAllow,
)
```

## User Experience

### Creating New Product
1. Navigate to Masters > Products
2. Click "New Product" button
3. Fill in product details
4. **See "Allow Negative Stock" checkbox (unchecked by default)**
5. Check the box if you want to allow auto-purchase for this product
6. Save

**Result:** Product created with `negative_allow` set to chosen value

### Editing Existing Product
1. Navigate to Masters > Products
2. Click edit icon on any product
3. Form opens with all current values
4. **"Allow Negative Stock" checkbox shows current setting**
5. Change the checkbox as needed
6. Save

**Result:** Product updated with new `negative_allow` value

## Visual Design

### Checkbox Layout
```
┌─────────────────────────────────────────────────────────┐
│ [ ] Taxable          [ ] Enabled                        │
│                                                         │
│ [ ] Allow Negative Stock                               │
│     When enabled, bills can be created even when       │
│     stock is insufficient. System will automatically   │
│     create purchase records.                           │
└─────────────────────────────────────────────────────────┘
```

### Text Styling
- **Checkbox Label:** Medium font, semi-bold (fontWeight.w500)
- **Help Text:** Small font, gray color (Colors.grey[600])

## Behavior

### Checkbox State Changes
```dart
onChanged: (value) {
  setState(() {
    _negativeAllow = value ?? false;
  });
}
```

### Default Values
- **New Products:** `false` (unchecked)
- **Editing Products:** Current database value

### Validation
- No validation required (boolean field)
- Always has a valid value (true/false)

## Testing Steps

### Test 1: Create New Product with negative_allow = true
1. Click "New Product"
2. Fill in required fields
3. Check "Allow Negative Stock" checkbox
4. Save product

**Verify:**
```sql
SELECT id, name, negative_allow FROM products ORDER BY id DESC LIMIT 1;
```
Should show `negative_allow = 1`

### Test 2: Create New Product with negative_allow = false
1. Click "New Product"
2. Fill in required fields
3. Leave "Allow Negative Stock" unchecked
4. Save product

**Verify:**
```sql
SELECT id, name, negative_allow FROM products ORDER BY id DESC LIMIT 1;
```
Should show `negative_allow = 0`

### Test 3: Edit Product - Enable negative_allow
1. Select product with `negative_allow = 0`
2. Click edit
3. Check "Allow Negative Stock" checkbox
4. Save

**Verify:**
```sql
SELECT id, name, negative_allow FROM products WHERE id = ?;
```
Should show `negative_allow = 1`

### Test 4: Edit Product - Disable negative_allow
1. Select product with `negative_allow = 1`
2. Click edit
3. Uncheck "Allow Negative Stock" checkbox
4. Save

**Verify:**
```sql
SELECT id, name, negative_allow FROM products WHERE id = ?;
```
Should show `negative_allow = 0`

### Test 5: Edit Product - No Change
1. Select any product
2. Click edit
3. Don't change "Allow Negative Stock" checkbox
4. Modify other fields (e.g., price)
5. Save

**Verify:** `negative_allow` value unchanged in database

## Impact on Bill Creation

### Product with negative_allow = 1 (Checked)
**Behavior:** When stock insufficient during bill creation
- ✅ Auto-purchase created
- ✅ Bill succeeds
- ✅ User sees success

### Product with negative_allow = 0 (Unchecked)
**Behavior:** When stock insufficient during bill creation
- ❌ Error shown: "Insufficient stock for [Product]"
- ❌ Bill blocked
- ❌ User must adjust quantity or restock

## UI/UX Considerations

### Help Text Purpose
The descriptive help text explains:
1. **What it does:** Bills can be created without stock
2. **How it works:** System auto-creates purchase records
3. **When to use it:** For items where you want flexibility

### Checkbox Placement
Positioned after "Taxable" and "Enabled" because:
1. Related to product behavior settings
2. Important enough to be visible without scrolling
3. Grouped with other boolean flags
4. Has space for help text below

### Default State (Unchecked)
Conservative approach:
1. Protects new products from accidental overselling
2. User must explicitly enable flexible stock management
3. Aligns with existing products (all default to 0)

## Accessibility

- ✅ Checkbox is keyboard accessible
- ✅ Label text is clickable (taps checkbox)
- ✅ Help text provides context
- ✅ Visual contrast meets standards

## Code Quality

### State Management
- Uses local state (`_negativeAllow`)
- Updates via `setState()`
- Persisted via Product model

### Initialization
- Loads from existing product if editing
- Defaults to `false` for new products
- Handled in `initState()`

### Validation
- No validation needed (boolean)
- Always has valid value

## Integration Points

### Product Model
```dart
final bool negativeAllow;
```

### Database
```sql
products.negative_allow INTEGER NOT NULL DEFAULT 0
```

### Bill Creation
```dart
if (negativeAllow) {
  // Create auto-purchase
} else {
  // Throw error
}
```

## Files Modified

✅ `lib/view/widgets/product_form_dialog.dart`
- Added `_negativeAllow` state variable
- Added initialization from product data
- Added checkbox UI with help text
- Updated Product constructor call

## Success Criteria

✅ Checkbox visible in product form
✅ Default state: unchecked (false)
✅ Edit loads current value from database
✅ Saving updates database correctly
✅ Help text explains feature clearly
✅ No compilation errors
✅ UI responsive and accessible

## Status

🟢 **FULLY IMPLEMENTED**

Users can now control the `negative_allow` flag directly from the product form UI when creating or editing products.

---

**Implementation Date:** October 14, 2025
**Feature:** negative_allow checkbox in product form
**Location:** Masters > Products > New/Edit Product Dialog
