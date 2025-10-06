# Database Schema

Database: `C:\motobill\database\motobill.db`
Type: SQLite

## Tables

### test
Testing/Todo table

| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY |
| name | TEXT | |
| description | TEXT | |

---

### main_categories
Main categories for the application

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| name | TEXT | NOT NULL | | Category name |
| description | TEXT | | | Category description |
| image | TEXT | | | Image filename only (stored in C:\motobill\database\images) |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | | | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | | | Timestamp when record was last updated (ISO 8601 format) |

**Indexes:**
- `idx_main_categories_name` - On `name`
- `idx_main_categories_is_enabled` - On `is_enabled`
- `idx_main_categories_is_deleted` - On `is_deleted`
- `idx_main_categories_active` - On `(is_deleted, is_enabled)`
- `idx_main_categories_created_at` - On `created_at`
- `idx_main_categories_updated_at` - On `updated_at`

**Common Queries:**
```sql
-- Get all active enabled categories
SELECT * FROM main_categories WHERE is_deleted = 0 AND is_enabled = 1;

-- Get category by ID (active only)
SELECT * FROM main_categories WHERE id = ? AND is_deleted = 0;

-- Insert new category (timestamps will be set automatically in code)
INSERT INTO main_categories (name, description, image, created_at, updated_at)
VALUES (?, ?, ?, datetime('now'), datetime('now'));

-- Update category (remember to update updated_at)
UPDATE main_categories
SET name = ?, description = ?, image = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a category
UPDATE main_categories SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;

-- Restore a soft-deleted category
UPDATE main_categories SET is_deleted = 0, updated_at = datetime('now') WHERE id = ?;

-- Get recently created categories
SELECT * FROM main_categories
WHERE is_deleted = 0
ORDER BY created_at DESC
LIMIT 10;
```

---

### sub_categories
Sub-categories under main categories

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| main_category_id | INTEGER | NOT NULL, FOREIGN KEY | | References main_categories(id) |
| name | TEXT | NOT NULL | | Sub-category name |
| description | TEXT | | | Sub-category description |
| image | TEXT | | | Image filename only (stored in C:\motobill\database\images) |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Foreign Keys:**
- `main_category_id` → `main_categories(id)`

**Indexes:**
- `idx_sub_categories_main_category_id` - On `main_category_id`
- `idx_sub_categories_name` - On `name`
- `idx_sub_categories_is_enabled` - On `is_enabled`
- `idx_sub_categories_is_deleted` - On `is_deleted`
- `idx_sub_categories_active` - On `(is_deleted, is_enabled)`
- `idx_sub_categories_category_active` - On `(main_category_id, is_deleted, is_enabled)`
- `idx_sub_categories_created_at` - On `created_at`
- `idx_sub_categories_updated_at` - On `updated_at`

**Common Queries:**
```sql
-- Get all active enabled sub-categories for a main category
SELECT * FROM sub_categories
WHERE main_category_id = ? AND is_deleted = 0 AND is_enabled = 1;

-- Get sub-category by ID (active only)
SELECT * FROM sub_categories WHERE id = ? AND is_deleted = 0;

-- Insert new sub-category
INSERT INTO sub_categories (main_category_id, name, description, image, created_at, updated_at)
VALUES (?, ?, ?, ?, datetime('now'), datetime('now'));

-- Update sub-category (remember to update updated_at)
UPDATE sub_categories
SET name = ?, description = ?, image = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Get sub-categories with main category details
SELECT sc.*, mc.name as main_category_name
FROM sub_categories sc
JOIN main_categories mc ON sc.main_category_id = mc.id
WHERE sc.is_deleted = 0 AND sc.is_enabled = 1;

-- Soft delete a sub-category
UPDATE sub_categories SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;

-- Get recently created sub-categories
SELECT * FROM sub_categories
WHERE is_deleted = 0
ORDER BY created_at DESC
LIMIT 10;
```

---

### manufacturers
Vehicle manufacturers

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| name | TEXT | NOT NULL | | Manufacturer name |
| description | TEXT | | | Manufacturer description |
| image | TEXT | | | Image filename only (stored in C:\motobill\database\images) |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Indexes:**
- `idx_manufacturers_name` - On `name`
- `idx_manufacturers_is_enabled` - On `is_enabled`
- `idx_manufacturers_is_deleted` - On `is_deleted`
- `idx_manufacturers_active` - On `(is_deleted, is_enabled)`
- `idx_manufacturers_created_at` - On `created_at`
- `idx_manufacturers_updated_at` - On `updated_at`

**Common Queries:**
```sql
-- Get all active enabled manufacturers
SELECT * FROM manufacturers WHERE is_deleted = 0 AND is_enabled = 1;

-- Get manufacturer by ID (active only)
SELECT * FROM manufacturers WHERE id = ? AND is_deleted = 0;

-- Insert new manufacturer
INSERT INTO manufacturers (name, description, image)
VALUES (?, ?, ?);

-- Update manufacturer (remember to update updated_at)
UPDATE manufacturers
SET name = ?, description = ?, image = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a manufacturer
UPDATE manufacturers SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;

-- Restore a soft-deleted manufacturer
UPDATE manufacturers SET is_deleted = 0, updated_at = datetime('now') WHERE id = ?;

-- Get recently created manufacturers
SELECT * FROM manufacturers
WHERE is_deleted = 0
ORDER BY created_at DESC
LIMIT 10;

-- Search manufacturers by name
SELECT * FROM manufacturers
WHERE name LIKE ? AND is_deleted = 0 AND is_enabled = 1;
```

---

### vehicle_types
Types of vehicles (Motorcycle, Scooter, etc.)

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| name | TEXT | NOT NULL | | Vehicle type name |
| description | TEXT | | | Vehicle type description |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Indexes:**
- `idx_vehicle_types_name` - On `name`
- `idx_vehicle_types_is_enabled` - On `is_enabled`
- `idx_vehicle_types_is_deleted` - On `is_deleted`
- `idx_vehicle_types_active` - On `(is_deleted, is_enabled)`

**Common Queries:**
```sql
-- Get all active enabled vehicle types
SELECT * FROM vehicle_types WHERE is_deleted = 0 AND is_enabled = 1;

-- Get vehicle type by ID (active only)
SELECT * FROM vehicle_types WHERE id = ? AND is_deleted = 0;

-- Insert new vehicle type
INSERT INTO vehicle_types (name, description)
VALUES (?, ?);

-- Update vehicle type (remember to update updated_at)
UPDATE vehicle_types
SET name = ?, description = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a vehicle type
UPDATE vehicle_types SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;
```

---

### fuel_types
Types of fuel (Petrol, Diesel, Electric, etc.)

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| name | TEXT | NOT NULL | | Fuel type name |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Indexes:**
- `idx_fuel_types_name` - On `name`
- `idx_fuel_types_is_enabled` - On `is_enabled`
- `idx_fuel_types_is_deleted` - On `is_deleted`
- `idx_fuel_types_active` - On `(is_deleted, is_enabled)`

**Common Queries:**
```sql
-- Get all active enabled fuel types
SELECT * FROM fuel_types WHERE is_deleted = 0 AND is_enabled = 1;

-- Get fuel type by ID (active only)
SELECT * FROM fuel_types WHERE id = ? AND is_deleted = 0;

-- Insert new fuel type
INSERT INTO fuel_types (name)
VALUES (?);

-- Update fuel type (remember to update updated_at)
UPDATE fuel_types
SET name = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a fuel type
UPDATE fuel_types SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;
```

---

### vehicles
Vehicle records with manufacturer, type, and fuel information

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| name | TEXT | NOT NULL | | Vehicle name/model |
| model_year | INTEGER | | | Manufacturing year |
| description | TEXT | | | Vehicle description |
| image | TEXT | | | Image filename only (stored in C:\motobill\database\images) |
| manufacturer_id | INTEGER | NOT NULL, FOREIGN KEY | | References manufacturers(id) |
| vehicle_type_id | INTEGER | NOT NULL, FOREIGN KEY | | References vehicle_types(id) |
| fuel_type_id | INTEGER | NOT NULL, FOREIGN KEY | | References fuel_types(id) |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Foreign Keys:**
- `manufacturer_id` → `manufacturers(id)`
- `vehicle_type_id` → `vehicle_types(id)`
- `fuel_type_id` → `fuel_types(id)`

**Indexes:**
- `idx_vehicles_name` - On `name`
- `idx_vehicles_manufacturer_id` - On `manufacturer_id`
- `idx_vehicles_vehicle_type_id` - On `vehicle_type_id`
- `idx_vehicles_fuel_type_id` - On `fuel_type_id`
- `idx_vehicles_is_enabled` - On `is_enabled`
- `idx_vehicles_is_deleted` - On `is_deleted`
- `idx_vehicles_active` - On `(is_deleted, is_enabled)`
- `idx_vehicles_model_year` - On `model_year`

**Common Queries:**
```sql
-- Get all active enabled vehicles
SELECT * FROM vehicles WHERE is_deleted = 0 AND is_enabled = 1;

-- Get vehicle by ID (active only)
SELECT * FROM vehicles WHERE id = ? AND is_deleted = 0;

-- Get vehicles with full details (JOIN)
SELECT v.*,
       m.name as manufacturer_name,
       vt.name as vehicle_type_name,
       ft.name as fuel_type_name
FROM vehicles v
JOIN manufacturers m ON v.manufacturer_id = m.id
JOIN vehicle_types vt ON v.vehicle_type_id = vt.id
JOIN fuel_types ft ON v.fuel_type_id = ft.id
WHERE v.is_deleted = 0 AND v.is_enabled = 1;

-- Get vehicles by manufacturer
SELECT * FROM vehicles
WHERE manufacturer_id = ? AND is_deleted = 0 AND is_enabled = 1;

-- Get vehicles by type
SELECT * FROM vehicles
WHERE vehicle_type_id = ? AND is_deleted = 0 AND is_enabled = 1;

-- Get vehicles by fuel type
SELECT * FROM vehicles
WHERE fuel_type_id = ? AND is_deleted = 0 AND is_enabled = 1;

-- Get vehicles by year range
SELECT * FROM vehicles
WHERE model_year BETWEEN ? AND ? AND is_deleted = 0 AND is_enabled = 1;

-- Insert new vehicle
INSERT INTO vehicles (name, model_year, description, image, manufacturer_id, vehicle_type_id, fuel_type_id)
VALUES (?, ?, ?, ?, ?, ?, ?);

-- Update vehicle (remember to update updated_at)
UPDATE vehicles
SET name = ?, model_year = ?, description = ?, image = ?,
    manufacturer_id = ?, vehicle_type_id = ?, fuel_type_id = ?,
    updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a vehicle
UPDATE vehicles SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;

-- Search vehicles by name
SELECT * FROM vehicles
WHERE name LIKE ? AND is_deleted = 0 AND is_enabled = 1;
```

---

