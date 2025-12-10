class UserIntegration {
  final String id;
  final String userId;
  final String provider;
  final String? amazonUserId;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserIntegration({
    required this.id,
    required this.userId,
    required this.provider,
    this.amazonUserId,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  factory UserIntegration.fromMap(Map<String, dynamic> map) {
    return UserIntegration(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      provider: map['provider'] as String,
      amazonUserId: map['amazon_user_id'] as String?,
      accessToken: map['access_token'] as String?,
      refreshToken: map['refresh_token'] as String?,
      expiresAt: map['expires_at'] != null 
          ? DateTime.parse(map['expires_at'] as String) 
          : null,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'provider': provider,
      if (amazonUserId != null) 'amazon_user_id': amazonUserId,
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  UserIntegration copyWith({
    String? id,
    String? userId,
    String? provider,
    String? amazonUserId,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserIntegration(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      provider: provider ?? this.provider,
      amazonUserId: amazonUserId ?? this.amazonUserId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}
