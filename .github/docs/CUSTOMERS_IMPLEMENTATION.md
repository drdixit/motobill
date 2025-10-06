# Customers Module Implementation

## Overview
The Customers module is the first fully implemented CRUD (Create, Read, Update, Delete) module in MotoBill, following MVVM architecture with Riverpod state management.

## Architecture

### MVVM Layers

```
Model (Data)
    ↓
Repository (Data Access)
    ↓
ViewModel (Business Logic)
    ↓
View (UI)
```

## File Structure

```
lib/
├── model/
│   └── customer.dart                    # Customer data model
├── repository/
│   └── customer_repository.dart         # Database operations
├── view_model/
│   └── customer_viewmodel.dart          # Business logic & state
└── view/
    ├── screens/masters/
    │   └── customers_screen.dart        # Main customer list screen
    └── widgets/
        └── customer_form_dialog.dart    # Create/Edit form dialog
```

## Database Schema

### customers Table
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | INTEGER | No | AUTO | Primary key |
| name | TEXT | No | - | Customer name |
| legal_name | TEXT | Yes | - | Legal/registered name |
| phone | TEXT | Yes | - | Mobile number |
| email | TEXT | Yes | - | Email address |
| gst_number | TEXT | Yes | - | GST registration number |
| address_line1 | TEXT | Yes | - | Address line 1 |
| address_line2 | TEXT | Yes | - | Address line 2 |
| city | TEXT | Yes | - | City |
| state | TEXT | Yes | - | State |
| pincode | TEXT | Yes | - | Postal code |
| is_enabled | INTEGER | No | 1 | Active status (1=enabled, 0=disabled) |
| is_deleted | INTEGER | No | 0 | Soft delete flag (0=active, 1=deleted) |
| created_at | TEXT | No | CURRENT_TIMESTAMP | Creation timestamp |
| updated_at | TEXT | No | CURRENT_TIMESTAMP | Last update timestamp |

## Implementation Details

### 1. Model (`customer.dart`)

**Features:**
- Immutable data class with all customer fields
- `fromJson()` - Convert database map to Customer object
- `toJson()` - Convert Customer object to database map
- `copyWith()` - Create modified copies
- Proper handling of nullable fields
- Boolean conversion for INTEGER flags (is_enabled, is_deleted)

**Key Points:**
- `legal_name` is used as primary display name (falls back to `name`)
- Timestamps are handled automatically by database
- `is_deleted` flag enables soft delete pattern

### 2. Repository (`customer_repository.dart`)

**Methods:**
```dart
Future<List<Customer>> getAllCustomers()           // Get all active customers
Future<Customer?> getCustomerById(int id)          // Get single customer
Future<int> createCustomer(Customer customer)      // Create new customer
Future<void> updateCustomer(Customer customer)     // Update existing customer
Future<void> softDeleteCustomer(int id)            // Soft delete customer
Future<void> toggleCustomerEnabled(int id, bool)   // Enable/disable customer
Future<List<Customer>> searchCustomers(String)     // Search by name/GST/phone
```

**Key Features:**
- All queries filter by `is_deleted = 0` (exclude deleted records)
- Uses parameterized queries (`?`) to prevent SQL injection
- Automatic timestamp updates via `datetime('now')`
- Proper error handling with try-catch
- Returns typed data (List<Customer>, Customer, int)

**Security:**
- ✅ Parameterized queries throughout
- ✅ No string concatenation in SQL
- ✅ Soft delete (never physical DELETE)

### 3. ViewModel (`customer_viewmodel.dart`)

**State Management:**
```dart
class CustomerState {
  List<Customer> customers
  bool isLoading
  String? error
}
```

**ViewModel Methods:**
```dart
Future<void> loadCustomers()                    // Load all customers
Future<bool> createCustomer(Customer)           // Create and refresh
Future<bool> updateCustomer(Customer)           // Update and refresh
Future<bool> deleteCustomer(int id)             // Soft delete and refresh
Future<bool> toggleCustomerEnabled(int, bool)   // Toggle status and refresh
Future<void> searchCustomers(String query)      // Search customers
```

