# Automated Purchase Bill Creation - Quick Guide

## How to Use

### Step 1: Upload Invoice PDF
1. Open the application
2. Navigate to **API Test** screen (from sidebar)
3. Select **POST** method
4. Click **"Select PDF File"** button
5. Choose your invoice PDF file
6. Click **"Test API"**
7. Wait for the response (loading indicator shows progress)

### Step 2: View Response and Parse Invoice
1. After successful API call, you'll see the JSON response
2. A green button appears: **"Create Purchase Bill from Response"**
3. Click this button to parse the invoice

### Step 3: Review Invoice Details
The preview screen shows:
- **Invoice Header**: Invoice number and date
- **Vendor Info**:
  - Green badge "Existing Vendor" = Vendor found in database ✅
  - Orange badge "New Vendor" = Vendor NOT in database ⚠️
- **Line Items**: Each item shows:
  - Part number
  - Description
  - HSN code, Quantity, UQC, Amount
  - Green "Found" badge = Product exists in database ✅
  - Red "Not Found" badge = Product NOT in database ❌

### Step 4: Approve Items
- Check the box next to each item you want to include
- **Only checked items will be added to the purchase bill**
- You must approve at least one item

### Step 5: Select Stock Type (IMPORTANT!)
For each item, choose stock type:
- **Taxable** (Blue chip) = Stock goes to taxable pool
- **Non-Taxable** (Orange chip) = Stock goes to non-taxable pool
- This affects POS and billing stock availability

### Step 6: Create Purchase Bill
1. Click **"Create Purchase Bill"** button at bottom
2. System validates:
   - At least one item approved?
   - All approved items found in product database?
   - Vendor exists?
3. If validation passes:
   - Purchase bill is created
   - Success message shows with purchase number
   - Stock batches are created automatically
4. If validation fails:
   - Error message shows at top
   - Fix the issue and try again

## Error Messages & Solutions

### "No items approved"
**Solution**: Check at least one item checkbox

### "Item 'PART-123' not found in product database"
**Solution**:
1. Go to Products master screen
2. Create the product with this part number
3. Come back and try again

### "Missing vendor or invoice data"
**Solution**:
1. Go to Vendors master screen
2. Create vendor with the GSTIN shown
3. Come back and try again

## What Gets Created?

When you click "Create Purchase Bill":
1. **One purchase record** in `purchases` table
   - Auto-generated purchase number (DDMMYYSSSSSS format)
   - Vendor linked
   - Invoice number as reference
   - Totals calculated

2. **One purchase item** per approved item in `purchase_items` table
   - Product linked
   - Quantities, rates, tax details
   - HSN code, UQC code

3. **One stock batch** per approved item in `stock_batches` table
   - Initial quantity = purchased quantity
   - Cost price from invoice
   - **Taxable flag based on your selection** ✅
   - FIFO tracking enabled

## Tips

✅ **Review carefully**: Once created, you can't auto-undo (manual deletion required)
✅ **Create products first**: If many items are "Not Found", create products before importing
✅ **Check stock type**: Taxable/Non-Taxable selection affects POS billing
✅ **Vendor must exist**: Create vendor before importing if showing "New Vendor"
✅ **Approved items only**: Unchecked items are ignored completely

## Common Workflow

**Scenario 1: All products exist**
- Upload PDF → Parse → Approve all → Select stock types → Create ✅

**Scenario 2: Some products missing**
- Upload PDF → Parse → See "Not Found" badges
- Create missing products in master
- Return to API Test → Re-upload PDF → Approve → Create ✅

**Scenario 3: New vendor**
- Upload PDF → Parse → See "New Vendor" warning
- Create vendor in master (copy GSTIN from preview)
- Return to API Test → Re-upload PDF → Approve → Create ✅

**Scenario 4: Mixed stock types**
- Upload PDF → Parse → Approve items
- Toggle some to "Taxable", some to "Non-Taxable"
- Create → Stock splits correctly ✅

## Integration with Existing Features

### POS Screen
- Stock created here appears in POS product cards
- Taxable/Non-Taxable split affects stock display: "200 (100/100)"
- POS switch uses appropriate stock pool

### Create Bill Screen
- Stock batches available for billing
- FIFO allocation works normally
- Taxable switch respects stock type

### Purchase Screen
- View created purchase bills
- See all items and details
- Standard purchase operations work

## Keyboard Shortcuts
- None yet (future enhancement)

## Known Limitations

1. **Vendor must exist**: Can't auto-create vendors
2. **Product must exist**: Can't auto-create products
3. **No draft saving**: Must complete or cancel
4. **No bulk import**: One invoice at a time
5. **No editing**: Can't edit parsed data (must re-upload)

## Need Help?

**Can't find "API Test" in sidebar?**
- Check `main.dart` routing
- Should be in dashboard section

**Products not matching?**
- Check part numbers match exactly
- Case-sensitive comparison
- No leading/trailing spaces

**Stock not appearing in POS?**
- Check if created as taxable/non-taxable correctly
- Verify product is enabled
- Check `stock_batches` table `is_taxable` flag