### uqcs
Unit of Quantity Code (UQC) for products

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| code | TEXT | NOT NULL | | UQC code (e.g., NOS, PCS, KGS) |
| description | TEXT | | | UQC description |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Indexes:**
- `idx_uqcs_code` - On `code`
- `idx_uqcs_is_enabled` - On `is_enabled`
- `idx_uqcs_is_deleted` - On `is_deleted`
- `idx_uqcs_active` - On `(is_deleted, is_enabled)`

**Common Queries:**
```sql
-- Get all active enabled UQCs
SELECT * FROM uqcs WHERE is_deleted = 0 AND is_enabled = 1;

-- Get UQC by ID (active only)
SELECT * FROM uqcs WHERE id = ? AND is_deleted = 0;

-- Get UQC by code
SELECT * FROM uqcs WHERE code = ? AND is_deleted = 0 AND is_enabled = 1;

-- Insert new UQC
INSERT INTO uqcs (code, description)
VALUES (?, ?);

-- Update UQC (remember to update updated_at)
UPDATE uqcs
SET code = ?, description = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a UQC
UPDATE uqcs SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;
```

---

### hsn_codes
HSN (Harmonized System of Nomenclature) codes for products

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| code | TEXT | NOT NULL | | HSN code (e.g., 8708) |
| description | TEXT | | | HSN code description |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Indexes:**
- `idx_hsn_codes_code` - On `code`
- `idx_hsn_codes_is_enabled` - On `is_enabled`
- `idx_hsn_codes_is_deleted` - On `is_deleted`
- `idx_hsn_codes_active` - On `(is_deleted, is_enabled)`

**Common Queries:**
```sql
-- Get all active enabled HSN codes
SELECT * FROM hsn_codes WHERE is_deleted = 0 AND is_enabled = 1;

-- Get HSN code by ID (active only)
SELECT * FROM hsn_codes WHERE id = ? AND is_deleted = 0;

-- Get HSN code by code
SELECT * FROM hsn_codes WHERE code = ? AND is_deleted = 0 AND is_enabled = 1;

-- Insert new HSN code
INSERT INTO hsn_codes (code, description)
VALUES (?, ?);

-- Update HSN code (remember to update updated_at)
UPDATE hsn_codes
SET code = ?, description = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete an HSN code
UPDATE hsn_codes SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;

-- Search HSN codes by code
SELECT * FROM hsn_codes
WHERE code LIKE ? AND is_deleted = 0 AND is_enabled = 1;
```

---

### gst_rates
GST (Goods and Services Tax) rates for HSN codes

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| hsn_code_id | INTEGER | NOT NULL, FOREIGN KEY | | References hsn_codes(id) |
| cgst | REAL | NOT NULL | | Central GST rate (%) |
| sgst | REAL | NOT NULL | | State GST rate (%) |
| igst | REAL | NOT NULL | | Integrated GST rate (%) |
| utgst | REAL | NOT NULL | 0 | Union Territory GST rate (%) |
| effective_from | TEXT | NOT NULL | | Date from which rate is effective (ISO 8601 format) |
| effective_to | TEXT | | | Date till which rate is effective (ISO 8601 format) |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Foreign Keys:**
- `hsn_code_id` → `hsn_codes(id)`

**Indexes:**
- `idx_gst_rates_hsn_code_id` - On `hsn_code_id`
- `idx_gst_rates_effective_from` - On `effective_from`
- `idx_gst_rates_is_enabled` - On `is_enabled`
- `idx_gst_rates_is_deleted` - On `is_deleted`
- `idx_gst_rates_active` - On `(is_deleted, is_enabled)`

**Common Queries:**
```sql
-- Get all active enabled GST rates
SELECT * FROM gst_rates WHERE is_deleted = 0 AND is_enabled = 1;

-- Get GST rate by ID (active only)
SELECT * FROM gst_rates WHERE id = ? AND is_deleted = 0;

-- Get current GST rate for an HSN code
SELECT gr.*, h.code as hsn_code
FROM gst_rates gr
JOIN hsn_codes h ON gr.hsn_code_id = h.id
WHERE gr.hsn_code_id = ?
  AND gr.effective_from <= date('now')
  AND (gr.effective_to IS NULL OR gr.effective_to >= date('now'))
  AND gr.is_deleted = 0
  AND gr.is_enabled = 1
ORDER BY gr.effective_from DESC
LIMIT 1;

-- Get all GST rates with HSN code details
SELECT gr.*, h.code as hsn_code, h.description as hsn_description
FROM gst_rates gr
JOIN hsn_codes h ON gr.hsn_code_id = h.id
WHERE gr.is_deleted = 0 AND gr.is_enabled = 1;

-- Insert new GST rate
INSERT INTO gst_rates (hsn_code_id, cgst, sgst, igst, utgst, effective_from, effective_to)
VALUES (?, ?, ?, ?, ?, ?, ?);

-- Update GST rate (remember to update updated_at)
UPDATE gst_rates
SET cgst = ?, sgst = ?, igst = ?, utgst = ?,
    effective_from = ?, effective_to = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a GST rate
UPDATE gst_rates SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;
```

---

### products
Product/Spare parts inventory

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| name | TEXT | NOT NULL | | Product name |
| part_number | TEXT | | | Part/SKU number |
| hsn_code_id | INTEGER | NOT NULL, FOREIGN KEY | | References hsn_codes(id) |
| uqc_id | INTEGER | NOT NULL, FOREIGN KEY | | References uqcs(id) |
| cost_price | REAL | NOT NULL | | Purchase/Cost price |
| selling_price | REAL | NOT NULL | | Selling price |
| sub_category_id | INTEGER | NOT NULL, FOREIGN KEY | | References sub_categories(id) |
| manufacturer_id | INTEGER | NOT NULL, FOREIGN KEY | | References manufacturers(id) |
| is_taxable | INTEGER | NOT NULL | 0 | 0 = non-taxable, 1 = taxable (GST applicable) |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Foreign Keys:**
- `hsn_code_id` → `hsn_codes(id)`
- `uqc_id` → `uqcs(id)`
- `sub_category_id` → `sub_categories(id)`
- `manufacturer_id` → `manufacturers(id)`

**Indexes:**
- `idx_products_name` - On `name`
- `idx_products_part_number` - On `part_number`
- `idx_products_hsn_code_id` - On `hsn_code_id`
- `idx_products_uqc_id` - On `uqc_id`
- `idx_products_sub_category_id` - On `sub_category_id`
- `idx_products_manufacturer_id` - On `manufacturer_id`
- `idx_products_is_enabled` - On `is_enabled`
- `idx_products_is_deleted` - On `is_deleted`
- `idx_products_active` - On `(is_deleted, is_enabled)`

**Common Queries:**
```sql
-- Get all active enabled products
SELECT * FROM products WHERE is_deleted = 0 AND is_enabled = 1;

-- Get product by ID (active only)
SELECT * FROM products WHERE id = ? AND is_deleted = 0;

-- Get products with full details (JOIN)
SELECT p.*,
       h.code as hsn_code,
       u.code as uqc_code,
       sc.name as sub_category_name,
       mc.name as main_category_name,
       m.name as manufacturer_name
FROM products p
JOIN hsn_codes h ON p.hsn_code_id = h.id
JOIN uqcs u ON p.uqc_id = u.id
JOIN sub_categories sc ON p.sub_category_id = sc.id
JOIN main_categories mc ON sc.main_category_id = mc.id
JOIN manufacturers m ON p.manufacturer_id = m.id
WHERE p.is_deleted = 0 AND p.is_enabled = 1;

-- Get products by manufacturer
SELECT * FROM products
WHERE manufacturer_id = ? AND is_deleted = 0 AND is_enabled = 1;

-- Get products by sub-category
SELECT * FROM products
WHERE sub_category_id = ? AND is_deleted = 0 AND is_enabled = 1;

-- Get products by HSN code
SELECT * FROM products
WHERE hsn_code_id = ? AND is_deleted = 0 AND is_enabled = 1;

-- Search products by name or part number
SELECT * FROM products
WHERE (name LIKE ? OR part_number LIKE ?)
  AND is_deleted = 0 AND is_enabled = 1;

-- Get products with profit margin
SELECT *,
       (selling_price - cost_price) as profit,
       ROUND(((selling_price - cost_price) / cost_price * 100), 2) as profit_margin_percent
FROM products
WHERE is_deleted = 0 AND is_enabled = 1;

-- Get taxable products only
SELECT * FROM products
WHERE is_taxable = 1 AND is_deleted = 0 AND is_enabled = 1;

-- Get non-taxable products only
SELECT * FROM products
WHERE is_taxable = 0 AND is_deleted = 0 AND is_enabled = 1;

-- Insert new product
INSERT INTO products (name, part_number, hsn_code_id, uqc_id, cost_price, selling_price, sub_category_id, manufacturer_id, is_taxable)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);

-- Update product (remember to update updated_at)
UPDATE products
SET name = ?, part_number = ?, hsn_code_id = ?, uqc_id = ?,
    cost_price = ?, selling_price = ?, sub_category_id = ?,
    manufacturer_id = ?, is_taxable = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Update product prices
UPDATE products
SET cost_price = ?, selling_price = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a product
UPDATE products SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;
```

---

### product_images
Multiple images for products

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| product_id | INTEGER | NOT NULL, FOREIGN KEY | | References products(id) |
| image_path | TEXT | NOT NULL | | Image filename (stored in C:\motobill\database\images) |
| is_primary | INTEGER | NOT NULL | 0 | 0 = secondary image, 1 = primary/main image |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |

**Foreign Keys:**
- `product_id` → `products(id)`

**Indexes:**
- `idx_product_images_product_id` - On `product_id`
- `idx_product_images_is_primary` - On `is_primary`
- `idx_product_images_is_deleted` - On `is_deleted`
- `idx_product_images_product_primary` - On `(product_id, is_primary, is_deleted)`

**Common Queries:**
```sql
-- Get all images for a product (active only)
SELECT * FROM product_images
WHERE product_id = ? AND is_deleted = 0
ORDER BY is_primary DESC, id ASC;

-- Get primary image for a product
SELECT * FROM product_images
WHERE product_id = ? AND is_primary = 1 AND is_deleted = 0
LIMIT 1;

-- Get all products with their primary images
SELECT p.*, pi.image_path as primary_image
FROM products p
LEFT JOIN product_images pi ON p.id = pi.product_id AND pi.is_primary = 1 AND pi.is_deleted = 0
WHERE p.is_deleted = 0 AND p.is_enabled = 1;

-- Get product with all images
SELECT p.*,
       GROUP_CONCAT(pi.image_path) as images,
       (SELECT image_path FROM product_images WHERE product_id = p.id AND is_primary = 1 AND is_deleted = 0 LIMIT 1) as primary_image
FROM products p
LEFT JOIN product_images pi ON p.id = pi.product_id AND pi.is_deleted = 0
WHERE p.id = ? AND p.is_deleted = 0
GROUP BY p.id;

-- Insert new product image
INSERT INTO product_images (product_id, image_path, is_primary)
VALUES (?, ?, ?);

-- Set an image as primary (and unset others)
UPDATE product_images SET is_primary = 0 WHERE product_id = ? AND is_deleted = 0;
UPDATE product_images SET is_primary = 1 WHERE id = ? AND is_deleted = 0;

-- Soft delete a product image
UPDATE product_images SET is_deleted = 1 WHERE id = ?;

-- Count images for a product
SELECT COUNT(*) as image_count
FROM product_images
WHERE product_id = ? AND is_deleted = 0;
```

