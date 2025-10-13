# POS (Point of Sale) Feature Documentation

## Overview
The POS screen is a comprehensive point-of-sale interface for the MotoBill application. It provides a three-panel layout for efficient product selection and billing.

## Architecture

### MVVM Pattern
Following the project's MVVM architecture:
- **Model**: `PosProduct` - Enhanced product model with joined data
- **View**: `PosScreen`, `PosFilters`, `PosProductCard`, `PosCart` - UI components
- **ViewModel**: `PosViewModel` - Business logic and state management
- **Repository**: `PosRepository` - Database operations

### State Management
Uses **Riverpod** exclusively for state management as per project guidelines.

## Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│                        AppBar                                │
├──────────┬─────────────────────────────┬────────────────────┤
│          │                             │                    │
│ Filters  │     Products Grid          │       Cart         │
│ (Left)   │       (Middle)             │      (Right)       │
│ 280px    │        Flexible            │       380px        │
│          │                             │                    │
└──────────┴─────────────────────────────┴────────────────────┘
```

### 1. Left Panel - Filters (280px)
**Location**: `lib/view/widgets/pos/pos_filters.dart`

Features:
- **Search Bar**: Real-time product search
- **Main Category Filter**: Select from available main categories
- **Sub Category Filter**: Dynamically shown based on main category selection
- **Manufacturer Filter**: Filter products by manufacturer
- **Clear All**: Reset all filters at once

Implementation:
- Uses `ConsumerStatefulWidget` to manage search controller
- Real-time filtering with debounced search
- Visual feedback for selected filters

### 2. Middle Panel - Products Grid
**Location**: `lib/view/screens/pos_screen.dart`

Features:
- **Responsive Grid**: Auto-adjusts based on available space
- **Product Cards**: Shows image, name, part number, price, manufacturer
- **Click to Add**: Clicking any product adds it to cart
- **Loading States**: Shows spinner while loading
- **Empty State**: User-friendly message when no products found
- **Error Handling**: Displays errors gracefully

Product Card Details (`lib/view/widgets/pos/pos_product_card.dart`):
- Product image (with fallback to placeholder icon)
- Product name (2 lines max)
- Part number (if available)
- Selling price (prominent display)
- Manufacturer name

### 3. Right Panel - Cart (380px)
**Location**: `lib/view/widgets/pos/pos_cart.dart`

Features:
- **Cart Items List**: Scrollable list of added products
- **Quantity Controls**: +/- buttons to adjust quantity
- **Remove Item**: Delete button for each item
- **Price Calculation**: Real-time subtotal, tax, and total
- **GST Display**: Shows tax breakdown (CGST/SGST)
- **Clear Cart**: Remove all items at once
- **Checkout Button**: Ready for checkout flow integration

Cart Summary:
- Subtotal (before tax)
- Tax Amount (GST calculation)
- Total Amount (bold, prominent)
- Item count badge in header

## Database Schema

### PosProduct (Enhanced Model)
Joins multiple tables for efficient data retrieval:
- `products` table
- `hsn_codes` table
- `uqcs` table
- `sub_categories` table
- `main_categories` table
- `manufacturers` table
- `product_images` table (primary image only)

### SQL Query
The repository uses a complex JOIN query to fetch all necessary data in one call:
```sql
SELECT
  p.id, p.name, p.part_number, p.selling_price, p.cost_price,
  p.is_taxable, p.hsn_code_id, p.uqc_id, p.sub_category_id, p.manufacturer_id,
  h.code as hsn_code, u.code as uqc_code,
  sc.name as sub_category_name, mc.name as main_category_name,
  m.name as manufacturer_name, pi.image_path
FROM products p
LEFT JOIN hsn_codes h ON p.hsn_code_id = h.id
LEFT JOIN uqcs u ON p.uqc_id = u.id
LEFT JOIN sub_categories sc ON p.sub_category_id = sc.id
LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
LEFT JOIN manufacturers m ON p.manufacturer_id = m.id
LEFT JOIN (SELECT product_id, image_path FROM product_images
           WHERE is_primary = 1 AND is_deleted = 0) pi ON p.id = pi.product_id
WHERE p.is_deleted = 0 AND p.is_enabled = 1
```

## State Management

### PosState
Manages the complete state:
```dart
- allProducts: List<PosProduct>          // All products
- filteredProducts: List<PosProduct>     // After filtering
- cartItems: List<BillItem>              // Cart contents
- mainCategories: List<MainCategory>     // Filter options
- subCategories: List<SubCategory>       // Dynamic sub-categories
- manufacturers: List<Manufacturer>      // Filter options
- selectedMainCategoryId: int?           // Current filter
- selectedSubCategoryId: int?            // Current filter
- selectedManufacturerId: int?           // Current filter
- searchQuery: String                    // Search text
- isLoading: bool                        // Loading state
- error: String?                         // Error message
```

### PosViewModel Methods
```dart
// Initialization
loadInitialData()                        // Load all data on startup

// Filter Management
selectMainCategory(int? categoryId)     // Filter by main category
selectSubCategory(int? subCategoryId)   // Filter by sub category
selectManufacturer(int? manufacturerId) // Filter by manufacturer
setSearchQuery(String query)            // Search products
clearFilters()                          // Reset all filters

