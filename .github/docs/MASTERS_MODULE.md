# Masters Module Documentation

## Overview
The Masters module provides centralized management for all master data in the MotoBill application. It features a horizontal tab bar interface for easy navigation between different master data screens.

## Module Structure

```
lib/view/screens/
├── masters_screen.dart              # Main masters screen with TabBar
└── masters/                         # Master module screens
    ├── customers_screen.dart        # Customer management
    ├── vendors_screen.dart          # Vendor management
    ├── main_categories_screen.dart  # Main category management
    ├── sub_categories_screen.dart   # Sub category management
    ├── products_screen.dart         # Product management
    ├── vehicles_screen.dart         # Vehicle management
    └── manufacturers_screen.dart    # Manufacturer management
```

## Features

### Horizontal Tab Navigation
- **7 Master Modules**: Customers, Vendors, Main Categories, Sub Categories, Products, Vehicles, Manufacturers
- **Scrollable Tabs**: Tabs scroll horizontally to accommodate all modules
- **Apple-Inspired Design**: System Blue accent for selected tab
- **Smooth Transitions**: TabBarView provides smooth swipe navigation between screens

### Design Specifications

#### Tab Bar Styling
- **Background**: Pure White (#FFFFFF)
- **Border**: Bottom border with System Gray 5 (#E5E5EA, 0.5px)
- **Selected Tab**:
  - Text: System Blue (#007AFF)
  - Font: Roboto w600 (semi-bold)
  - Indicator: 2px System Blue bottom line
- **Unselected Tab**:
  - Text: Secondary text color (#3C3C43)
  - Font: Roboto normal
- **Alignment**: Left-aligned with horizontal padding

#### Screen Layout
Each master screen follows consistent design:
- **Centered Content**: Icon, title, and description centered vertically
- **Icon**: Large size (iconXL * 2) in System Blue
- **Title**: XXL font size, Roboto w600, primary text color
- **Description**: Large font size, Roboto normal, secondary text color
- **Spacing**: Consistent padding using AppSizes constants

## Master Modules

### 1. Customers
- **Icon**: Icons.people
- **Purpose**: Manage customer information
- **Future Features**: CRUD operations for customer records

### 2. Vendors
- **Icon**: Icons.business
- **Purpose**: Manage vendor/supplier information
- **Future Features**: CRUD operations for vendor records

### 3. Main Categories
- **Icon**: Icons.category
- **Purpose**: Manage top-level product categories
- **Future Features**: CRUD operations for main category records

### 4. Sub Categories
- **Icon**: Icons.label
- **Purpose**: Manage product sub-categories
- **Future Features**: CRUD operations for sub-category records (linked to main categories)

### 5. Products
- **Icon**: Icons.inventory_2
- **Purpose**: Manage product/item information
- **Future Features**: CRUD operations for product records

### 6. Vehicles
- **Icon**: Icons.two_wheeler
- **Purpose**: Manage vehicle information for automobile business
- **Future Features**: CRUD operations for vehicle records

### 7. Manufacturers
- **Icon**: Icons.factory
- **Purpose**: Manage manufacturer/brand information
- **Future Features**: CRUD operations for manufacturer records

## Technical Implementation

### MastersScreen (StatefulWidget)
```dart
class MastersScreen extends StatefulWidget with SingleTickerProviderStateMixin
```

**Key Components:**
- `TabController`: Manages tab selection and animation
- `_tabs`: List of tab labels
- `_tabScreens`: List of corresponding screen widgets
- `_buildTabBar()`: Builds the horizontal tab bar with Apple styling

**State Management:**
- Tab controller initialized in `initState()`
- Properly disposed in `dispose()` to prevent memory leaks
- Uses `SingleTickerProviderStateMixin` for tab animations

### Individual Master Screens (StatelessWidget)
Each screen is a simple stateless widget displaying placeholder content:
- Consistent layout and styling
- Proper use of AppColors and AppSizes constants
- Roboto font family applied
- Ready for CRUD functionality implementation

## Future Development

### Phase 1: Data Display
1. Create repository classes for each master module
2. Create ViewModel classes with Riverpod
3. Implement data fetching from SQLite database
4. Display data in lists/tables

### Phase 2: CRUD Operations
1. **Create**: Add new records with forms
2. **Read**: Display records in tables/lists with search and filters
3. **Update**: Edit existing records
4. **Delete**: Soft delete records (is_deleted flag)

### Phase 3: Advanced Features
1. Search and filter functionality
2. Sorting options
3. Pagination for large datasets
4. Export to Excel/PDF
5. Import from CSV/Excel
6. Validation rules
7. Duplicate detection

## Database Tables (Reference)

Based on existing schema, these master modules will interact with:
- `customers` table (for Customers module)
- `vendors` table (for Vendors module)
- `main_categories` table (for Main Categories)
- `sub_categories` table (for Sub Categories)
- `products` table (for Products)
- `vehicles` table (for Vehicles)
- `manufacturers` table (for Manufacturers)

## Code Quality Guidelines

### When implementing CRUD operations:

1. **Follow MVVM Architecture**:
   - Models in `lib/model/`
   - Repositories in `lib/repository/`
   - ViewModels in `lib/view_model/`
   - Views remain in `lib/view/screens/masters/`

2. **Use Riverpod for State Management**:
   - Create providers for each repository
   - Create StateNotifier ViewModels
   - Watch providers in screens

3. **Database Operations**:
   - Use raw SQL queries in repositories
   - Always use parameterized queries (`?`)
   - Implement soft delete (is_deleted = 1)
   - Handle errors with try-catch

4. **UI Consistency**:
   - Use AppColors for all colors
   - Use AppSizes for spacing and fonts
   - Apply Roboto font family
   - Follow Apple-inspired design principles

5. **Keep Code Simple**:
   - Small, focused functions
   - Clear naming conventions
   - One class per file
   - Minimal complexity

## Navigation

Users can access the Masters module by:
1. Clicking "Masters" in the sidebar navigation
2. Switching between master modules using the horizontal tab bar
3. Swiping left/right in TabBarView (touch support)

## Color Constants Used

All colors from `lib/core/constants/app_colors.dart`:
- `AppColors.background` - Pure white background
- `AppColors.primary` - System Blue for accents
- `AppColors.textPrimary` - Black for main text
- `AppColors.textSecondary` - Gray for secondary text
- `AppColors.border` - Gray for borders

## Size Constants Used

All sizes from `lib/core/constants/app_sizes.dart`:
- `AppSizes.fontM` - Tab labels
- `AppSizes.fontXXL` - Screen titles
- `AppSizes.fontL` - Screen descriptions
- `AppSizes.iconXL` - Screen icons
- `AppSizes.paddingM` - General padding

## Version History

### v1.0 (Current)
- Initial implementation with 7 master modules
- Horizontal tab bar navigation
- Placeholder screens for each module
- Apple-inspired design with Roboto font
- Full folder structure ready for CRUD implementation

### Future Versions
- v2.0: Data display with listing functionality
- v3.0: CRUD operations implementation
- v4.0: Advanced features (search, filter, export)