---

### customers
Customer information for billing and invoicing

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| name | TEXT | NOT NULL | | Customer name |
| legal_name | TEXT | | | Legal business name (for companies) |
| phone | TEXT | | | Contact phone number |
| email | TEXT | | | Contact email address |
| gst_number | TEXT | | | GST registration number (for GST registered customers) |
| address_line1 | TEXT | | | Address line 1 |
| address_line2 | TEXT | | | Address line 2 |
| city | TEXT | | | City |
| state | TEXT | | | State |
| pincode | TEXT | | | Postal/PIN code |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Indexes:**
- `idx_customers_name` - On `name`
- `idx_customers_phone` - On `phone`
- `idx_customers_email` - On `email`
- `idx_customers_gst_number` - On `gst_number`
- `idx_customers_is_enabled` - On `is_enabled`
- `idx_customers_is_deleted` - On `is_deleted`
- `idx_customers_active` - On `(is_deleted, is_enabled)`

**Common Queries:**
```sql
-- Get all active enabled customers
SELECT * FROM customers WHERE is_deleted = 0 AND is_enabled = 1;

-- Get customer by ID (active only)
SELECT * FROM customers WHERE id = ? AND is_deleted = 0;

-- Search customers by name
SELECT * FROM customers
WHERE name LIKE ? AND is_deleted = 0 AND is_enabled = 1;

-- Search customers by phone
SELECT * FROM customers
WHERE phone LIKE ? AND is_deleted = 0 AND is_enabled = 1;

-- Search customers by email
SELECT * FROM customers
WHERE email LIKE ? AND is_deleted = 0 AND is_enabled = 1;

-- Get customer by GST number
SELECT * FROM customers
WHERE gst_number = ? AND is_deleted = 0 AND is_enabled = 1;

-- Get customers by city or state
SELECT * FROM customers
WHERE (city = ? OR state = ?) AND is_deleted = 0 AND is_enabled = 1;

-- Get GST registered customers only
SELECT * FROM customers
WHERE gst_number IS NOT NULL AND gst_number != ''
  AND is_deleted = 0 AND is_enabled = 1;

-- Get customers with complete address
SELECT * FROM customers
WHERE address_line1 IS NOT NULL
  AND city IS NOT NULL
  AND state IS NOT NULL
  AND pincode IS NOT NULL
  AND is_deleted = 0 AND is_enabled = 1;

-- Insert new customer
INSERT INTO customers (name, legal_name, phone, email, gst_number, address_line1, address_line2, city, state, pincode)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- Update customer (remember to update updated_at)
UPDATE customers
SET name = ?, legal_name = ?, phone = ?, email = ?, gst_number = ?,
    address_line1 = ?, address_line2 = ?, city = ?, state = ?, pincode = ?,
    updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Update customer contact info only
UPDATE customers
SET phone = ?, email = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a customer
UPDATE customers SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;

-- Get recently added customers
SELECT * FROM customers
WHERE is_deleted = 0
ORDER BY created_at DESC
LIMIT 10;

-- Search customers by multiple criteria
SELECT * FROM customers
WHERE (name LIKE ? OR phone LIKE ? OR email LIKE ?)
  AND is_deleted = 0 AND is_enabled = 1;
```

---

### vendors
Vendor/Supplier information for purchasing and procurement

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| name | TEXT | NOT NULL | | Vendor name |
| legal_name | TEXT | | | Legal business name |
| phone | TEXT | | | Contact phone number |
| email | TEXT | | | Contact email address |
| gst_number | TEXT | | | GST registration number |
| address_line1 | TEXT | | | Address line 1 |
| address_line2 | TEXT | | | Address line 2 |
| city | TEXT | | | City |
| state | TEXT | | | State |
| pincode | TEXT | | | Postal/PIN code |
| is_enabled | INTEGER | NOT NULL | 1 | 1 = enabled, 0 = disabled |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Indexes:**
- `idx_vendors_name` - On `name`
- `idx_vendors_phone` - On `phone`
- `idx_vendors_email` - On `email`
- `idx_vendors_gst_number` - On `gst_number`
- `idx_vendors_is_enabled` - On `is_enabled`
- `idx_vendors_is_deleted` - On `is_deleted`
- `idx_vendors_active` - On `(is_deleted, is_enabled)`

**Common Queries:**
```sql
-- Get all active enabled vendors
SELECT * FROM vendors WHERE is_deleted = 0 AND is_enabled = 1;

-- Get vendor by ID (active only)
SELECT * FROM vendors WHERE id = ? AND is_deleted = 0;

-- Search vendors by name
SELECT * FROM vendors
WHERE name LIKE ? AND is_deleted = 0 AND is_enabled = 1;

-- Search vendors by phone
SELECT * FROM vendors
WHERE phone LIKE ? AND is_deleted = 0 AND is_enabled = 1;

-- Search vendors by email
SELECT * FROM vendors
WHERE email LIKE ? AND is_deleted = 0 AND is_enabled = 1;

-- Get vendor by GST number
SELECT * FROM vendors
WHERE gst_number = ? AND is_deleted = 0 AND is_enabled = 1;

-- Get vendors by city or state
SELECT * FROM vendors
WHERE (city = ? OR state = ?) AND is_deleted = 0 AND is_enabled = 1;

-- Get GST registered vendors only
SELECT * FROM vendors
WHERE gst_number IS NOT NULL AND gst_number != ''
  AND is_deleted = 0 AND is_enabled = 1;

-- Insert new vendor
INSERT INTO vendors (name, legal_name, phone, email, gst_number, address_line1, address_line2, city, state, pincode)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- Update vendor (remember to update updated_at)
UPDATE vendors
SET name = ?, legal_name = ?, phone = ?, email = ?, gst_number = ?,
    address_line1 = ?, address_line2 = ?, city = ?, state = ?, pincode = ?,
    updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Update vendor contact info only
UPDATE vendors
SET phone = ?, email = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a vendor
UPDATE vendors SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;

-- Get recently added vendors
SELECT * FROM vendors
WHERE is_deleted = 0
ORDER BY created_at DESC
LIMIT 10;

-- Search vendors by multiple criteria
SELECT * FROM vendors
WHERE (name LIKE ? OR phone LIKE ? OR email LIKE ?)
  AND is_deleted = 0 AND is_enabled = 1;
```

---

### bills
Sales bills/invoices

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| bill_number | TEXT | NOT NULL, UNIQUE | | Unique bill/invoice number |
| customer_id | INTEGER | NOT NULL, FOREIGN KEY | | References customers(id) |
| subtotal | REAL | NOT NULL | | Subtotal before tax |
| tax_amount | REAL | NOT NULL | | Total tax amount (sum of all taxes) |
| total_amount | REAL | NOT NULL | | Final total amount (subtotal + tax_amount) |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Foreign Keys:**
- `customer_id` → `customers(id)`

**Indexes:**
- `idx_bills_bill_number` - On `bill_number`
- `idx_bills_customer_id` - On `customer_id`
- `idx_bills_is_deleted` - On `is_deleted`
- `idx_bills_created_at` - On `created_at`

**Common Queries:**
```sql
-- Get all active bills
SELECT * FROM bills WHERE is_deleted = 0;

-- Get bill by ID (active only)
SELECT * FROM bills WHERE id = ? AND is_deleted = 0;

-- Get bill by bill number
SELECT * FROM bills WHERE bill_number = ? AND is_deleted = 0;

-- Get bills for a customer
SELECT * FROM bills
WHERE customer_id = ? AND is_deleted = 0
ORDER BY created_at DESC;

-- Get bills with customer details
SELECT b.*, c.name as customer_name, c.phone, c.gst_number
FROM bills b
JOIN customers c ON b.customer_id = c.id
WHERE b.is_deleted = 0
ORDER BY b.created_at DESC;

-- Get recent bills
SELECT * FROM bills
WHERE is_deleted = 0
ORDER BY created_at DESC
LIMIT 10;

-- Get bills by date range
SELECT * FROM bills
WHERE date(created_at) BETWEEN ? AND ?
  AND is_deleted = 0;

-- Get total sales amount
SELECT SUM(total_amount) as total_sales
FROM bills
WHERE is_deleted = 0;

-- Get sales by date
SELECT date(created_at) as sale_date,
       COUNT(*) as bill_count,
       SUM(total_amount) as total_sales
FROM bills
WHERE is_deleted = 0
GROUP BY date(created_at)
ORDER BY sale_date DESC;

-- Insert new bill
INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount)
VALUES (?, ?, ?, ?, ?);

-- Update bill (remember to update updated_at)
UPDATE bills
SET subtotal = ?, tax_amount = ?, total_amount = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a bill
UPDATE bills SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;
```

---

### bill_items
Line items for bills/invoices

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| bill_id | INTEGER | NOT NULL, FOREIGN KEY | | References bills(id) |
| product_id | INTEGER | NOT NULL, FOREIGN KEY | | References products(id) |
| product_name | TEXT | NOT NULL | | Product name (snapshot) |
| part_number | TEXT | | | Part/SKU number (snapshot) |
| hsn_code | TEXT | | | HSN code (snapshot) |
| uqc_code | TEXT | | | UQC code (snapshot) |
| cost_price | REAL | NOT NULL | | Cost price per unit |
| selling_price | REAL | NOT NULL | | Selling price per unit |
| quantity | REAL | NOT NULL | | Quantity sold |
| subtotal | REAL | NOT NULL | | Line item subtotal (selling_price × quantity) |
| cgst_rate | REAL | NOT NULL | 0 | Central GST rate (%) |
| sgst_rate | REAL | NOT NULL | 0 | State GST rate (%) |
| igst_rate | REAL | NOT NULL | 0 | Integrated GST rate (%) |
| utgst_rate | REAL | NOT NULL | 0 | Union Territory GST rate (%) |
| cgst_amount | REAL | NOT NULL | 0 | Calculated CGST amount |
| sgst_amount | REAL | NOT NULL | 0 | Calculated SGST amount |
| igst_amount | REAL | NOT NULL | 0 | Calculated IGST amount |
| utgst_amount | REAL | NOT NULL | 0 | Calculated UTGST amount |
| tax_amount | REAL | NOT NULL | | Total tax amount (sum of all taxes) |
| total_amount | REAL | NOT NULL | | Line item total (subtotal + tax_amount) |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Foreign Keys:**
- `bill_id` → `bills(id)`
- `product_id` → `products(id)`

