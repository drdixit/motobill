import '../model/google_account_info.dart';
import '../repository/key_value_repository.dart';

class GoogleDriveRepository {
  final KeyValueRepository _keyValueRepository;

  static const String _googleEmailKey = 'google_account_email';
  static const String _googleDisplayNameKey = 'google_account_display_name';
  static const String _googlePhotoUrlKey = 'google_account_photo_url';
  static const String _googleRefreshTokenKey = 'google_account_refresh_token';
  static const String _googleAccessTokenKey = 'google_account_access_token';
  static const String _googleTokenExpiryKey = 'google_account_token_expiry';

  GoogleDriveRepository(this._keyValueRepository);

  // Save Google account info
  Future<void> saveAccountInfo(GoogleAccountInfo accountInfo) async {
    await _keyValueRepository.setValue(_googleEmailKey, accountInfo.email);
    await _keyValueRepository.setValue(
      _googleDisplayNameKey,
      accountInfo.displayName,
    );

    if (accountInfo.photoUrl != null) {
      await _keyValueRepository.setValue(
        _googlePhotoUrlKey,
        accountInfo.photoUrl!,
      );
    }

    if (accountInfo.refreshToken != null) {
      await _keyValueRepository.setValue(
        _googleRefreshTokenKey,
        accountInfo.refreshToken!,
      );
    }

    if (accountInfo.accessToken != null) {
      await _keyValueRepository.setValue(
        _googleAccessTokenKey,
        accountInfo.accessToken!,
      );
    }

    if (accountInfo.tokenExpiry != null) {
      await _keyValueRepository.setValue(
        _googleTokenExpiryKey,
        accountInfo.tokenExpiry!.toIso8601String(),
      );
    }
  }

  // Get Google account info
  Future<GoogleAccountInfo?> getAccountInfo() async {
    final email = await _keyValueRepository.getValue(_googleEmailKey);
    if (email == null) return null;

    final displayName = await _keyValueRepository.getValue(
      _googleDisplayNameKey,
    );
    if (displayName == null) return null;

    final photoUrl = await _keyValueRepository.getValue(_googlePhotoUrlKey);
    final refreshToken = await _keyValueRepository.getValue(
      _googleRefreshTokenKey,
    );
    final accessToken = await _keyValueRepository.getValue(
      _googleAccessTokenKey,
    );
    final tokenExpiryStr = await _keyValueRepository.getValue(
      _googleTokenExpiryKey,
    );

    return GoogleAccountInfo(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      refreshToken: refreshToken,
      accessToken: accessToken,
      tokenExpiry: tokenExpiryStr != null
          ? DateTime.tryParse(tokenExpiryStr)
          : null,
    );
  }

  // Update access token
  Future<void> updateAccessToken(String accessToken, DateTime expiry) async {
    await _keyValueRepository.setValue(_googleAccessTokenKey, accessToken);
    await _keyValueRepository.setValue(
      _googleTokenExpiryKey,
      expiry.toIso8601String(),
    );
  }

  // Clear Google account info (sign out)
  Future<void> clearAccountInfo() async {
    await _keyValueRepository.deleteKey(_googleEmailKey);
    await _keyValueRepository.deleteKey(_googleDisplayNameKey);
    await _keyValueRepository.deleteKey(_googlePhotoUrlKey);
    await _keyValueRepository.deleteKey(_googleRefreshTokenKey);
    await _keyValueRepository.deleteKey(_googleAccessTokenKey);
    await _keyValueRepository.deleteKey(_googleTokenExpiryKey);
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final refreshToken = await _keyValueRepository.getValue(
      _googleRefreshTokenKey,
    );
    return refreshToken != null && refreshToken.isNotEmpty;
  }
}
