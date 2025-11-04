# Product Upload Screen Refactoring

## Status: Partial Refactoring Complete

### What's Been Done ✅

#### 1. Model Layer (`lib/model/product_proposal.dart`)
- Extracted `_ProductProposal` class from screen into proper model file
- Renamed to `ProductProposal` following naming conventions
- Contains all product upload data structure

#### 2. ViewModel Layer (`lib/view_model/product_upload_viewmodel.dart`)
- Created `ProductUploadState` class for state management
- Created `ProductUploadViewModel` with Riverpod StateNotifier
- Extracted business logic methods:
  - `loadManufacturers()` - Load manufacturers from database
  - `resolveManufacturerId()` - Match manufacturer from Excel
  - `downloadTemplate()` - Handle template download
  - `setProcessing()` - Manage processing state
  - `toggleProposalApproval()` - Individual approval
  - `approveAll()` - Bulk approval
  - State management methods (`setFileName`, `setSheets`, etc.)

### What Still Needs To Be Done ⏳

#### 3. View Layer (`lib/view/screens/product_upload_screen.dart`)
The screen is currently **1736 lines** of mixed UI and business logic. It needs to be refactored to:

**Current Issues:**
- Direct database calls in UI methods (`await ref.read(databaseProvider)`)
- Business logic mixed with UI code
- Complex methods like `_prepareProductProposalsFromLoaded()` (400+ lines)
- `_applySelectedProductProposals()` with transaction logic (200+ lines)

**Required Changes:**
1. Remove all database access from screen (move to ViewModel)
2. Replace `setState()` calls with ViewModel method calls
3. Use `ref.watch(productUploadViewModelProvider)` for state
4. Move remaining business logic:
   - File picking and Excel parsing
   - Proposal preparation and validation
   - HSN code lookup and price calculations
   - Product save/update logic

#### Example Refactoring Pattern:

**Before (Current):**
```dart
class _ProductUploadScreenState extends ConsumerState<ProductUploadScreen> {
  String? _fileName;
  List<_ProductProposal> _proposals = [];
  bool _isProcessing = false;

  Future<void> _pickFile() async {
    // ... 100 lines of logic
    final db = await ref.read(databaseProvider);
    // ... database operations
    setState(() {
      _fileName = fileName;
      _proposals = proposals;
    });
  }
}
```

**After (Target):**
```dart
class ProductUploadScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productUploadViewModelProvider);
    final viewModel = ref.read(productUploadViewModelProvider.notifier);

    // UI only - no business logic
    return Column(
      children: [
        if (state.isProcessing) ProgressIndicator(progress: state.progress),
        ElevatedButton(
          onPressed: () => viewModel.pickAndPrepareFile(db),
          child: Text('Upload'),
        ),
      ],
    );
  }
}
```

### Benefits of Full Refactoring

1. **Testability** - ViewModel can be unit tested without UI
2. **Maintainability** - Clear separation of concerns
3. **Reusability** - Business logic can be reused
4. **Readability** - Smaller, focused files (200-300 lines each)
5. **State Management** - Centralized in ViewModel

### Migration Guide

To complete the refactoring:

1. **Move business logic to ViewModel** (one method at a time):
   ```dart
   // In ViewModel
   Future<void> pickAndPrepareFile(Database db) async {
     // File picking logic
     // Excel parsing logic
     // Validation logic
     state = state.copyWith(proposals: proposals);
   }
   ```

2. **Update Screen to use ViewModel**:
   ```dart
   // In Screen
   ElevatedButton(
     onPressed: () async {
       final db = await ref.read(databaseProvider);
       await viewModel.pickAndPrepareFile(db);
     },
   )
   ```

3. **Remove state variables from Screen**:
   - Delete `_fileName`, `_proposals`, `_isProcessing`, etc.
   - Use `state.fileName`, `state.proposals`, `state.isProcessing` instead

4. **Replace setState with ViewModel calls**:
   - Every `setState(() => _isProcessing = true)` becomes
   - `viewModel.setProcessing(true)`

### Estimated Effort

- **Completed**: 20% (Model + ViewModel structure)
- **Remaining**: 80% (Move logic + Rewrite UI)
- **Time**: 4-6 hours for complete refactor

### Files Changed

- ✅ `lib/model/product_proposal.dart` - NEW
- ✅ `lib/view_model/product_upload_viewmodel.dart` - NEW
- ⏳ `lib/view/screens/product_upload_screen.dart` - NEEDS REFACTORING