**Indexes:**
- `idx_bill_items_bill_id` - On `bill_id`
- `idx_bill_items_product_id` - On `product_id`
- `idx_bill_items_is_deleted` - On `is_deleted`

**Common Queries:**
```sql
-- Get all items for a bill
SELECT * FROM bill_items
WHERE bill_id = ? AND is_deleted = 0;

-- Get bill with all items
SELECT b.*,
       bi.product_name, bi.quantity, bi.selling_price, bi.total_amount
FROM bills b
JOIN bill_items bi ON b.id = bi.bill_id
WHERE b.id = ? AND b.is_deleted = 0 AND bi.is_deleted = 0;

-- Get complete bill details with customer and items
SELECT b.bill_number, b.created_at,
       c.name as customer_name, c.phone, c.gst_number,
       bi.product_name, bi.part_number, bi.hsn_code, bi.quantity,
       bi.selling_price, bi.subtotal, bi.tax_amount, bi.total_amount
FROM bills b
JOIN customers c ON b.customer_id = c.id
JOIN bill_items bi ON b.id = bi.bill_id
WHERE b.id = ? AND b.is_deleted = 0 AND bi.is_deleted = 0;

-- Get top selling products
SELECT product_id, product_name,
       SUM(quantity) as total_quantity,
       SUM(total_amount) as total_revenue
FROM bill_items
WHERE is_deleted = 0
GROUP BY product_id, product_name
ORDER BY total_quantity DESC
LIMIT 10;

-- Get product-wise sales report
SELECT product_name, part_number,
       COUNT(*) as times_sold,
       SUM(quantity) as total_quantity,
       SUM(subtotal) as total_subtotal,
       SUM(tax_amount) as total_tax,
       SUM(total_amount) as total_revenue,
       SUM((selling_price - cost_price) * quantity) as total_profit
FROM bill_items
WHERE is_deleted = 0
GROUP BY product_id
ORDER BY total_revenue DESC;

-- Get GST summary for a bill
SELECT bill_id,
       SUM(cgst_amount) as total_cgst,
       SUM(sgst_amount) as total_sgst,
       SUM(igst_amount) as total_igst,
       SUM(utgst_amount) as total_utgst,
       SUM(tax_amount) as total_tax
FROM bill_items
WHERE bill_id = ? AND is_deleted = 0
GROUP BY bill_id;

-- Insert new bill item
INSERT INTO bill_items (bill_id, product_id, product_name, part_number, hsn_code, uqc_code,
                        cost_price, selling_price, quantity, subtotal,
                        cgst_rate, sgst_rate, igst_rate, utgst_rate,
                        cgst_amount, sgst_amount, igst_amount, utgst_amount,
                        tax_amount, total_amount)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- Update bill item (remember to update updated_at)
UPDATE bill_items
SET quantity = ?, subtotal = ?, tax_amount = ?, total_amount = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a bill item
UPDATE bill_items SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;

-- Calculate profit for a bill
SELECT SUM((selling_price - cost_price) * quantity) as total_profit
FROM bill_items
WHERE bill_id = ? AND is_deleted = 0;
```

---

### purchases
Purchase orders from vendors

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| purchase_number | TEXT | NOT NULL, UNIQUE | | Unique purchase order number |
| purchase_reference_number | TEXT | | | Vendor's invoice/reference number |
| purchase_reference_date | TEXT | | | Date on vendor's invoice (ISO 8601 format) |
| vendor_id | INTEGER | NOT NULL, FOREIGN KEY | | References vendors(id) |
| subtotal | REAL | NOT NULL | | Subtotal before tax |
| tax_amount | REAL | NOT NULL | | Total tax amount (sum of all taxes) |
| total_amount | REAL | NOT NULL | | Final total amount (subtotal + tax_amount) |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Foreign Keys:**
- `vendor_id` → `vendors(id)`

**Indexes:**
- `idx_purchases_purchase_number` - On `purchase_number`
- `idx_purchases_vendor_id` - On `vendor_id`
- `idx_purchases_is_deleted` - On `is_deleted`
- `idx_purchases_created_at` - On `created_at`
- `idx_purchases_reference_date` - On `purchase_reference_date`

**Common Queries:**
```sql
-- Get all active purchases
SELECT * FROM purchases WHERE is_deleted = 0;

-- Get purchase by ID (active only)
SELECT * FROM purchases WHERE id = ? AND is_deleted = 0;

-- Get purchase by purchase number
SELECT * FROM purchases WHERE purchase_number = ? AND is_deleted = 0;

-- Get purchases for a vendor
SELECT * FROM purchases
WHERE vendor_id = ? AND is_deleted = 0
ORDER BY created_at DESC;

-- Get purchases with vendor details
SELECT p.*, v.name as vendor_name, v.phone, v.gst_number
FROM purchases p
JOIN vendors v ON p.vendor_id = v.id
WHERE p.is_deleted = 0
ORDER BY p.created_at DESC;

-- Get recent purchases
SELECT * FROM purchases
WHERE is_deleted = 0
ORDER BY created_at DESC
LIMIT 10;

-- Get purchases by reference date range
SELECT * FROM purchases
WHERE date(purchase_reference_date) BETWEEN ? AND ?
  AND is_deleted = 0;

-- Get total purchase amount
SELECT SUM(total_amount) as total_purchases
FROM purchases
WHERE is_deleted = 0;

-- Get purchases by date
SELECT date(created_at) as purchase_date,
       COUNT(*) as purchase_count,
       SUM(total_amount) as total_amount
FROM purchases
WHERE is_deleted = 0
GROUP BY date(created_at)
ORDER BY purchase_date DESC;

-- Insert new purchase
INSERT INTO purchases (purchase_number, purchase_reference_number, purchase_reference_date, vendor_id, subtotal, tax_amount, total_amount)
VALUES (?, ?, ?, ?, ?, ?, ?);

-- Update purchase (remember to update updated_at)
UPDATE purchases
SET purchase_reference_number = ?, purchase_reference_date = ?,
    subtotal = ?, tax_amount = ?, total_amount = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a purchase
UPDATE purchases SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;
```

---

### purchase_items
Line items for purchase orders

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| purchase_id | INTEGER | NOT NULL, FOREIGN KEY | | References purchases(id) |
| product_id | INTEGER | NOT NULL, FOREIGN KEY | | References products(id) |
| product_name | TEXT | NOT NULL | | Product name (snapshot) |
| part_number | TEXT | | | Part/SKU number (snapshot) |
| hsn_code | TEXT | | | HSN code (snapshot) |
| uqc_code | TEXT | | | UQC code (snapshot) |
| cost_price | REAL | NOT NULL | | Cost price per unit |
| quantity | REAL | NOT NULL | | Quantity purchased |
| subtotal | REAL | NOT NULL | | Line item subtotal (cost_price × quantity) |
| cgst_rate | REAL | NOT NULL | 0 | Central GST rate (%) |
| sgst_rate | REAL | NOT NULL | 0 | State GST rate (%) |
| igst_rate | REAL | NOT NULL | 0 | Integrated GST rate (%) |
| utgst_rate | REAL | NOT NULL | 0 | Union Territory GST rate (%) |
| cgst_amount | REAL | NOT NULL | 0 | Calculated CGST amount |
| sgst_amount | REAL | NOT NULL | 0 | Calculated SGST amount |
| igst_amount | REAL | NOT NULL | 0 | Calculated IGST amount |
| utgst_amount | REAL | NOT NULL | 0 | Calculated UTGST amount |
| tax_amount | REAL | NOT NULL | | Total tax amount (sum of all taxes) |
| total_amount | REAL | NOT NULL | | Line item total (subtotal + tax_amount) |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Foreign Keys:**
- `purchase_id` → `purchases(id)`
- `product_id` → `products(id)`

**Indexes:**
- `idx_purchase_items_purchase_id` - On `purchase_id`
- `idx_purchase_items_product_id` - On `product_id`
- `idx_purchase_items_is_deleted` - On `is_deleted`

**Common Queries:**
```sql
-- Get all items for a purchase
SELECT * FROM purchase_items
WHERE purchase_id = ? AND is_deleted = 0;

-- Get purchase with all items
SELECT p.*,
       pi.product_name, pi.quantity, pi.cost_price, pi.total_amount
FROM purchases p
JOIN purchase_items pi ON p.id = pi.purchase_id
WHERE p.id = ? AND p.is_deleted = 0 AND pi.is_deleted = 0;

-- Get complete purchase details with vendor and items
SELECT p.purchase_number, p.purchase_reference_number, p.created_at,
       v.name as vendor_name, v.phone, v.gst_number,
       pi.product_name, pi.part_number, pi.hsn_code, pi.quantity,
       pi.cost_price, pi.subtotal, pi.tax_amount, pi.total_amount
FROM purchases p
JOIN vendors v ON p.vendor_id = v.id
JOIN purchase_items pi ON p.id = pi.purchase_id
WHERE p.id = ? AND p.is_deleted = 0 AND pi.is_deleted = 0;

-- Get most purchased products
SELECT product_id, product_name,
       SUM(quantity) as total_quantity,
       SUM(total_amount) as total_spent
FROM purchase_items
WHERE is_deleted = 0
GROUP BY product_id, product_name
ORDER BY total_quantity DESC
LIMIT 10;

-- Get product-wise purchase report
SELECT product_name, part_number,
       COUNT(*) as times_purchased,
       SUM(quantity) as total_quantity,
       AVG(cost_price) as avg_cost_price,
       SUM(subtotal) as total_subtotal,
       SUM(tax_amount) as total_tax,
       SUM(total_amount) as total_spent
FROM purchase_items
WHERE is_deleted = 0
GROUP BY product_id
ORDER BY total_spent DESC;

-- Get GST summary for a purchase
SELECT purchase_id,
       SUM(cgst_amount) as total_cgst,
       SUM(sgst_amount) as total_sgst,
       SUM(igst_amount) as total_igst,
       SUM(utgst_amount) as total_utgst,
       SUM(tax_amount) as total_tax
FROM purchase_items
WHERE purchase_id = ? AND is_deleted = 0
GROUP BY purchase_id;

-- Insert new purchase item
INSERT INTO purchase_items (purchase_id, product_id, product_name, part_number, hsn_code, uqc_code,
                            cost_price, quantity, subtotal,
                            cgst_rate, sgst_rate, igst_rate, utgst_rate,
                            cgst_amount, sgst_amount, igst_amount, utgst_amount,
                            tax_amount, total_amount)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- Update purchase item (remember to update updated_at)
UPDATE purchase_items
SET quantity = ?, subtotal = ?, tax_amount = ?, total_amount = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete a purchase item
UPDATE purchase_items SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;
```

---

### purchase_attachments
Attachments for purchase orders (invoices, receipts, etc.)

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| purchase_id | INTEGER | NOT NULL, FOREIGN KEY | | References purchases(id) |
| file_path | TEXT | NOT NULL | | File path/filename (stored in C:\motobill\database\images) |
| file_type | TEXT | | | MIME type (e.g., application/pdf, image/jpeg) |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when record was last updated (ISO 8601 format) |