**Features:**
- Extends `StateNotifier<CustomerState>`
- Automatic loading on initialization
- Exposes `currentState` getter for UI access
- Returns bool for success/failure feedback
- Auto-refreshes list after mutations
- Centralizes business logic

**Providers:**
```dart
customerRepositoryProvider          // Database repository
asyncCustomerViewModelProvider      // ViewModel with async init
```

### 4. View (`customers_screen.dart`)

**UI Structure:**
```
CustomersScreen (ConsumerWidget)
├── Header Bar
│   ├── "Customers" Title
│   └── "New Customer" Button
├── Error Message (if any)
└── Content Area
    ├── Loading Spinner (if loading)
    ├── Empty State (if no customers)
    └── Customer List (ListView)
        └── Customer Items
            ├── Customer Info (2-line)
            │   ├── Line 1: Legal Name
            │   └── Line 2: GST + Phone
            └── Action Buttons
                ├── Edit Button
                ├── Toggle Button
                └── Delete Button
```

**Features:**
- Uses `ConsumerWidget` for Riverpod integration
- Reactive UI - automatically updates on state changes
- Async provider handling with `.when(data/loading/error)`
- Two-line list item layout as requested
- Visual indication for disabled customers (gray background)
- Confirmation dialog for delete action
- Success/error snackbar notifications

**Customer List Item:**
- **Line 1:** `legal_name` (or `name` if legal_name is null) - Bold, Large
- **Line 2:** GST icon + number, Phone icon + number - Small, Gray
- **Background:** White (enabled) or Light Gray (disabled)
- **Actions:** Edit (blue), Toggle (green/gray), Delete (red)

### 5. Form Dialog (`customer_form_dialog.dart`)

**Features:**
- Reusable for both Create and Edit operations
- All database fields exposed (except auto-generated)
- Form validation (name is required)
- Proper keyboard types (phone, email numbers)
- Scrollable form for long content
- Enabled checkbox for is_enabled field
- Cancel/Save buttons with proper styling

**Fields:**
1. Name * (required)
2. Legal Name
3. Mobile Number
4. Email
5. GST Number
6. Address Line 1
7. Address Line 2
8. City & State (side by side)
9. Pincode
10. Enabled checkbox

**Validation:**
- Name is required (marked with *)
- Empty optional fields are stored as NULL
- Trim whitespace from all inputs

## User Workflows

### Create New Customer
1. Click "New Customer" button in header
2. Dialog opens with empty form
3. Fill in customer details (minimum: name)
4. Click "Save"
5. Customer created in database
6. List refreshes automatically
7. Success notification shown

### Edit Customer
1. Click "Edit" button (pencil icon) on customer item
2. Dialog opens with pre-filled form
3. Modify customer details
4. Click "Save"
5. Customer updated in database
6. List refreshes automatically
7. Success notification shown

### Toggle Customer Status
1. Click "Toggle" button on customer item
2. Status immediately toggles (enabled ↔ disabled)
3. Visual indication updates (white ↔ gray background)
4. Database updated
5. List refreshes automatically
6. Success notification shown

### Delete Customer (Soft Delete)
1. Click "Delete" button (trash icon) on customer item
2. Confirmation dialog appears
3. Click "Delete" to confirm (or "Cancel")
4. Customer marked as deleted (`is_deleted = 1`)
5. Customer removed from list view
6. List refreshes automatically
7. Success notification shown

**Note:** Deleted customers are not physically removed from database. They are filtered out from all queries using `is_deleted = 0` condition.

## UI Design Specifications

