# GitHub Copilot Instructions for MotoBill Project

## Project Overview
- **Framework**: Flutter
- **Database**: SQLite (direct SQL queries, no migrations)
- **Architecture**: MVVM (Model-View-ViewModel)
- **State Management**: Riverpod (exclusive)
- **Project Location**: `C:\motobill`
- **Database Location**: `C:\motobill\database\motobill.db`
- **Images Storage**: `C:\motobill\database\images`

## Core Principles
1. **Keep it Simple**: Write clear, straightforward code
2. **Stay Modular**: Each file has one responsibility
3. **Easy to Understand**: Anyone should understand the code
4. **No Over-Engineering**: Use the simplest solution that works

## Project Structure (Type-Based Organization)

```
lib/
├── model/
│   ├── apis/                          # API models (request/response)
│   ├── services/                      # External services
│   └── [model_name].dart              # Domain models
├── view/
│   ├── screens/
│   │   └── [feature]_screen.dart      # Screen widgets
│   └── widgets/
│       └── [widget_name].dart         # Reusable widgets
├── view_model/
│   └── [feature]_viewmodel.dart       # Business logic & state
├── repository/
│   └── [entity]_repository.dart       # Database operations
├── core/
│   ├── providers/
│   │   └── database_provider.dart     # Core providers
│   └── constants/
│       └── app_constants.dart         # App constants
└── main.dart
```

## Naming Conventions (Dart Style Guide)

### Files
- Use `lowercase_with_underscores`
- Match the main class name in the file

```
✅ user_repository.dart
✅ invoice_list_screen.dart
✅ user_card.dart
❌ UserRepository.dart
❌ invoiceListScreen.dart
```

### Classes
- Use `UpperCamelCase` (PascalCase)
- Add descriptive suffixes

```dart
✅ UserRepository
✅ InvoiceListScreen
✅ UserViewModel
✅ User (model)
❌ userRepository
❌ User_Repository
```

### Variables & Functions
- Use `lowerCamelCase`
- Be descriptive but concise

```dart
✅ userName
✅ calculateTotal()
✅ fetchUserList()
❌ user_name
❌ UserName
❌ CalculateTotal()
```

### Constants
- Use `lowerCamelCase` (not SCREAMING_SNAKE_CASE)

```dart
✅ const maxRetries = 5;
✅ const apiBaseUrl = 'https://api.example.com';
✅ const databasePath = 'C:\\motobill\\database\\motobill.db';
❌ const MAX_RETRIES = 5;
❌ const API_BASE_URL = 'https://api.example.com';
```

### Private Members
- Prefix with underscore `_`

```dart
class UserRepository {
  final Database _db;         // Private
  String _cache;              // Private

  Future getUsers() {}  // Public
}
```

### Providers (Riverpod)
- Use descriptive names with `Provider` suffix

```dart
✅ final databaseProvider = Provider(...);
✅ final userRepositoryProvider = Provider(...);
✅ final userListProvider = FutureProvider<List>(...);
✅ final userViewModelProvider = StateNotifierProvider(...);
```

## Layer Guidelines
### 1. Models (lib/model/)
**Purpose**: Represent data structure only
**Rules**:
- Plain Dart classes only
- Immutable (`final` fields)
- Include `fromJson` and `toJson`
- No business logic
- No UI code
- One model per file

### 2. API Models (lib/model/apis/)
**Purpose**: Request/Response models for API communication

### 3. Services (lib/model/services/)
**Purpose**: Utility services and external integrations

### 4. Repositories (lib/repository/)
**Purpose**: Handle all database operations for one entity
**Rules**:
- One repository per entity/table
- Only SQL queries here
- Use raw SQL (no ORM)
- Always use parameterized queries (`?`)
- Handle errors appropriately
- Return models or primitives
- No business logic
- No UI code