**Foreign Keys:**
- `purchase_id` → `purchases(id)`

**Indexes:**
- `idx_purchase_attachments_purchase_id` - On `purchase_id`
- `idx_purchase_attachments_is_deleted` - On `is_deleted`

**Common Queries:**
```sql
-- Get all attachments for a purchase
SELECT * FROM purchase_attachments
WHERE purchase_id = ? AND is_deleted = 0;

-- Get purchases with attachment count
SELECT p.*, COUNT(pa.id) as attachment_count
FROM purchases p
LEFT JOIN purchase_attachments pa ON p.id = pa.purchase_id AND pa.is_deleted = 0
WHERE p.is_deleted = 0
GROUP BY p.id;

-- Get attachments by file type
SELECT * FROM purchase_attachments
WHERE file_type LIKE ? AND is_deleted = 0;

-- Insert new attachment
INSERT INTO purchase_attachments (purchase_id, file_path, file_type)
VALUES (?, ?, ?);

-- Update attachment (remember to update updated_at)
UPDATE purchase_attachments
SET file_path = ?, file_type = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete an attachment
UPDATE purchase_attachments SET is_deleted = 1, updated_at = datetime('now') WHERE id = ?;

-- Count attachments for a purchase
SELECT COUNT(*) as attachment_count
FROM purchase_attachments
WHERE purchase_id = ? AND is_deleted = 0;
```

---

### stock_batches
Tracks inventory batches from purchases for FIFO (First In First Out) stock management.

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| product_id | INTEGER | NOT NULL, FOREIGN KEY | | References products(id) |
| purchase_item_id | INTEGER | NOT NULL, FOREIGN KEY | | References purchase_items(id) - source of this batch |
| batch_number | TEXT | NOT NULL, UNIQUE | | Unique batch identifier (e.g., BATCH-EOF-001) |
| quantity_received | REAL | NOT NULL | | Total quantity received in this batch |
| quantity_remaining | REAL | NOT NULL | | Remaining quantity available for sale |
| cost_price | REAL | NOT NULL | | Cost price per unit for this batch |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when batch was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when batch was last updated (ISO 8601 format) |

**Foreign Keys:**
- `product_id` → `products(id)`
- `purchase_item_id` → `purchase_items(id)`

**Indexes:**
- `idx_stock_batches_product_id` - On `product_id`
- `idx_stock_batches_purchase_item_id` - On `purchase_item_id`
- `idx_stock_batches_batch_number` - On `batch_number`
- `idx_stock_batches_is_deleted` - On `is_deleted`
- `idx_stock_batches_quantity_remaining` - On `quantity_remaining`

**Common Queries:**
```sql
-- Get all active batches with remaining stock
SELECT sb.*, p.name as product_name, p.part_number
FROM stock_batches sb
JOIN products p ON sb.product_id = p.id
WHERE sb.is_deleted = 0 AND sb.quantity_remaining > 0
ORDER BY sb.created_at ASC;

-- Get oldest batch (FIFO) for a product with stock
SELECT *
FROM stock_batches
WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
ORDER BY created_at ASC
LIMIT 1;

-- Get total available stock by product
SELECT p.id, p.name, p.part_number,
       COALESCE(SUM(sb.quantity_remaining), 0) as total_stock,
       COUNT(sb.id) as batch_count
FROM products p
LEFT JOIN stock_batches sb ON p.id = sb.product_id
  AND sb.is_deleted = 0 AND sb.quantity_remaining > 0
WHERE p.is_deleted = 0
GROUP BY p.id, p.name, p.part_number
ORDER BY p.name;

-- Get batch details with usage summary
SELECT sb.batch_number, p.name as product_name,
       sb.quantity_received,
       sb.quantity_remaining,
       (sb.quantity_received - sb.quantity_remaining) as quantity_used,
       sb.cost_price,
       sb.created_at
FROM stock_batches sb
JOIN products p ON sb.product_id = p.id
WHERE sb.id = ?;

-- Get batches for a product ordered by FIFO
SELECT batch_number, quantity_remaining, cost_price, created_at
FROM stock_batches
WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
ORDER BY created_at ASC;

-- Get low stock batches (less than 5 units)
SELECT sb.batch_number, p.name as product_name,
       sb.quantity_remaining, sb.cost_price
FROM stock_batches sb
JOIN products p ON sb.product_id = p.id
WHERE sb.is_deleted = 0
  AND sb.quantity_remaining > 0
  AND sb.quantity_remaining < 5
ORDER BY sb.quantity_remaining ASC;

-- Get batches linked to a purchase
SELECT sb.*, p.name as product_name
FROM stock_batches sb
JOIN products p ON sb.product_id = p.id
WHERE sb.purchase_item_id IN (
  SELECT id FROM purchase_items WHERE purchase_id = ?
)
AND sb.is_deleted = 0;

-- Update batch quantity after sale
UPDATE stock_batches
SET quantity_remaining = quantity_remaining - ?,
    updated_at = datetime('now')
WHERE id = ? AND quantity_remaining >= ?;

-- Get batch value (stock value)
SELECT batch_number,
       quantity_remaining * cost_price as batch_value
FROM stock_batches
WHERE id = ?;

-- Get total stock value by product
SELECT p.name as product_name,
       SUM(sb.quantity_remaining * sb.cost_price) as total_value
FROM stock_batches sb
JOIN products p ON sb.product_id = p.id
WHERE sb.is_deleted = 0 AND sb.quantity_remaining > 0
GROUP BY p.id, p.name
ORDER BY total_value DESC;

-- Get exhausted batches (quantity_remaining = 0)
SELECT sb.batch_number, p.name as product_name,
       sb.quantity_received, sb.created_at
FROM stock_batches sb
JOIN products p ON sb.product_id = p.id
WHERE sb.is_deleted = 0 AND sb.quantity_remaining = 0
ORDER BY sb.updated_at DESC;

-- Check if product has sufficient stock
SELECT
  CASE
    WHEN COALESCE(SUM(quantity_remaining), 0) >= ? THEN 1
    ELSE 0
  END as has_sufficient_stock
FROM stock_batches
WHERE product_id = ? AND is_deleted = 0;

-- Get average cost price for a product
SELECT AVG(cost_price) as avg_cost_price,
       MIN(cost_price) as min_cost_price,
       MAX(cost_price) as max_cost_price
FROM stock_batches
WHERE product_id = ? AND is_deleted = 0;

-- Soft delete batch
UPDATE stock_batches
SET is_deleted = 1, updated_at = datetime('now')
WHERE id = ?;

-- Restore batch
UPDATE stock_batches
SET is_deleted = 0, updated_at = datetime('now')
WHERE id = ?;
```

---

### stock_batch_usage
Records which batches were used for each sale (bill item) to track COGS and inventory consumption.

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| bill_item_id | INTEGER | NOT NULL, FOREIGN KEY | | References bill_items(id) |
| stock_batch_id | INTEGER | NOT NULL, FOREIGN KEY | | References stock_batches(id) |
| quantity_used | REAL | NOT NULL | | Quantity used from this batch for the sale |
| cost_price | REAL | NOT NULL | | Cost price per unit at the time of sale |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when usage was recorded (ISO 8601 format) |

**Foreign Keys:**
- `bill_item_id` → `bill_items(id)`
- `stock_batch_id` → `stock_batches(id)`

**Indexes:**
- `idx_stock_batch_usage_bill_item_id` - On `bill_item_id`
- `idx_stock_batch_usage_stock_batch_id` - On `stock_batch_id`

**Common Queries:**
```sql
-- Get batch usage for a bill item
SELECT sbu.*, sb.batch_number, p.name as product_name
FROM stock_batch_usage sbu
JOIN stock_batches sb ON sbu.stock_batch_id = sb.id
JOIN products p ON sb.product_id = p.id
WHERE sbu.bill_item_id = ?;

-- Get cost of goods sold (COGS) for a bill
SELECT SUM(sbu.quantity_used * sbu.cost_price) as total_cogs
FROM stock_batch_usage sbu
JOIN bill_items bi ON sbu.bill_item_id = bi.id
WHERE bi.bill_id = ?;

-- Get profit for a bill (selling price - cost price)
SELECT
  bi.bill_id,
  SUM(bi.quantity * bi.unit_price) as total_selling_price,
  SUM(sbu.quantity_used * sbu.cost_price) as total_cogs,
  (SUM(bi.quantity * bi.unit_price) - SUM(sbu.quantity_used * sbu.cost_price)) as gross_profit
FROM bill_items bi
JOIN stock_batch_usage sbu ON bi.id = sbu.bill_item_id
WHERE bi.bill_id = ?
GROUP BY bi.bill_id;

-- Get batch usage summary for a product
SELECT p.name as product_name,
       COUNT(sbu.id) as usage_count,
       SUM(sbu.quantity_used) as total_quantity_sold,
       SUM(sbu.quantity_used * sbu.cost_price) as total_cogs
FROM stock_batch_usage sbu
JOIN stock_batches sb ON sbu.stock_batch_id = sb.id
JOIN products p ON sb.product_id = p.id
WHERE sb.product_id = ?
GROUP BY p.id, p.name;

-- Get bills that used a specific batch
SELECT DISTINCT b.bill_number, b.bill_date, c.name as customer_name
FROM bills b
JOIN bill_items bi ON b.id = bi.bill_id
JOIN stock_batch_usage sbu ON bi.id = sbu.bill_item_id
JOIN customers c ON b.customer_id = c.id
WHERE sbu.stock_batch_id = ?
ORDER BY b.bill_date DESC;

-- Get usage history for a batch
SELECT sbu.quantity_used, sbu.cost_price,
       bi.quantity as sold_quantity,
       bi.unit_price as selling_price,
       b.bill_number, b.bill_date,
       sbu.created_at as usage_date
FROM stock_batch_usage sbu
JOIN bill_items bi ON sbu.bill_item_id = bi.id
JOIN bills b ON bi.bill_id = b.id
WHERE sbu.stock_batch_id = ?
ORDER BY sbu.created_at DESC;

-- Get profit margin by product
SELECT p.name as product_name,
       SUM(bi.quantity * bi.unit_price) as total_revenue,
       SUM(sbu.quantity_used * sbu.cost_price) as total_cost,
       SUM(bi.quantity * bi.unit_price) - SUM(sbu.quantity_used * sbu.cost_price) as gross_profit,
       ROUND(
         ((SUM(bi.quantity * bi.unit_price) - SUM(sbu.quantity_used * sbu.cost_price)) /
          SUM(bi.quantity * bi.unit_price)) * 100, 2
       ) as profit_margin_percentage
FROM bill_items bi
JOIN stock_batch_usage sbu ON bi.id = sbu.bill_item_id
JOIN stock_batches sb ON sbu.stock_batch_id = sb.id
JOIN products p ON sb.product_id = p.id
GROUP BY p.id, p.name
ORDER BY gross_profit DESC;

-- Get daily COGS
SELECT DATE(sbu.created_at) as sale_date,
       SUM(sbu.quantity_used * sbu.cost_price) as daily_cogs
FROM stock_batch_usage sbu
GROUP BY DATE(sbu.created_at)
ORDER BY sale_date DESC;

-- Get batch utilization rate
SELECT sb.batch_number,
       sb.quantity_received,
       COALESCE(SUM(sbu.quantity_used), 0) as quantity_sold,
       sb.quantity_remaining,
       ROUND((COALESCE(SUM(sbu.quantity_used), 0) / sb.quantity_received) * 100, 2) as utilization_percentage
FROM stock_batches sb
LEFT JOIN stock_batch_usage sbu ON sb.id = sbu.stock_batch_id
WHERE sb.id = ?
GROUP BY sb.id, sb.batch_number, sb.quantity_received, sb.quantity_remaining;

-- Get top selling products by COGS
SELECT p.name as product_name,
       COUNT(DISTINCT sbu.bill_item_id) as times_sold,
       SUM(sbu.quantity_used) as total_quantity,
       SUM(sbu.quantity_used * sbu.cost_price) as total_cogs
FROM stock_batch_usage sbu
JOIN stock_batches sb ON sbu.stock_batch_id = sb.id
JOIN products p ON sb.product_id = p.id
GROUP BY p.id, p.name
ORDER BY total_cogs DESC
LIMIT 10;

-- Get batch usage for date range
SELECT sb.batch_number, p.name as product_name,
       SUM(sbu.quantity_used) as quantity_used,
       SUM(sbu.quantity_used * sbu.cost_price) as total_cost
FROM stock_batch_usage sbu
JOIN stock_batches sb ON sbu.stock_batch_id = sb.id
JOIN products p ON sb.product_id = p.id
WHERE DATE(sbu.created_at) BETWEEN ? AND ?
GROUP BY sb.id, sb.batch_number, p.name
ORDER BY total_cost DESC;

-- Verify batch usage integrity (total used should match batch consumption)
SELECT sb.batch_number,
       sb.quantity_received,
       sb.quantity_remaining,
       COALESCE(SUM(sbu.quantity_used), 0) as recorded_usage,
       (sb.quantity_received - sb.quantity_remaining) as calculated_usage,
       CASE
         WHEN COALESCE(SUM(sbu.quantity_used), 0) = (sb.quantity_received - sb.quantity_remaining)
         THEN 'OK'
         ELSE 'MISMATCH'
       END as status
FROM stock_batches sb
LEFT JOIN stock_batch_usage sbu ON sb.id = sbu.stock_batch_id
WHERE sb.id = ?
GROUP BY sb.id, sb.batch_number, sb.quantity_received, sb.quantity_remaining;
```

