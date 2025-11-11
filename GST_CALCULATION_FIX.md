# GST Calculation Fix - Using Selected Vendor

## Problem
Previously, the GST calculation in the purchase bill automation was using the vendor GST number from the API response, not the vendor selected from the dropdown. This caused incorrect GST calculations when:
- The selected vendor was different from the one in the invoice
- The selected vendor had a different state code than the API response vendor

## Solution
Updated the GST calculation logic to:
1. Fetch the **selected vendor** from the database using the dropdown selection
2. Compare the **selected vendor's GST prefix** with the **primary company's GST prefix**
3. Recalculate GST for all approved items based on this comparison

## Changes Made

### File: `lib/view_model/purchase_bill_automation_viewmodel.dart`

#### 1. Fetch Selected Vendor (Lines ~563-595)
```dart
// Fetch selected vendor from database
final selectedVendor = await _vendorRepository!.getVendorById(vendorId);

// Fetch primary company info
final companyInfo = await _companyInfoRepository!.getPrimaryCompanyInfo();

// Extract GST prefixes (first 2 characters)
final companyGstPrefix = companyInfo?.gstNumber?.substring(0, 2) ?? '';
final vendorGstPrefix = selectedVendor.gstNumber?.substring(0, 2) ?? '';

// Determine if we should use IGST
// Use IGST when both GST numbers exist and prefixes are different
final useIGST = vendorGstPrefix.isNotEmpty &&
                companyGstPrefix.isNotEmpty &&
                vendorGstPrefix != companyGstPrefix;

print('\n=== GST Calculation for Purchase Bill ===');
print('Company GST Prefix: $companyGstPrefix');
print('Selected Vendor GST Prefix: $vendorGstPrefix');
print('Use IGST: $useIGST');
print('=========================================\n');
```

#### 2. Recalculate GST for Approved Items (Lines ~615-690)
```dart
// Recalculate GST for approved items based on selected vendor
for (int i = 0; i < approvedItems.length; i++) {
  final item = approvedItems[i];
  final index = approvedIndices[i];

  // Get product to fetch HSN code ID
  final productId = state.productMatches[index];
  if (productId == null) continue;

  final product = await _productRepository!.getProductById(productId);
  if (product == null) continue;

  // Get GST rates from database using HSN code ID
  final gstRate = await _gstRateRepository!.getGstRateByHsnCodeId(
    product.hsnCodeId,
  );

  double cgstRate = 0;
  double sgstRate = 0;
  double igstRate = 0;
  double utgstRate = 0;

  if (gstRate != null) {
    // Determine tax type based on vendor GST
    if (useIGST) {
      // Different state: Use IGST + UTGST
      igstRate = gstRate.igst;
      utgstRate = gstRate.utgst;
    } else {
      // Same state or no vendor GST: Use CGST + SGST + UTGST
      cgstRate = gstRate.cgst;
      sgstRate = gstRate.sgst;
      utgstRate = gstRate.utgst;
    }

    // Reverse calculate base amount and tax amounts
    final totalGstRate = cgstRate + sgstRate + igstRate + utgstRate;
    final baseAmount = totalGstRate > 0
        ? item.totalAmount / (1 + (totalGstRate / 100))
        : item.totalAmount;

    final cgstAmount = (baseAmount * cgstRate) / 100;
    final sgstAmount = (baseAmount * sgstRate) / 100;
    final igstAmount = (baseAmount * igstRate) / 100;
    final utgstAmount = (baseAmount * utgstRate) / 100;

    // Calculate rate (per unit price with tax)
    final rate = item.quantity > 0 ? item.totalAmount / item.quantity : 0.0;

    // Update the approved item with recalculated GST
    approvedItems[i] = ParsedInvoiceItem(
      partNumber: item.partNumber,
      description: item.description,
      hsnCode: item.hsnCode,
      uqc: item.uqc,
      quantity: item.quantity,
      rate: rate,
      cgstRate: cgstRate,
      sgstRate: sgstRate,
      igstRate: igstRate,
      utgstRate: utgstRate,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      utgstAmount: utgstAmount,
      totalAmount: item.totalAmount,
      isPriceFromBill: item.isPriceFromBill,
      isApproved: item.isApproved,
      dbProductName: item.dbProductName,
      dbProductDescription: item.dbProductDescription,
    );

    print('Item ${item.partNumber}: Total=${item.totalAmount}, '
        'CGST=${cgstRate.toStringAsFixed(2)}%, '
        'SGST=${sgstRate.toStringAsFixed(2)}%, '
        'IGST=${igstRate.toStringAsFixed(2)}%, '
        'UTGST=${utgstRate.toStringAsFixed(2)}%');
  }
}
```

