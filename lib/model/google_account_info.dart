class GoogleAccountInfo {
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? refreshToken;
  final String? accessToken;
  final DateTime? tokenExpiry;

  GoogleAccountInfo({
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.refreshToken,
    this.accessToken,
    this.tokenExpiry,
  });

  // From JSON (database)
  factory GoogleAccountInfo.fromJson(Map<String, dynamic> json) {
    return GoogleAccountInfo(
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      photoUrl: json['photo_url'] as String?,
      refreshToken: json['refresh_token'] as String?,
      accessToken: json['access_token'] as String?,
      tokenExpiry: json['token_expiry'] != null
          ? DateTime.parse(json['token_expiry'] as String)
          : null,
    );
  }

  // To JSON (for database)
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'refresh_token': refreshToken,
      'access_token': accessToken,
      'token_expiry': tokenExpiry?.toIso8601String(),
    };
  }

  // Copy with
  GoogleAccountInfo copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    String? refreshToken,
    String? accessToken,
    DateTime? tokenExpiry,
  }) {
    return GoogleAccountInfo(
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      refreshToken: refreshToken ?? this.refreshToken,
      accessToken: accessToken ?? this.accessToken,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
    );
  }

  // Check if token is expired
  bool get isTokenExpired {
    if (tokenExpiry == null) return true;
    return DateTime.now().isAfter(tokenExpiry!);
  }

  // Check if user is authenticated
  bool get isAuthenticated {
    return refreshToken != null && refreshToken!.isNotEmpty;
  }
}