---

### credit_notes
Credit notes issued for sales returns, refunds, or adjustments against bills.

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| credit_note_number | TEXT | NOT NULL, UNIQUE | | Unique credit note number (e.g., CN-2024-0001) |
| bill_id | INTEGER | NOT NULL, FOREIGN KEY | | References bills(id) - original bill |
| customer_id | INTEGER | NOT NULL, FOREIGN KEY | | References customers(id) |
| reason | TEXT | | | Reason for credit note (e.g., defective product, wrong item) |
| subtotal | REAL | NOT NULL | | Total before tax |
| tax_amount | REAL | NOT NULL | | Total tax amount (CGST + SGST + IGST + UTGST) |
| total_amount | REAL | NOT NULL | | Final amount including tax |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when credit note was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when credit note was last updated (ISO 8601 format) |

**Foreign Keys:**
- `bill_id` → `bills(id)`
- `customer_id` → `customers(id)`

**Indexes:**
- `idx_credit_notes_bill_id` - On `bill_id`
- `idx_credit_notes_customer_id` - On `customer_id`
- `idx_credit_notes_credit_note_number` - On `credit_note_number`
- `idx_credit_notes_is_deleted` - On `is_deleted`

**Common Queries:**
```sql
-- Get all credit notes with bill and customer details
SELECT cn.*, b.bill_number, c.name as customer_name
FROM credit_notes cn
JOIN bills b ON cn.bill_id = b.id
JOIN customers c ON cn.customer_id = c.id
WHERE cn.is_deleted = 0
ORDER BY cn.created_at DESC;

-- Get credit notes for a specific bill
SELECT * FROM credit_notes
WHERE bill_id = ? AND is_deleted = 0;

-- Get credit notes for a customer
SELECT cn.*, b.bill_number
FROM credit_notes cn
JOIN bills b ON cn.bill_id = b.id
WHERE cn.customer_id = ? AND cn.is_deleted = 0
ORDER BY cn.created_at DESC;

-- Get total credit note amount for a customer
SELECT customer_id, c.name, SUM(total_amount) as total_credits
FROM credit_notes cn
JOIN customers c ON cn.customer_id = c.id
WHERE cn.is_deleted = 0
GROUP BY customer_id, c.name;

-- Get credit notes by date range
SELECT cn.*, b.bill_number, c.name as customer_name
FROM credit_notes cn
JOIN bills b ON cn.bill_id = b.id
JOIN customers c ON cn.customer_id = c.id
WHERE DATE(cn.created_at) BETWEEN ? AND ?
  AND cn.is_deleted = 0
ORDER BY cn.created_at DESC;

-- Get monthly credit note summary
SELECT strftime('%Y-%m', created_at) as month,
       COUNT(*) as credit_note_count,
       SUM(total_amount) as total_amount
FROM credit_notes
WHERE is_deleted = 0
GROUP BY strftime('%Y-%m', created_at)
ORDER BY month DESC;

-- Insert new credit note
INSERT INTO credit_notes (credit_note_number, bill_id, customer_id, reason, subtotal, tax_amount, total_amount)
VALUES (?, ?, ?, ?, ?, ?, ?);

-- Update credit note
UPDATE credit_notes
SET reason = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete credit note
UPDATE credit_notes
SET is_deleted = 1, updated_at = datetime('now')
WHERE id = ?;

-- Get credit notes with item count
SELECT cn.*, COUNT(cni.id) as item_count
FROM credit_notes cn
LEFT JOIN credit_note_items cni ON cn.id = cni.credit_note_id AND cni.is_deleted = 0
WHERE cn.is_deleted = 0
GROUP BY cn.id
ORDER BY cn.created_at DESC;
```

---

### credit_note_items
Line items for credit notes with full GST breakdown (snapshot of returned items).

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| credit_note_id | INTEGER | NOT NULL, FOREIGN KEY | | References credit_notes(id) |
| bill_item_id | INTEGER | NOT NULL, FOREIGN KEY | | References bill_items(id) - original bill item |
| product_id | INTEGER | NOT NULL, FOREIGN KEY | | References products(id) |
| product_name | TEXT | NOT NULL | | Product name (snapshot) |
| part_number | TEXT | | | Part number (snapshot) |
| hsn_code | TEXT | | | HSN/SAC code (snapshot) |
| uqc_code | TEXT | | | Unit of measurement code (snapshot) |
| selling_price | REAL | NOT NULL | | Price per unit |
| quantity | REAL | NOT NULL | | Quantity returned |
| subtotal | REAL | NOT NULL | | quantity × selling_price |
| cgst_rate | REAL | NOT NULL | 0 | CGST rate percentage |
| sgst_rate | REAL | NOT NULL | 0 | SGST rate percentage |
| igst_rate | REAL | NOT NULL | 0 | IGST rate percentage |
| utgst_rate | REAL | NOT NULL | 0 | UTGST rate percentage |
| cgst_amount | REAL | NOT NULL | 0 | Calculated CGST amount |
| sgst_amount | REAL | NOT NULL | 0 | Calculated SGST amount |
| igst_amount | REAL | NOT NULL | 0 | Calculated IGST amount |
| utgst_amount | REAL | NOT NULL | 0 | Calculated UTGST amount |
| tax_amount | REAL | NOT NULL | | Total tax (sum of all GST amounts) |
| total_amount | REAL | NOT NULL | | subtotal + tax_amount |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when item was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when item was last updated (ISO 8601 format) |

**Foreign Keys:**
- `credit_note_id` → `credit_notes(id)`
- `bill_item_id` → `bill_items(id)`
- `product_id` → `products(id)`

**Indexes:**
- `idx_credit_note_items_credit_note_id` - On `credit_note_id`
- `idx_credit_note_items_bill_item_id` - On `bill_item_id`
- `idx_credit_note_items_product_id` - On `product_id`
- `idx_credit_note_items_is_deleted` - On `is_deleted`

**Common Queries:**
```sql
-- Get all items for a credit note
SELECT * FROM credit_note_items
WHERE credit_note_id = ? AND is_deleted = 0;

-- Get credit note items with full details
SELECT cni.*, cn.credit_note_number, b.bill_number
FROM credit_note_items cni
JOIN credit_notes cn ON cni.credit_note_id = cn.id
JOIN bill_items bi ON cni.bill_item_id = bi.id
JOIN bills b ON bi.bill_id = b.id
WHERE cni.credit_note_id = ? AND cni.is_deleted = 0;

-- Get most returned products
SELECT product_id, product_name, part_number,
       COUNT(*) as return_count,
       SUM(quantity) as total_quantity_returned,
       SUM(total_amount) as total_return_value
FROM credit_note_items
WHERE is_deleted = 0
GROUP BY product_id, product_name, part_number
ORDER BY return_count DESC;

-- Get credit note GST breakdown
SELECT credit_note_id,
       SUM(cgst_amount) as total_cgst,
       SUM(sgst_amount) as total_sgst,
       SUM(igst_amount) as total_igst,
       SUM(utgst_amount) as total_utgst,
       SUM(tax_amount) as total_tax
FROM credit_note_items
WHERE credit_note_id = ? AND is_deleted = 0
GROUP BY credit_note_id;

-- Get returns for a specific product
SELECT cni.*, cn.credit_note_number, cn.reason
FROM credit_note_items cni
JOIN credit_notes cn ON cni.credit_note_id = cn.id
WHERE cni.product_id = ? AND cni.is_deleted = 0
ORDER BY cni.created_at DESC;

-- Get returns for a specific bill
SELECT cni.*, cn.credit_note_number, cn.reason
FROM credit_note_items cni
JOIN credit_notes cn ON cni.credit_note_id = cn.id
WHERE cni.bill_item_id IN (
  SELECT id FROM bill_items WHERE bill_id = ?
) AND cni.is_deleted = 0;

-- Insert new credit note item
INSERT INTO credit_note_items (
  credit_note_id, bill_item_id, product_id, product_name, part_number,
  hsn_code, uqc_code, selling_price, quantity, subtotal,
  cgst_rate, sgst_rate, cgst_amount, sgst_amount, tax_amount, total_amount
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- Soft delete credit note item
UPDATE credit_note_items
SET is_deleted = 1, updated_at = datetime('now')
WHERE id = ?;

-- Get return rate by product (percentage of sold quantity returned)
SELECT p.name as product_name,
       SUM(bi.quantity) as total_sold,
       COALESCE(SUM(cni.quantity), 0) as total_returned,
       ROUND((COALESCE(SUM(cni.quantity), 0) / SUM(bi.quantity)) * 100, 2) as return_rate_percentage
FROM bill_items bi
JOIN products p ON bi.product_id = p.id
LEFT JOIN credit_note_items cni ON bi.id = cni.bill_item_id AND cni.is_deleted = 0
WHERE bi.is_deleted = 0
GROUP BY p.id, p.name
HAVING total_returned > 0
ORDER BY return_rate_percentage DESC;
```

