# Excel File Tracking Implementation

## Overview
Implemented a system to track Excel files uploaded through Product Upload and HSN Upload screens. Files are saved only when users press the "Apply Selected" button, ensuring we only track files that actually made changes to the database.

## Database Schema

### Table: `excel_uploads`
```sql
CREATE TABLE excel_uploads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

**Columns:**
- `id`: Auto-incrementing primary key
- `file_name`: Stored filename with timestamp (e.g., `products_20240115_143022.xlsx`)
- `file_type`: Type of upload - either `"products"` or `"hsn_codes"`
- `created_at`: ISO 8601 timestamp when file was uploaded
- `updated_at`: ISO 8601 timestamp (same as created_at initially)

## File Storage

**Location:** `C:\motobill\database\excel_files\`

**Naming Convention:**
- Product Upload: `products_YYYYMMDD_HHMMSS.xlsx`
- HSN Upload: `hsn_YYYYMMDD_HHMMSS.xlsx`

**Example filenames:**
- `products_20240115_143022.xlsx`
- `hsn_20240115_150045.xlsx`

## Implementation Details

### Product Upload Screen (`product_upload_screen.dart`)

**State Variables Added:**
```dart
String? _uploadedFilePath; // Store original file path for copying after apply
```

**File Path Storage** (in `_pickFile()` method):
```dart
setState(() {
  _sheets
    ..clear()
    ..addAll(parsed);
  _fileName = result.files.single.name;
  _uploadedFilePath = path; // Store path for copying after apply
});
```

**File Copying Logic** (in `_applySelectedProductProposals()` method):
- Triggered: After successful database transaction, before clearing UI state
- Process:
  1. Generate timestamp in format `YYYYMMDD_HHMMSS`
  2. Create destination filename: `products_timestamp.xlsx`
  3. Copy file from original location to `C:\motobill\database\excel_files\`
  4. Insert record into `excel_uploads` table with `file_type='products'`
  5. Clear `_uploadedFilePath` along with other state

**Error Handling:**
- File copy errors are logged via `debugPrint()` but don't fail the apply operation
- This ensures database changes are not rolled back due to file system issues

### HSN Upload Screen (`testing_screen.dart`)

**State Variables Added:**
```dart
String? _uploadedFilePath; // Store original file path for copying after apply
```

**File Path Storage** (in `_pickAndLoadExcel()` method):
```dart
setState(() {
  _sheets
    ..clear()
    ..addAll(parsed);
  _fileName = result.files.single.name;
  _uploadedFilePath = path; // Store path for copying after apply
});
```

**File Copying Logic** (in `_applySelectedProposals()` method):
- Triggered: After successful database transaction, before refreshing proposals
- Process:
  1. Generate timestamp in format `YYYYMMDD_HHMMSS`
  2. Create destination filename: `hsn_timestamp.xlsx`
  3. Copy file from original location to `C:\motobill\database\excel_files\`
  4. Insert record into `excel_uploads` table with `file_type='hsn_codes'`
  5. File path persists for potential re-apply (HSN screen doesn't clear state after apply)

**Error Handling:**
- Same as Product Upload: errors logged but don't fail the operation

## Key Design Decisions

1. **Save on Apply Only**: Files are copied only when "Apply Selected" button is pressed and the database transaction succeeds. This ensures we only track files that actually made changes.

2. **Timestamp-Based Naming**: Using timestamp ensures:
   - Unique filenames (no overwrite conflicts)
   - Chronological ordering
   - Easy identification of when changes were made

3. **Original File Preservation**: The original file uploaded by the user remains untouched in its original location. We create a copy in our storage directory.

4. **Non-Blocking Errors**: File copy errors don't rollback database changes. This is intentional - the primary operation (database update) should not fail due to file system issues.

5. **Separate file_type Values**: Using `"products"` and `"hsn_codes"` makes it easy to query and filter uploads by type.

## Usage Examples

### Query All Product Uploads
```sql
SELECT * FROM excel_uploads WHERE file_type = 'products' ORDER BY created_at DESC;
```

### Query All HSN Uploads
```sql
SELECT * FROM excel_uploads WHERE file_type = 'hsn_codes' ORDER BY created_at DESC;
```

### Get Recent Uploads (Last 7 Days)
```sql
SELECT * FROM excel_uploads
WHERE created_at >= datetime('now', '-7 days')
ORDER BY created_at DESC;
```

### Count Uploads by Type
```sql
SELECT file_type, COUNT(*) as count
FROM excel_uploads
GROUP BY file_type;
```

## Testing Checklist

- [ ] Upload Excel file in Product Upload screen
- [ ] Verify file is NOT copied before pressing "Apply Selected"
- [ ] Press "Apply Selected" button
- [ ] Verify file is copied to `C:\motobill\database\excel_files\` with correct naming
- [ ] Verify database record exists in `excel_uploads` table
- [ ] Verify timestamp format is correct (YYYYMMDD_HHMMSS)
- [ ] Repeat for HSN Upload screen
- [ ] Test with multiple uploads to ensure unique filenames
- [ ] Verify file copy errors don't prevent database updates

## Future Enhancements

Potential improvements for future consideration:

1. **File Cleanup**: Implement automatic cleanup of old Excel files (e.g., delete files older than 6 months)
2. **File Size Tracking**: Add `file_size` column to track uploaded file sizes
3. **User Attribution**: Add `uploaded_by` column to track which user uploaded the file
4. **Upload Summary**: Add columns to track number of records added/updated
5. **File Restore**: Implement ability to view and re-apply previous uploads
6. **Audit Trail**: Link excel_uploads to specific product/HSN records for complete audit trail