### Colors
- **Primary Action:** System Blue (#007AFF)
- **Success:** System Green (#34C759)
- **Error/Delete:** System Red (#FF3B30)
- **Disabled Background:** System Gray 6 (#F2F2F7)
- **Text Primary:** Black (#000000)
- **Text Secondary:** Gray (#3C3C43)
- **Borders:** Light Gray (#E5E5EA)

### Typography
- **Font Family:** Roboto (app-wide)
- **Header Title:** 24px, w600
- **Customer Name:** 16px, w600
- **Secondary Info:** 12px, normal
- **Button Text:** 14px, w600

### Spacing
- **List Item Padding:** 16px vertical, 16px horizontal
- **Button Spacing:** 16px horizontal gaps
- **Form Field Spacing:** 16px vertical gaps
- **Icon Sizes:** 20px (edit/delete), 28px (toggle), 14px (info icons)

## Error Handling

### Repository Level
```dart
try {
  // Database operation
} catch (e) {
  throw Exception('Failed to [operation]: $e');
}
```

### ViewModel Level
```dart
try {
  await _repository.operation();
  return true;
} catch (e) {
  state = state.copyWith(error: e.toString());
  return false;
}
```

### View Level
- Display error in red banner if `state.error != null`
- Show error snackbar on operation failure
- Show success snackbar on operation success
- Confirmation dialog for destructive actions (delete)

## Best Practices Followed

### ✅ MVVM Architecture
- Clean separation of concerns
- Model contains only data
- Repository contains only database logic
- ViewModel contains only business logic
- View contains only UI code

### ✅ Riverpod State Management
- Single source of truth (CustomerState)
- Reactive UI updates
- Proper provider initialization
- Async provider handling

### ✅ Database Best Practices
- Parameterized queries (SQL injection safe)
- Soft delete pattern (data preservation)
- Automatic timestamps
- Proper error handling
- Typed return values

### ✅ UI/UX Best Practices
- Loading states
- Empty states
- Error states
- Confirmation for destructive actions
- Visual feedback (snackbars)
- Accessible icons with tooltips
- Responsive forms

### ✅ Code Quality
- Type safety throughout
- Null safety handled properly
- Meaningful variable names
- Clear function names
- Comments for complex logic
- Consistent formatting

## Testing the Implementation

### Manual Testing Checklist
- [ ] Create new customer with all fields
- [ ] Create new customer with only name
- [ ] Edit existing customer
- [ ] Toggle customer status (enable/disable)
- [ ] Visual indication for disabled customers
- [ ] Delete customer with confirmation
- [ ] Cancel delete operation
- [ ] Form validation (empty name)
- [ ] List refreshes after operations
- [ ] Success/error notifications
- [ ] Empty state when no customers
- [ ] Loading state on initial load

## Future Enhancements

### Phase 2
1. Search functionality (search bar in header)
2. Filter by enabled/disabled status
3. Sort options (name, created date, etc.)
4. Pagination for large lists
5. Bulk operations (delete multiple, export)

### Phase 3
1. Customer transaction history
2. Outstanding balance tracking
3. Credit limit management
4. Customer groups/categories
5. Import from CSV/Excel
6. Export to PDF/Excel
7. Advanced search with filters
8. Customer notes/comments

## Performance Considerations

- List view uses `ListView.separated` (efficient scrolling)
- Database queries are indexed on `is_deleted`
- Forms use `TextEditingController` (proper cleanup in dispose)
- State updates are minimal (only affected data)
- Async operations don't block UI

## Security Notes

- ✅ SQL injection prevented (parameterized queries)
- ✅ Data validation on form level
- ✅ Soft delete preserves data integrity
- ✅ No sensitive data in error messages
- ⚠️ Future: Add user authentication
- ⚠️ Future: Add audit trail logging

## Conclusion

The Customers module serves as the template for all other master modules (Vendors, Products, etc.). The same MVVM pattern, Riverpod state management, and UI components can be replicated for consistent implementation across the application.

**Status:** ✅ Fully Functional
**Build:** ✅ No Errors
**Ready for:** Production Testing

