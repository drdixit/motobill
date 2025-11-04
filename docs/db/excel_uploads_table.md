# Excel Uploads Table Reference

## Table Schema

```sql
CREATE TABLE excel_uploads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

## Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `id` | INTEGER | No | Auto-incrementing primary key |
| `file_name` | TEXT | No | Stored filename with timestamp (e.g., `products_20240115_143022.xlsx`) |
| `file_type` | TEXT | No | Type of upload: `"products"` or `"hsn_codes"` |
| `created_at` | TEXT | No | ISO 8601 timestamp when file was uploaded and applied |
| `updated_at` | TEXT | No | ISO 8601 timestamp (currently same as created_at) |

## File Types

- **`products`**: Excel files uploaded via Product Upload screen
- **`hsn_codes`**: Excel files uploaded via HSN Upload screen

## File Storage Location

**Directory:** `C:\motobill\database\excel_files\`

**Naming Convention:**
- Product uploads: `products_YYYYMMDD_HHMMSS.xlsx`
- HSN uploads: `hsn_YYYYMMDD_HHMMSS.xlsx`

## Common Queries

### Get All Uploads
```sql
SELECT * FROM excel_uploads ORDER BY created_at DESC;
```

### Get Product Uploads Only
```sql
SELECT * FROM excel_uploads
WHERE file_type = 'products'
ORDER BY created_at DESC;
```

### Get HSN Code Uploads Only
```sql
SELECT * FROM excel_uploads
WHERE file_type = 'hsn_codes'
ORDER BY created_at DESC;
```

### Get Recent Uploads (Last 30 Days)
```sql
SELECT * FROM excel_uploads
WHERE created_at >= datetime('now', '-30 days')
ORDER BY created_at DESC;
```

### Get Uploads by Date Range
```sql
SELECT * FROM excel_uploads
WHERE created_at BETWEEN '2024-01-01' AND '2024-01-31'
ORDER BY created_at DESC;
```

### Count Total Uploads
```sql
SELECT COUNT(*) as total_uploads FROM excel_uploads;
```

### Count Uploads by Type
```sql
SELECT
  file_type,
  COUNT(*) as count
FROM excel_uploads
GROUP BY file_type;
```

### Get Upload Statistics
```sql
SELECT
  file_type,
  COUNT(*) as total_uploads,
  MIN(created_at) as first_upload,
  MAX(created_at) as latest_upload
FROM excel_uploads
GROUP BY file_type;
```

### Get Latest Upload for Each Type
```sql
SELECT * FROM excel_uploads
WHERE id IN (
  SELECT MAX(id)
  FROM excel_uploads
  GROUP BY file_type
);
```

### Get Today's Uploads
```sql
SELECT * FROM excel_uploads
WHERE DATE(created_at) = DATE('now')
ORDER BY created_at DESC;
```

### Search by Filename Pattern
```sql
SELECT * FROM excel_uploads
WHERE file_name LIKE '%20240115%'
ORDER BY created_at DESC;
```

## Usage Notes

1. **Records are created only when "Apply Selected" is pressed** - Not when the Excel file is first uploaded
2. **Files are copied to storage directory** - Original files remain in their upload location
3. **Timestamps use ISO 8601 format** - Example: `2024-01-15T14:30:22.123456`
4. **No soft delete** - This table tracks uploaded files for audit purposes; records should not be deleted
5. **File copy errors are logged but don't prevent database updates** - Check application logs if file is missing

## Related Documentation

- [Excel File Tracking Implementation](../EXCEL_FILE_TRACKING_IMPLEMENTATION.md) - Full implementation details
- [Product Upload Screen](../../lib/view/screens/product_upload_screen.dart) - Product upload implementation
- [HSN Upload Screen](../../lib/view/screens/testing_screen.dart) - HSN upload implementation
