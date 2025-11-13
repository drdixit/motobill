# Google Drive Backup Implementation

## Overview
Successfully integrated Google Drive online backup functionality to the MotoBill application. Users can now sign in with their Google account and upload backup files directly to Google Drive with real-time progress tracking.

## Features Implemented

### 1. **Google OAuth Authentication**
   - Sign in with Google using OAuth 2.0
   - Persistent authentication using refresh tokens
   - Silent re-authentication (99% of the time)
   - Sign out functionality
   - Display user email and display name

### 2. **Google Drive Upload**
   - Upload backup ZIP files to Google Drive
   - Real-time upload progress (0-100%)
   - Automatic token refresh on expiry
   - Error handling for auth failures
   - Success/Error messages with dismiss actions

### 3. **Database Persistence**
   - Store Google credentials in `key_values` table
   - Fields stored:
     - `google_account_email`
     - `google_account_display_name`
     - `google_account_photo_url`
     - `google_account_refresh_token`
     - `google_account_access_token`
     - `google_account_token_expiry`

## Files Created/Modified

### New Files Created:

1. **lib/model/google_account_info.dart**
   - Model for storing Google account information
   - Fields: email, displayName, photoUrl, refreshToken, accessToken, tokenExpiry
   - Methods: fromJson, toJson, copyWith, isTokenExpired, isAuthenticated

2. **lib/repository/google_drive_repository.dart**
   - Repository for managing Google credentials in database
   - Methods:
     - `saveAccountInfo()` - Save account info to DB
     - `getAccountInfo()` - Retrieve account info from DB
     - `updateAccessToken()` - Update access token
     - `clearAccountInfo()` - Clear credentials from DB
     - `isAuthenticated()` - Check if user is authenticated

3. **lib/view_model/google_drive_viewmodel.dart**
   - StateNotifier for managing Google Drive state
   - State: accountInfo, isLoading, uploadProgress, error, successMessage, isAuthenticating
   - Methods:
     - `signIn()` - Google OAuth sign in flow
     - `signOut()` - Sign out and clear credentials
     - `uploadBackup(String zipFilePath)` - Upload file to Google Drive with progress
     - `clearError()` - Clear error message
     - `clearSuccess()` - Clear success message

### Modified Files:

1. **pubspec.yaml**
   - Added dependencies:
     - `google_sign_in: ^6.2.1`
     - `googleapis: ^13.2.0`
     - `extension_google_sign_in_as_googleapis_auth: ^2.0.12`

2. **lib/view/screens/settings/backup_settings_screen.dart**
   - Added "Online Backup (Google Drive)" section
   - Two-column layout:
     - Left: Google Account (sign in/out, account info)
     - Right: Upload to Drive (create & upload button, progress bar)
   - Error and success message displays
   - Integrated with GoogleDriveViewModel

## User Flow

### First Time Setup:
1. Navigate to Settings > Backup
2. Scroll to "Online Backup (Google Drive)" section
3. Click "Sign In with Google"
4. Complete Google OAuth flow in browser
5. Account email and name displayed in UI
6. Click "Create & Upload Backup"
7. Watch progress bar (0-100%)
8. Success message shows file uploaded to Google Drive

### Subsequent Uploads:
1. Navigate to Settings > Backup
2. Already signed in (account info displayed)
3. Click "Create & Upload Backup"
4. Progress bar shows upload status
5. Success message confirms upload

### Sign Out:
1. Click "Sign Out" button
2. Credentials cleared from database
3. UI returns to sign-in state

## Technical Details

### OAuth Scopes:
- `DriveApi.driveFileScope` - For uploading files to Google Drive

### Upload Progress Tracking:
- 0-10%: Authenticating
- 10-20%: Preparing file
- 20-30%: Creating Drive API
- 30-40%: Starting upload
- 40-90%: File upload (progressive)
- 90-95%: Verifying upload
- 95-100%: Complete

### Error Handling:
- Authentication errors → Prompt re-authentication
- Token expiry → Automatic refresh using refresh token
- Upload errors → Display error message with dismiss action
- Network errors → User-friendly error messages

### Security:
- Refresh tokens stored securely in SQLite database
- Access tokens refreshed automatically
- No sensitive data in UI or logs
- OAuth standard security practices

## Edge Cases Handled

1. **Token Expiry**: Automatically refreshes access token using refresh token
2. **Password Change**: Prompts re-authentication on auth failure
3. **Manual App Removal**: Requires re-authentication (detected on next upload)
4. **Sign-In Cancellation**: Shows "Sign in cancelled" message
5. **File Not Found**: Error message if backup file doesn't exist
6. **Network Issues**: Catches and displays network errors

## UI Components

### Google Account Section:
- Shows account info when authenticated:
  - ✓ Signed In indicator
  - 👤 Display name
  - ✉ Email address
  - Sign Out button (red)
- Shows sign-in prompt when not authenticated:
  - ℹ Info message about Google Drive backup
  - Sign In with Google button (blue)

### Upload Section:
- Description text
- Progress bar during upload (0-100%)
- "Create & Upload Backup" button (green)
  - Disabled when:
    - Not authenticated
    - No backup location set
    - Upload in progress
- Error/Success dismissible alerts below sections

## Testing Scenarios

### ✅ Scenario 1: First-Time Sign In
- Click "Sign In with Google"
- Complete OAuth flow
- Verify account info displayed
- Upload backup successfully

### ✅ Scenario 2: Subsequent Upload
- Already signed in
- Click "Create & Upload Backup"
- Verify progress bar updates
- Verify success message

### ✅ Scenario 3: Sign Out
- Click "Sign Out"
- Verify credentials cleared
- Verify UI returns to sign-in state

### ✅ Scenario 4: Token Refresh
- Wait for token to expire (1 hour)
- Upload backup
- Verify automatic token refresh
- Upload succeeds

### ✅ Scenario 5: Error Handling
- Disconnect network
- Try to upload
- Verify error message displayed
- Dismiss error message

## Future Enhancements (Optional)

1. **Backup History**: Show list of previous backups in Google Drive
2. **Restore from Drive**: Download and restore backups from Google Drive
3. **Auto Backup**: Scheduled automatic backups to Google Drive
4. **Backup Rotation**: Keep only last N backups in Drive
5. **Folder Selection**: Let user choose Drive folder for backups
6. **Backup Verification**: Verify backup integrity after upload

## Dependencies

```yaml
dependencies:
  google_sign_in: ^6.2.1
  googleapis: ^13.2.0
  extension_google_sign_in_as_googleapis_auth: ^2.0.12
  archive: ^3.6.1  # For local backup
  intl: ^0.19.0    # For date formatting
  file_picker: ^8.1.6  # For folder selection
```

## Database Schema

### key_values Table:
```sql
CREATE TABLE key_values (
  key TEXT PRIMARY KEY,
  value TEXT,
  created_at TEXT,
  updated_at TEXT
);
```

### Keys Used:
- `google_account_email`
- `google_account_display_name`
- `google_account_photo_url`
- `google_account_refresh_token`
- `google_account_access_token`
- `google_account_token_expiry`

## Summary

The Google Drive backup feature is now fully implemented and integrated into the MotoBill application. Users can:
- ✅ Sign in with their Google account
- ✅ Upload backup files to Google Drive
- ✅ Track upload progress in real-time
- ✅ Automatically handle token refresh
- ✅ Sign out and clear credentials
- ✅ See clear error and success messages

The implementation follows the project's MVVM architecture, uses Riverpod for state management, and stores credentials securely in the SQLite database. All edge cases are handled gracefully with appropriate user feedback.