### 5. ViewModels (lib/view_model/)
**Purpose**: Handle business logic and manage state
**Rules**:
- One ViewModel per screen/feature
- Use `StateNotifier` for complex state
- Call repositories for data
- Handle business logic here
- No direct database access
- No UI code
- Keep methods focused and simple

### 6. Views - Screens (lib/view/screens/)
**Purpose**: Main screen widgets

### 7. Views - Widgets (lib/view/widgets/)
**Purpose**: Reusable widget components
**Rules**:
- Use `ConsumerWidget` or `ConsumerStatefulWidget` for screens
- Only UI code here
- Watch ViewModels with `ref.watch()`
- Call ViewModel methods with `ref.read().notifier`
- No business logic
- No direct database access
- Break down into smaller widgets

## Database Guidelines

### MCP Database Commands Available
Before writing any database code, use these commands to understand the schema:
- `append_insight` - Add a business insight to the memo
- `create_table` - Create a new table in the SQLite database
- `describe_table` - Get the schema information for a specific table
- `list_tables` - List all tables in the SQLite database
- `read_query` - Execute a SELECT query on the SQLite database
- `write_query` - Execute an INSERT, UPDATE, or DELETE query on the SQLite database

### Soft Delete Policy
**CRITICAL:**We never delete records physically from the database. Always use soft delete pattern.
All tables must include:
```
is_deleted INTEGER NOT NULL DEFAULT 0  -- 0: active, 1: deleted
```

### SQL Query Patterns

```dart
// SELECT
final result = await _db.rawQuery('SELECT * FROM users WHERE active = ?', [1]);

// INSERT
final id = await _db.rawInsert(
  'INSERT INTO users (name, email) VALUES (?, ?)',
  [name, email],
);

// UPDATE
await _db.rawUpdate(
  'UPDATE users SET name = ? WHERE id = ?',
  [name, id],
);

// ❌ NEVER do this - Physical delete
await _db.rawDelete('DELETE FROM users WHERE id = ?', [id]);

// ✅ Always do this - Soft delete
await _db.rawUpdate(
  'UPDATE users SET is_deleted = 1 WHERE id = ?',
  [id],
);

// Restore a soft-deleted record
await _db.rawUpdate(
  'UPDATE users SET is_deleted = 0 WHERE id = ?',
  [id],
);

// JOIN
final result = await _db.rawQuery(
  'SELECT u.*, o.total FROM users u LEFT JOIN orders o ON u.id = o.user_id WHERE u.id = ?',
  [userId],
);
```

**Rules**:
- Always use parameterized queries (`?`)
- Never string concatenation for SQL
- Handle errors with try-catch
- No migrations in code
- No schema definitions in code

## Provider Setup

## Code Quality Standards

### Keep Functions Small
### Handle Errors Properly

### Use Meaningful Names
```dart
✅ getUsersByStatus(String status)
✅ calculateTotalWithDiscount(double amount)
✅ isUserActive(User user)

❌ getData()
❌ calc(double x)
❌ check(User u)
```

## Do's ✅

- Write simple, readable code
- Keep files small and focused (under 200 lines)
- Use meaningful names
- One class per file
- Use Riverpod for all state management
- Write direct SQL queries in repositories
- Handle errors gracefully
- Use `const` constructors when possible
- Store only filenames for images in database
- Follow MVVM layers strictly
- Use MCP commands to query database structure before coding
- Comment complex business logic
- Keep functions under 20 lines when possible

## Don'ts ❌

- Don't use other state management (only Riverpod)
- Don't write migrations or schema code
- Don't mix layers (no DB in Views, no UI in ViewModels)
- Don't use ORM or query builders
- Don't store full image paths in database
- Don't create overly complex abstractions
- Don't put multiple classes in one file
- Don't ignore errors
- Don't use global mutable state
- Don't over-engineer solutions

**Remember**: This type-based structure (organizing by model/view/view_model) is your project's chosen approach. Keep code simple, modular, and follow MVVM layers strictly. Use Riverpod exclusively for state management and write direct SQL queries in repositories.