---

### credit_note_batch_returns
Tracks which stock batches received returned inventory from credit notes.

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| credit_note_item_id | INTEGER | NOT NULL, FOREIGN KEY | | References credit_note_items(id) |
| stock_batch_id | INTEGER | NOT NULL, FOREIGN KEY | | References stock_batches(id) - batch receiving return |
| quantity_returned | REAL | NOT NULL | | Quantity returned to this batch |
| cost_price | REAL | NOT NULL | | Original cost price of the returned items |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when return was recorded (ISO 8601 format) |

**Foreign Keys:**
- `credit_note_item_id` → `credit_note_items(id)`
- `stock_batch_id` → `stock_batches(id)`

**Indexes:**
- `idx_credit_note_batch_returns_credit_note_item_id` - On `credit_note_item_id`
- `idx_credit_note_batch_returns_stock_batch_id` - On `stock_batch_id`

**Common Queries:**
```sql
-- Get batch returns for a credit note item
SELECT cnbr.*, sb.batch_number, p.name as product_name
FROM credit_note_batch_returns cnbr
JOIN stock_batches sb ON cnbr.stock_batch_id = sb.id
JOIN products p ON sb.product_id = p.id
WHERE cnbr.credit_note_item_id = ?;

-- Get all returns to a specific batch
SELECT cnbr.*, cni.product_name, cn.credit_note_number, cn.reason
FROM credit_note_batch_returns cnbr
JOIN credit_note_items cni ON cnbr.credit_note_item_id = cni.id
JOIN credit_notes cn ON cni.credit_note_id = cn.id
WHERE cnbr.stock_batch_id = ?
ORDER BY cnbr.created_at DESC;

-- Get total returned quantity by batch
SELECT sb.batch_number, p.name as product_name,
       sb.quantity_remaining,
       COALESCE(SUM(cnbr.quantity_returned), 0) as total_returned
FROM stock_batches sb
JOIN products p ON sb.product_id = p.id
LEFT JOIN credit_note_batch_returns cnbr ON sb.id = cnbr.stock_batch_id
WHERE sb.is_deleted = 0
GROUP BY sb.id, sb.batch_number, p.name, sb.quantity_remaining
HAVING total_returned > 0
ORDER BY total_returned DESC;

-- Get return value by batch
SELECT sb.batch_number,
       SUM(cnbr.quantity_returned * cnbr.cost_price) as return_value
FROM credit_note_batch_returns cnbr
JOIN stock_batches sb ON cnbr.stock_batch_id = sb.id
GROUP BY sb.id, sb.batch_number
ORDER BY return_value DESC;

-- Get credit note with batch return details
SELECT cn.credit_note_number, cni.product_name, cni.quantity as return_quantity,
       sb.batch_number, cnbr.quantity_returned, cnbr.cost_price
FROM credit_notes cn
JOIN credit_note_items cni ON cn.id = cni.credit_note_id
JOIN credit_note_batch_returns cnbr ON cni.id = cnbr.credit_note_item_id
JOIN stock_batches sb ON cnbr.stock_batch_id = sb.id
WHERE cn.id = ?;

-- Insert new batch return (and update stock_batches.quantity_remaining)
INSERT INTO credit_note_batch_returns (credit_note_item_id, stock_batch_id, quantity_returned, cost_price)
VALUES (?, ?, ?, ?);

-- Verify return integrity (returned quantity should match credit note item)
SELECT cni.id, cni.product_name, cni.quantity as credit_note_quantity,
       COALESCE(SUM(cnbr.quantity_returned), 0) as total_batch_returns,
       CASE
         WHEN cni.quantity = COALESCE(SUM(cnbr.quantity_returned), 0)
         THEN 'OK'
         ELSE 'MISMATCH'
       END as status
FROM credit_note_items cni
LEFT JOIN credit_note_batch_returns cnbr ON cni.id = cnbr.credit_note_item_id
WHERE cni.id = ?
GROUP BY cni.id, cni.product_name, cni.quantity;

-- Get monthly return statistics
SELECT strftime('%Y-%m', cnbr.created_at) as month,
       COUNT(DISTINCT cni.credit_note_id) as credit_notes_count,
       SUM(cnbr.quantity_returned) as total_quantity_returned,
       SUM(cnbr.quantity_returned * cnbr.cost_price) as total_return_cost
FROM credit_note_batch_returns cnbr
JOIN credit_note_items cni ON cnbr.credit_note_item_id = cni.id
GROUP BY strftime('%Y-%m', cnbr.created_at)
ORDER BY month DESC;
```

---

### debit_notes
Debit notes issued for purchase returns to vendors or adjustments against purchase orders.

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| debit_note_number | TEXT | NOT NULL, UNIQUE | | Unique debit note number (e.g., DN-2024-0001) |
| purchase_id | INTEGER | NOT NULL, FOREIGN KEY | | References purchases(id) - original purchase order |
| vendor_id | INTEGER | NOT NULL, FOREIGN KEY | | References vendors(id) |
| reason | TEXT | | | Reason for debit note (e.g., defective products, damaged goods) |
| subtotal | REAL | NOT NULL | | Total before tax |
| tax_amount | REAL | NOT NULL | | Total tax amount (CGST + SGST + IGST + UTGST) |
| total_amount | REAL | NOT NULL | | Final amount including tax |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when debit note was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when debit note was last updated (ISO 8601 format) |

**Foreign Keys:**
- `purchase_id` → `purchases(id)`
- `vendor_id` → `vendors(id)`

**Indexes:**
- `idx_debit_notes_purchase_id` - On `purchase_id`
- `idx_debit_notes_vendor_id` - On `vendor_id`
- `idx_debit_notes_debit_note_number` - On `debit_note_number`
- `idx_debit_notes_is_deleted` - On `is_deleted`

**Common Queries:**
```sql
-- Get all debit notes with purchase and vendor details
SELECT dn.*, p.purchase_number, v.name as vendor_name
FROM debit_notes dn
JOIN purchases p ON dn.purchase_id = p.id
JOIN vendors v ON dn.vendor_id = v.id
WHERE dn.is_deleted = 0
ORDER BY dn.created_at DESC;

-- Get debit notes for a specific purchase order
SELECT * FROM debit_notes
WHERE purchase_id = ? AND is_deleted = 0;

-- Get debit notes for a vendor
SELECT dn.*, p.purchase_number
FROM debit_notes dn
JOIN purchases p ON dn.purchase_id = p.id
WHERE dn.vendor_id = ? AND dn.is_deleted = 0
ORDER BY dn.created_at DESC;

-- Get total debit note amount for a vendor
SELECT vendor_id, v.name, SUM(total_amount) as total_debits
FROM debit_notes dn
JOIN vendors v ON dn.vendor_id = v.id
WHERE dn.is_deleted = 0
GROUP BY vendor_id, v.name;

-- Get debit notes by date range
SELECT dn.*, p.purchase_number, v.name as vendor_name
FROM debit_notes dn
JOIN purchases p ON dn.purchase_id = p.id
JOIN vendors v ON dn.vendor_id = v.id
WHERE DATE(dn.created_at) BETWEEN ? AND ?
  AND dn.is_deleted = 0
ORDER BY dn.created_at DESC;

-- Get monthly debit note summary
SELECT strftime('%Y-%m', created_at) as month,
       COUNT(*) as debit_note_count,
       SUM(total_amount) as total_amount
FROM debit_notes
WHERE is_deleted = 0
GROUP BY strftime('%Y-%m', created_at)
ORDER BY month DESC;

-- Insert new debit note
INSERT INTO debit_notes (debit_note_number, purchase_id, vendor_id, reason, subtotal, tax_amount, total_amount)
VALUES (?, ?, ?, ?, ?, ?, ?);

-- Update debit note
UPDATE debit_notes
SET reason = ?, updated_at = datetime('now')
WHERE id = ? AND is_deleted = 0;

-- Soft delete debit note
UPDATE debit_notes
SET is_deleted = 1, updated_at = datetime('now')
WHERE id = ?;

-- Get debit notes with item count
SELECT dn.*, COUNT(dni.id) as item_count
FROM debit_notes dn
LEFT JOIN debit_note_items dni ON dn.id = dni.debit_note_id AND dni.is_deleted = 0
WHERE dn.is_deleted = 0
GROUP BY dn.id
ORDER BY dn.created_at DESC;
```

---

### debit_note_items
Line items for debit notes with full GST breakdown (snapshot of returned items).

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| debit_note_id | INTEGER | NOT NULL, FOREIGN KEY | | References debit_notes(id) |
| purchase_item_id | INTEGER | NOT NULL, FOREIGN KEY | | References purchase_items(id) - original purchase item |
| product_id | INTEGER | NOT NULL, FOREIGN KEY | | References products(id) |
| product_name | TEXT | NOT NULL | | Product name (snapshot) |
| part_number | TEXT | | | Part number (snapshot) |
| hsn_code | TEXT | | | HSN/SAC code (snapshot) |
| uqc_code | TEXT | | | Unit of measurement code (snapshot) |
| cost_price | REAL | NOT NULL | | Cost price per unit |
| quantity | REAL | NOT NULL | | Quantity returned to vendor |
| subtotal | REAL | NOT NULL | | quantity × cost_price |
| cgst_rate | REAL | NOT NULL | 0 | CGST rate percentage |
| sgst_rate | REAL | NOT NULL | 0 | SGST rate percentage |
| igst_rate | REAL | NOT NULL | 0 | IGST rate percentage |
| utgst_rate | REAL | NOT NULL | 0 | UTGST rate percentage |
| cgst_amount | REAL | NOT NULL | 0 | Calculated CGST amount |
| sgst_amount | REAL | NOT NULL | 0 | Calculated SGST amount |
| igst_amount | REAL | NOT NULL | 0 | Calculated IGST amount |
| utgst_amount | REAL | NOT NULL | 0 | Calculated UTGST amount |
| tax_amount | REAL | NOT NULL | | Total tax (sum of all GST amounts) |
| total_amount | REAL | NOT NULL | | subtotal + tax_amount |
| is_deleted | INTEGER | NOT NULL | 0 | 0 = active, 1 = soft deleted |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when item was created (ISO 8601 format) |
| updated_at | TEXT | NOT NULL | datetime('now') | Timestamp when item was last updated (ISO 8601 format) |