## GST Calculation Logic

### Three Cases:

#### Case 1: Same State (GST Prefixes Match)
- **Condition**: `companyGstPrefix == vendorGstPrefix`
- **Tax Components**: CGST + SGST + UTGST
- **Example**: Company in Karnataka (29) + Vendor in Karnataka (29)

#### Case 2: No Vendor GST
- **Condition**: `vendorGstPrefix.isEmpty`
- **Tax Components**: CGST + SGST + UTGST
- **Example**: Company has GST but vendor doesn't

#### Case 3: Different State (IGST)
- **Condition**: `companyGstPrefix != vendorGstPrefix` AND both exist
- **Tax Components**: IGST + UTGST
- **Example**: Company in Karnataka (29) + Vendor in Maharashtra (27)

## Reverse GST Calculation Formula

```dart
// Given: Total Amount (tax-inclusive)
// Calculate: Base Amount, Tax Amounts

totalGstRate = cgstRate + sgstRate + igstRate + utgstRate;
baseAmount = totalAmount / (1 + (totalGstRate / 100));

cgstAmount = (baseAmount * cgstRate) / 100;
sgstAmount = (baseAmount * sgstRate) / 100;
igstAmount = (baseAmount * igstRate) / 100;
utgstAmount = (baseAmount * utgstRate) / 100;

rate = totalAmount / quantity;  // Per unit price (tax-inclusive)
```

## What Changed vs Previous Behavior

### Before:
- Used vendor GST from API response
- GST calculated during invoice parsing
- No recalculation when vendor changed

### After:
- Uses **selected vendor** from dropdown
- GST recalculated at bill creation time
- Compares selected vendor vs primary company
- Debug logging shows which vendor and tax type used

## API Response Vendor - Purpose Clarification

The vendor GST in the API response is **ONLY** used for:
- Auto-selecting the vendor in the dropdown IF that vendor exists in the database

It is **NOT** used for:
- GST calculation
- Tax type determination (IGST vs CGST+SGST)
- Any financial calculations

## Testing

### Test Scenario 1: Same State
1. Company GST: 29XXXXX (Karnataka)
2. Select vendor with GST: 29YYYYY (Karnataka)
3. Expected: CGST + SGST + UTGST

### Test Scenario 2: Different State
1. Company GST: 29XXXXX (Karnataka)
2. Select vendor with GST: 27YYYYY (Maharashtra)
3. Expected: IGST + UTGST

### Test Scenario 3: No Vendor GST
1. Company GST: 29XXXXX (Karnataka)
2. Select vendor with NO GST
3. Expected: CGST + SGST + UTGST

### Verification
- Check console output for GST calculation logs
- Verify purchase_items table has correct tax components
- Confirm totals match expected calculations

## Related Files
- `lib/model/apis/parsed_invoice.dart` - Model with IGST/UTGST fields
- `lib/repository/vendor_repository.dart` - Vendor data access
- `lib/repository/company_info_repository.dart` - Company data access
- `lib/repository/gst_rate_repository.dart` - GST rate lookup by HSN code ID
- `lib/repository/product_repository.dart` - Product data access

## Date
December 2024
