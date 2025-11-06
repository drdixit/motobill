# Invoice Parser - Troubleshooting Guide

## Issue Fixed: "Unexpected character" JSON Parsing Error

### Root Cause
The API Test screen formats the response with headers and metadata before displaying it:
```
=== RESPONSE ===
Status: 200
Message: OK

--- Headers ---
content-type: application/json

--- Body ---
{
  "analyzeResult": { ... }
}
```

The invoice parser was trying to parse the entire formatted string instead of just the JSON body.

### Solution Implemented
Modified `InvoiceParserService.parseInvoiceResponse()` to:
1. Detect formatted response with `--- Body ---` marker
2. Extract only the JSON content after the marker
3. Remove truncation markers like `[...truncated]`
4. Parse the clean JSON

### Changes Made

**File**: `lib/model/services/invoice_parser_service.dart`

Added preprocessing logic:
```dart
// Extract JSON body from formatted response
String cleanJson = jsonResponse;

// Check if response contains formatting headers
if (jsonResponse.contains('--- Body ---')) {
  // Extract content after "--- Body ---"
  final bodyIndex = jsonResponse.indexOf('--- Body ---');
  if (bodyIndex != -1) {
    cleanJson = jsonResponse.substring(bodyIndex + 13).trim();
  }
}

// Remove truncation marker if present
if (cleanJson.contains('[...truncated]')) {
  final truncIndex = cleanJson.indexOf('[...truncated]');
  if (truncIndex != -1) {
    cleanJson = cleanJson.substring(0, truncIndex).trim();
  }
}
```

**File**: `lib/view_model/purchase_bill_automation_viewmodel.dart`

Added validation checks:
- Empty response check
- No items found check
- More descriptive error messages

### Testing the Fix

1. **Upload PDF to API**:
   - Go to API Test screen
   - Select POST method
   - Choose invoice PDF
   - Click "Test API"

2. **Verify Response Format**:
   - You should see formatted response with headers
   - Response includes `--- Body ---` section
   - JSON content follows the marker

3. **Parse Invoice**:
   - Click "Create Purchase Bill from Response"
   - Should now parse successfully
   - Preview screen should show invoice details

### Common Errors & Solutions

#### Error: "Failed to parse invoice response"
**Possible Causes**:
- Response doesn't contain `analyzeResult` structure
- Response doesn't contain `documents` array
- Azure API returned error instead of invoice data

**Solution**:
- Check the raw API response in the text field
- Verify it contains valid Azure Form Recognizer output
- Ensure the PDF was processed successfully by Azure

#### Error: "No line items found in the invoice"
**Possible Causes**:
- Invoice doesn't have line items table
- Azure couldn't detect line items
- Wrong document type (not an invoice)

**Solution**:
- Check if the PDF contains a clear line items table
- Try a different invoice PDF
- Verify the Azure API is using the "prebuilt-invoice" model

#### Error: "API response is empty"
**Possible Causes**:
- API call failed
- No response received
- Network timeout

**Solution**:
- Check API URL is correct
- Verify network connection
- Check API server is running

### Debug Logging

The parser now includes debug logging:
```dart
print('Error parsing invoice: $e');
print('Stack trace: $stackTrace');
// Prints first 500 chars of response
```

Check the terminal/console output for detailed error information.

### Response Format Variations

The parser handles:
✅ Formatted response with headers (current case)
✅ Raw JSON response (direct API calls)
✅ Truncated responses (large files)
✅ Responses with extra whitespace

### Azure Form Recognizer Response Structure

Expected structure:
```json
{
  "analyzeResult": {
    "documents": [
      {
        "fields": {
          "InvoiceId": { "content": "INV-123" },
          "InvoiceDate": { "content": "11-Oct-25" },
          "VendorName": { "content": "Vendor Name" },
          "VendorTaxId": { "content": "GSTIN123" },
          "Items": {
            "valueArray": [
              {
                "valueObject": {
                  "Description": { "content": "PART-123 Description" },
                  "ProductCode": { "content": "HSN123" },
                  "Quantity": { "content": "10" },
                  "UnitPrice": { "content": "100.00" },
                  "Amount": { "content": "1180.00" }
                }
              }
            ]
          }
        }
      }
    ]
  }
}
```

### If Issues Persist

1. **Copy Raw JSON**:
   - From API response, copy only the JSON part (after `--- Body ---`)
   - Save to a file
   - Test with a JSON validator

2. **Check Example File**:
   - Compare with `lib/example_response.json`
   - Verify structure matches

3. **Enable Detailed Logging**:
   - Check terminal output for "Response start:" message
   - This shows what the parser is trying to parse

4. **Test with Sample Data**:
   - Use the example_response.json from the project
   - Create a simple test screen to verify parsing works

### Next Steps

If you still encounter issues:
1. Copy the error message from terminal
2. Copy first 200 lines of the API response
3. Share both for detailed debugging