**Foreign Keys:**
- `debit_note_id` → `debit_notes(id)`
- `purchase_item_id` → `purchase_items(id)`
- `product_id` → `products(id)`

**Indexes:**
- `idx_debit_note_items_debit_note_id` - On `debit_note_id`
- `idx_debit_note_items_purchase_item_id` - On `purchase_item_id`
- `idx_debit_note_items_product_id` - On `product_id`
- `idx_debit_note_items_is_deleted` - On `is_deleted`

**Common Queries:**
```sql
-- Get all items for a debit note
SELECT * FROM debit_note_items
WHERE debit_note_id = ? AND is_deleted = 0;

-- Get debit note items with full details
SELECT dni.*, dn.debit_note_number, p.purchase_number
FROM debit_note_items dni
JOIN debit_notes dn ON dni.debit_note_id = dn.id
JOIN purchase_items pi ON dni.purchase_item_id = pi.id
JOIN purchases p ON pi.purchase_id = p.id
WHERE dni.debit_note_id = ? AND dni.is_deleted = 0;

-- Get most returned products to vendors
SELECT product_id, product_name, part_number,
       COUNT(*) as return_count,
       SUM(quantity) as total_quantity_returned,
       SUM(total_amount) as total_return_value
FROM debit_note_items
WHERE is_deleted = 0
GROUP BY product_id, product_name, part_number
ORDER BY return_count DESC;

-- Get debit note GST breakdown
SELECT debit_note_id,
       SUM(cgst_amount) as total_cgst,
       SUM(sgst_amount) as total_sgst,
       SUM(igst_amount) as total_igst,
       SUM(utgst_amount) as total_utgst,
       SUM(tax_amount) as total_tax
FROM debit_note_items
WHERE debit_note_id = ? AND is_deleted = 0
GROUP BY debit_note_id;

-- Get returns to vendor for a specific product
SELECT dni.*, dn.debit_note_number, dn.reason, v.name as vendor_name
FROM debit_note_items dni
JOIN debit_notes dn ON dni.debit_note_id = dn.id
JOIN vendors v ON dn.vendor_id = v.id
WHERE dni.product_id = ? AND dni.is_deleted = 0
ORDER BY dni.created_at DESC;

-- Get returns for a specific purchase order
SELECT dni.*, dn.debit_note_number, dn.reason
FROM debit_note_items dni
JOIN debit_notes dn ON dni.debit_note_id = dn.id
WHERE dni.purchase_item_id IN (
  SELECT id FROM purchase_items WHERE purchase_id = ?
) AND dni.is_deleted = 0;

-- Insert new debit note item
INSERT INTO debit_note_items (
  debit_note_id, purchase_item_id, product_id, product_name, part_number,
  hsn_code, uqc_code, cost_price, quantity, subtotal,
  cgst_rate, sgst_rate, cgst_amount, sgst_amount, tax_amount, total_amount
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- Soft delete debit note item
UPDATE debit_note_items
SET is_deleted = 1, updated_at = datetime('now')
WHERE id = ?;

-- Get return rate to vendor by product (percentage of purchased quantity returned)
SELECT p.name as product_name,
       SUM(pi.quantity) as total_purchased,
       COALESCE(SUM(dni.quantity), 0) as total_returned,
       ROUND((COALESCE(SUM(dni.quantity), 0) / SUM(pi.quantity)) * 100, 2) as return_rate_percentage
FROM purchase_items pi
JOIN products p ON pi.product_id = p.id
LEFT JOIN debit_note_items dni ON pi.id = dni.purchase_item_id AND dni.is_deleted = 0
WHERE pi.is_deleted = 0
GROUP BY p.id, p.name
HAVING total_returned > 0
ORDER BY return_rate_percentage DESC;

-- Get vendor quality score (based on return rate)
SELECT v.name as vendor_name,
       COUNT(DISTINCT p.id) as total_purchases,
       COUNT(DISTINCT dn.id) as debit_notes_count,
       SUM(pi.total_amount) as total_purchase_value,
       COALESCE(SUM(dni.total_amount), 0) as total_return_value,
       ROUND((COALESCE(SUM(dni.total_amount), 0) / SUM(pi.total_amount)) * 100, 2) as return_percentage
FROM vendors v
JOIN purchases p ON v.id = p.vendor_id AND p.is_deleted = 0
JOIN purchase_items pi ON p.id = pi.purchase_id AND pi.is_deleted = 0
LEFT JOIN debit_notes dn ON p.id = dn.purchase_id AND dn.is_deleted = 0
LEFT JOIN debit_note_items dni ON dn.id = dni.debit_note_id AND dni.is_deleted = 0
WHERE v.is_deleted = 0
GROUP BY v.id, v.name
ORDER BY return_percentage ASC;
```

---

### debit_note_batch_returns
Tracks which stock batches had inventory removed due to returns to vendors.

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | | Auto-incrementing ID |
| debit_note_item_id | INTEGER | NOT NULL, FOREIGN KEY | | References debit_note_items(id) |
| stock_batch_id | INTEGER | NOT NULL, FOREIGN KEY | | References stock_batches(id) - batch losing inventory |
| quantity_returned | REAL | NOT NULL | | Quantity returned to vendor from this batch |
| cost_price | REAL | NOT NULL | | Original cost price of the returned items |
| created_at | TEXT | NOT NULL | datetime('now') | Timestamp when return was recorded (ISO 8601 format) |

**Foreign Keys:**
- `debit_note_item_id` → `debit_note_items(id)`
- `stock_batch_id` → `stock_batches(id)`

**Indexes:**
- `idx_debit_note_batch_returns_debit_note_item_id` - On `debit_note_item_id`
- `idx_debit_note_batch_returns_stock_batch_id` - On `stock_batch_id`

**Common Queries:**
```sql
-- Get batch returns for a debit note item
SELECT dnbr.*, sb.batch_number, p.name as product_name
FROM debit_note_batch_returns dnbr
JOIN stock_batches sb ON dnbr.stock_batch_id = sb.id
JOIN products p ON sb.product_id = p.id
WHERE dnbr.debit_note_item_id = ?;

-- Get all returns from a specific batch
SELECT dnbr.*, dni.product_name, dn.debit_note_number, dn.reason
FROM debit_note_batch_returns dnbr
JOIN debit_note_items dni ON dnbr.debit_note_item_id = dni.id
JOIN debit_notes dn ON dni.debit_note_id = dn.id
WHERE dnbr.stock_batch_id = ?
ORDER BY dnbr.created_at DESC;

-- Get total returned quantity by batch
SELECT sb.batch_number, p.name as product_name,
       sb.quantity_remaining,
       COALESCE(SUM(dnbr.quantity_returned), 0) as total_returned_to_vendor
FROM stock_batches sb
JOIN products p ON sb.product_id = p.id
LEFT JOIN debit_note_batch_returns dnbr ON sb.id = dnbr.stock_batch_id
WHERE sb.is_deleted = 0
GROUP BY sb.id, sb.batch_number, p.name, sb.quantity_remaining
HAVING total_returned_to_vendor > 0
ORDER BY total_returned_to_vendor DESC;

-- Get return loss value by batch
SELECT sb.batch_number,
       SUM(dnbr.quantity_returned * dnbr.cost_price) as return_loss
FROM debit_note_batch_returns dnbr
JOIN stock_batches sb ON dnbr.stock_batch_id = sb.id
GROUP BY sb.id, sb.batch_number
ORDER BY return_loss DESC;

-- Get debit note with batch return details
SELECT dn.debit_note_number, dni.product_name, dni.quantity as return_quantity,
       sb.batch_number, dnbr.quantity_returned, dnbr.cost_price,
       v.name as vendor_name
FROM debit_notes dn
JOIN debit_note_items dni ON dn.id = dni.debit_note_id
JOIN debit_note_batch_returns dnbr ON dni.id = dnbr.debit_note_item_id
JOIN stock_batches sb ON dnbr.stock_batch_id = sb.id
JOIN vendors v ON dn.vendor_id = v.id
WHERE dn.id = ?;

-- Insert new batch return (and update stock_batches.quantity_remaining)
INSERT INTO debit_note_batch_returns (debit_note_item_id, stock_batch_id, quantity_returned, cost_price)
VALUES (?, ?, ?, ?);

-- Verify return integrity (returned quantity should match debit note item)
SELECT dni.id, dni.product_name, dni.quantity as debit_note_quantity,
       COALESCE(SUM(dnbr.quantity_returned), 0) as total_batch_returns,
       CASE
         WHEN dni.quantity = COALESCE(SUM(dnbr.quantity_returned), 0)
         THEN 'OK'
         ELSE 'MISMATCH'
       END as status
FROM debit_note_items dni
LEFT JOIN debit_note_batch_returns dnbr ON dni.id = dnbr.debit_note_item_id
WHERE dni.id = ?
GROUP BY dni.id, dni.product_name, dni.quantity;

-- Get monthly return to vendor statistics
SELECT strftime('%Y-%m', dnbr.created_at) as month,
       COUNT(DISTINCT dni.debit_note_id) as debit_notes_count,
       SUM(dnbr.quantity_returned) as total_quantity_returned,
       SUM(dnbr.quantity_returned * dnbr.cost_price) as total_return_cost
FROM debit_note_batch_returns dnbr
JOIN debit_note_items dni ON dnbr.debit_note_item_id = dni.id
GROUP BY strftime('%Y-%m', dnbr.created_at)
ORDER BY month DESC;

-- Compare credit notes vs debit notes (customer returns vs vendor returns)
SELECT
  'Customer Returns' as type,
  COUNT(*) as note_count,
  SUM(quantity_returned) as total_quantity,
  SUM(quantity_returned * cost_price) as total_value
FROM credit_note_batch_returns
UNION ALL
SELECT
  'Vendor Returns' as type,
  COUNT(*) as note_count,
  SUM(quantity_returned) as total_quantity,
  SUM(quantity_returned * cost_price) as total_value
FROM debit_note_batch_returns;
```

---

## Notes

- **Soft Delete Policy**: Never physically delete records. Always use `is_deleted = 1` for deletion.
- **Image Storage**: Store only filenames in database. Actual images stored in `C:\motobill\database\images\`.
- **Indexes**: Created for optimizing search and filtering operations.
- **Data Snapshot**: Bill items, purchase items, credit note items, and debit note items store product details (name, part_number, hsn_code, uqc_code) as snapshots to preserve historical data even if product details change later.
- **Attachment Storage**: Purchase attachments store invoices, receipts, and other documents. Store file paths and MIME types for proper handling.
- **Credit Notes & Returns**: When creating credit notes (sales returns from customers), returned items are added back to stock_batches (quantity_remaining increased). The credit_note_batch_returns table tracks which batches received the returns, maintaining FIFO integrity.
- **Debit Notes & Returns**: When creating debit notes (purchase returns to vendors), returned items are removed from stock_batches (quantity_remaining decreased). The debit_note_batch_returns table tracks which batches lost inventory due to vendor returns.