// Cart Management
addToCart(PosProduct product)           // Add product to cart
updateCartItemQuantity(int productId, int qty) // Change quantity
removeFromCart(int productId)           // Remove item
clearCart()                             // Empty cart

// Internal
_applyFilters()                         // Apply all active filters
_createBillItem(PosProduct, int qty)    // Convert to BillItem with tax
```

## Tax Calculation

### Current Implementation
Simple GST calculation (18% total):
- **CGST**: 9%
- **SGST**: 9%
- **IGST**: 0% (not currently used)
- **UTGST**: 0% (not currently used)

### Tax Logic
```dart
if (product.isTaxable) {
  cgstRate = 9.0;
  sgstRate = 9.0;
  cgstAmount = subtotal * 9 / 100;
  sgstAmount = subtotal * 9 / 100;
  taxAmount = cgstAmount + sgstAmount;
}
totalAmount = subtotal + taxAmount;
```

## Features to Enhance (Future)

1. **Checkout Flow**
   - Customer selection
   - Payment method
   - Bill generation
   - Print receipt
   - Stock deduction

2. **Advanced Filtering**
   - Price range filter
   - Stock availability filter
   - Recently added products
   - Best sellers

3. **Product Management from POS**
   - Quick add product
   - Update stock
   - Price override for discounts

4. **Cart Features**
   - Save cart for later
   - Apply discount codes
   - Multiple payment methods
   - Split payment

5. **Barcode/QR Scanner**
   - Quick product lookup
   - Scan to add to cart

6. **Keyboard Shortcuts**
   - Quick navigation
   - Fast product search
   - Keyboard-based checkout

7. **Stock Visibility**
   - Show available stock
   - Low stock warning
   - Out of stock indication

8. **Customer History**
   - Quick access to past orders
   - Favorite products
   - Credit limit check

## File Structure

```
lib/
├── model/
│   └── pos_product.dart                 # Enhanced product model
├── repository/
│   └── pos_repository.dart              # Database operations
├── view_model/
│   └── pos_viewmodel.dart               # Business logic & state
├── view/
│   ├── screens/
│   │   └── pos_screen.dart              # Main POS screen
│   └── widgets/
│       └── pos/
│           ├── pos_filters.dart         # Filter panel
│           ├── pos_product_card.dart    # Product card widget
│           └── pos_cart.dart            # Cart panel
└── core/
    └── providers/
        └── database_provider.dart       # Database instance
```

## Navigation

Access POS screen from:
1. **Sidebar Menu**: Click "POS" in the left sidebar
2. **App Bar**: Open sidebar menu → Select "POS"

Index in main navigation: **1** (second item after Dashboard)

## Design Principles

Following project guidelines:
- **Simple & Clean**: Minimalist Apple-inspired design
- **Modular**: Each widget has single responsibility
- **Type-safe**: Strong typing throughout
- **Soft Delete**: No physical deletion of records
- **Direct SQL**: Raw queries, no ORM
- **MVVM**: Strict layer separation
- **Riverpod**: Exclusive state management

## Testing

### Manual Testing Checklist
- [ ] Filters update products correctly
- [ ] Search works in real-time
- [ ] Products can be added to cart
- [ ] Quantity updates work
- [ ] Remove from cart works
- [ ] Clear cart empties all items
- [ ] Tax calculations are correct
- [ ] Totals update in real-time
- [ ] Loading states display properly
- [ ] Error handling works
- [ ] Images load correctly
- [ ] Empty states show appropriately

## Performance Considerations

1. **Efficient Queries**: Single JOIN query fetches all needed data
2. **Lazy Loading**: Products loaded on demand
3. **Debounced Search**: Prevents excessive filtering
4. **Optimized Images**: Only primary images loaded
5. **State Caching**: Filtered results cached until filters change

## Dependencies

All dependencies already in `pubspec.yaml`:
- `flutter_riverpod`: State management
- `sqflite_common_ffi`: Database operations
- `flutter`: UI framework

No additional dependencies required!

## Color Scheme

Uses app-wide colors from `AppColors`:
- **Primary**: #007AFF (System Blue)
- **Background**: #FFFFFF (Pure White)
- **Surface**: #FFFFFF
- **Text Primary**: #000000
- **Text Secondary**: #3C3C43
- **Border**: #E5E5EA
- **Success**: #34C759
- **Error**: #FF3B30

## Accessibility

- High contrast text and backgrounds
- Proper touch targets (48x48 minimum)
- Clear visual feedback
- Icon + text labels
- Error messages displayed clearly

## Known Limitations

1. **Checkout**: Not yet implemented - shows placeholder message
2. **Tax Rates**: Fixed at 18% - needs dynamic rate lookup
3. **Stock Check**: No stock validation before adding to cart
4. **Customer Selection**: Not integrated yet
5. **Print Receipt**: Not implemented

## Summary

The POS feature is fully functional for product browsing, filtering, and cart management. It follows all project guidelines and is ready for the checkout flow integration. The code is clean, modular, and maintainable, making it easy to extend with additional features.
