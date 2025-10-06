# Transactions Module Documentation

## Overview
The Transactions module manages all transaction-related operations in the MotoBill application. It features a horizontal tab bar interface for easy navigation between different transaction types.

## Module Structure

```
lib/view/screens/
├── transactions_screen.dart           # Main transactions screen with TabBar
└── transactions/                      # Transaction module screens
    ├── sales_screen.dart              # Sales/Invoice management
    ├── sales_returns_screen.dart      # Sales returns (Credit Notes)
    ├── purchase_screen.dart           # Purchase management
    └── purchase_returns_screen.dart   # Purchase returns (Debit Notes)
```

## Features

### Horizontal Tab Navigation
- **4 Transaction Types**: Sales, Sales Returns (Credit Notes), Purchase, Purchase Return (Debit Notes)
- **Evenly Spread Tabs**: Tabs are distributed evenly across the full width
- **Apple-Inspired Design**: System Blue accent for selected tab
- **Compact Layout**: Minimal vertical padding for space efficiency

### Design Specifications

#### Tab Bar Styling
- **Background**: Pure White (#FFFFFF)
- **Border**: Bottom border with System Gray 5 (#E5E5EA, 1px)
- **Selected Tab**:
  - Text: System Blue (#007AFF)
  - Font: Roboto w600 (semi-bold)
  - Font Size: 15px
  - Letter Spacing: 0.3px
  - Indicator: 3px System Blue bottom line
- **Unselected Tab**:
  - Text: Secondary text color (#3C3C43)
  - Font: Roboto w500 (medium)
  - Font Size: 15px
  - Letter Spacing: 0.3px
- **Padding**: Horizontal only (12px) - no vertical padding for compact design
- **Indicator Size**: Full tab width

#### Screen Layout
Each transaction screen follows consistent design:
- **Centered Content**: Icon, title, and description centered vertically
- **Icon**: Large size (iconXL * 2) in System Blue
- **Title**: XXL font size, Roboto w600, primary text color
- **Description**: Large font size, Roboto normal, secondary text color
- **Spacing**: Consistent padding using AppSizes constants

## Transaction Modules

### 1. Sales
- **Icon**: Icons.point_of_sale
- **Purpose**: Manage sales invoices/bills
- **Future Features**:
  - Create new sales invoices
  - View/Edit existing invoices
  - Print invoices
  - GST calculation
  - Payment tracking
  - Customer selection
  - Product selection with stock verification

### 2. Sales Returns (Credit Notes)
- **Icon**: Icons.assignment_return
- **Purpose**: Manage sales returns and credit notes
- **Future Features**:
  - Create credit notes against invoices
  - Return product items
  - Update stock (FIFO-based batch returns)
  - GST adjustments
  - Refund processing
  - Link to original invoice

### 3. Purchase
- **Icon**: Icons.shopping_cart
- **Purpose**: Manage purchase orders/bills
- **Future Features**:
  - Create purchase orders
  - Record purchases from vendors
  - Stock entry (FIFO batch creation)
  - GST input tax credit
  - Payment tracking
  - Vendor selection
  - Product selection

### 4. Purchase Return (Debit Notes)
- **Icon**: Icons.undo
- **Purpose**: Manage purchase returns and debit notes
- **Future Features**:
  - Create debit notes against purchases
  - Return products to vendor
  - Update stock (FIFO-based batch returns)
  - GST adjustments
  - Payment adjustments
  - Link to original purchase

## Technical Implementation

### TransactionsScreen (StatefulWidget)
```dart
class TransactionsScreen extends StatefulWidget with SingleTickerProviderStateMixin
```

**Key Components:**
- `TabController`: Manages tab selection and animation
- `_tabs`: List of 4 tab labels
- `_tabScreens`: List of corresponding screen widgets
- `_buildTabBar()`: Builds the horizontal tab bar with modern styling

**State Management:**
- Tab controller initialized in `initState()`
- Properly disposed in `dispose()` to prevent memory leaks
- Uses `SingleTickerProviderStateMixin` for tab animations

### Individual Transaction Screens (StatelessWidget)
Each screen is a simple stateless widget displaying placeholder content:
- Consistent layout and styling
- Proper use of AppColors and AppSizes constants
- Roboto font family applied
- Ready for CRUD functionality implementation

## Navigation

Users can access the Transactions module by:
1. Clicking "Transactions" in the sidebar navigation (between Desktop and Masters)
2. Switching between transaction types using the horizontal tab bar
3. Swiping left/right in TabBarView (touch support)

## Future Development

### Phase 1: Sales Invoice Implementation
1. Create repository classes for sales transactions
2. Create ViewModel with Riverpod
3. Implement invoice creation form
4. Product selection with stock verification
5. GST calculation
6. Customer selection
7. Payment entry
8. Print invoice functionality

### Phase 2: Purchase Implementation
1. Purchase order creation
2. Vendor selection
3. Product entry with batch details
4. Stock batch creation (FIFO)
5. GST input credit
6. Payment tracking

### Phase 3: Returns Implementation
1. Sales returns (Credit Notes)
   - Link to original invoice
   - Select items to return
   - Update stock batches (FIFO)
   - GST adjustments
   - Refund processing

2. Purchase returns (Debit Notes)
   - Link to original purchase
   - Select items to return
   - Update stock batches (FIFO)
   - GST adjustments
   - Payment adjustments

### Phase 4: Advanced Features
1. Transaction search and filter
2. Date range selection
3. Transaction reports
4. Payment status tracking
5. Outstanding reports
6. GST reports
7. Export to Excel/PDF
8. Transaction approval workflow
9. Barcode scanning for products
10. Keyboard shortcuts for faster data entry

## Database Tables (Reference)

Based on existing schema, these transaction modules will interact with:
- `bills` table (for Sales)
- `bill_items` table (for Sales line items)
- `credit_notes` table (for Sales Returns)
- `credit_note_items` table (for Sales Return line items)
- `credit_note_batch_returns` table (for stock batch updates)
- `purchases` table (for Purchase)
- `purchase_items` table (for Purchase line items)
- `stock_batches` table (for inventory tracking - FIFO)
- `debit_notes` table (for Purchase Returns)
- `debit_note_items` table (for Purchase Return line items)
- `debit_note_batch_returns` table (for stock batch updates)
- `customers` table
- `vendors` table
- `products` table

## Code Quality Guidelines

### When implementing transaction operations:

1. **Follow MVVM Architecture**:
   - Models in `lib/model/`
   - Repositories in `lib/repository/`
   - ViewModels in `lib/view_model/`
   - Views remain in `lib/view/screens/transactions/`

2. **Use Riverpod for State Management**:
   - Create providers for each repository
   - Create StateNotifier ViewModels
   - Watch providers in screens

3. **Database Operations**:
   - Use raw SQL queries in repositories
   - Always use parameterized queries (`?`)
   - Implement soft delete (is_deleted = 1)
   - Handle transactions for multi-table updates
   - FIFO stock batch management

4. **GST Compliance**:
   - Proper GST calculations (CGST, SGST, IGST)
   - HSN/SAC code validation
   - Tax rate verification
   - GST report generation

5. **UI Consistency**:
   - Use AppColors for all colors
   - Use AppSizes for spacing and fonts
   - Apply Roboto font family
   - Follow Apple-inspired design principles

6. **Validation**:
   - Required field validation
   - Numeric validation
   - Date validation
   - Stock availability check
   - Duplicate prevention

## Color Constants Used

All colors from `lib/core/constants/app_colors.dart`:
- `AppColors.background` - Pure white background
- `AppColors.primary` - System Blue for accents
- `AppColors.textPrimary` - Black for main text
- `AppColors.textSecondary` - Gray for secondary text
- `AppColors.border` - Gray for borders

## Size Constants Used

All sizes from `lib/core/constants/app_sizes.dart`:
- `AppSizes.iconXL` - Screen icons
- `AppSizes.fontXXL` - Screen titles
- `AppSizes.fontL` - Screen descriptions
- `AppSizes.paddingM` - General padding
- `AppSizes.paddingL` - Large padding

## Version History

### v1.0 (Current)
- Initial implementation with 4 transaction modules
- Horizontal tab bar navigation
- Placeholder screens for each module
- Apple-inspired compact design with Roboto font
- Full folder structure ready for implementation
- Integrated into sidebar navigation between Desktop and Masters

### Future Versions
- v2.0: Sales invoice implementation
- v3.0: Purchase implementation
- v4.0: Sales returns (Credit Notes) implementation
- v5.0: Purchase returns (Debit Notes) implementation
- v6.0: Advanced features and reports
