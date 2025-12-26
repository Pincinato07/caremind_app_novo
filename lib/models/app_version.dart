class AppVersion {
  final String id;
  final String versionName;
  final int buildNumber;
  final String downloadUrl;
  final bool? isMandatory;
  final String? changelog;
  final String? platform;
  final String? minOsVersion;
  final String? releaseDate;
  final String? createdAt;
  final String? updatedAt;

  AppVersion({
    required this.id,
    required this.versionName,
    required this.buildNumber,
    required this.downloadUrl,
    this.isMandatory = false,
    this.changelog,
    this.platform = 'all',
    this.minOsVersion,
    this.releaseDate,
    this.createdAt,
    this.updatedAt,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      id: json['id'] as String? ?? '',
      versionName: json['version_name'] as String? ?? '0.0.0',
      buildNumber: json['build_number'] as int? ?? 0,
      downloadUrl: json['download_url'] as String? ?? '',
      isMandatory: json['is_mandatory'] as bool? ?? false,
      changelog: json['changelog'] as String?,
      platform: json['platform'] as String? ?? 'all',
      minOsVersion: json['min_os_version'] as String?,
      releaseDate: json['release_date'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version_name': versionName,
      'build_number': buildNumber,
      'download_url': downloadUrl,
      'is_mandatory': isMandatory,
      'changelog': changelog,
      'platform': platform,
      'min_os_version': minOsVersion,
      'release_date': releaseDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  @override
  String toString() {
    return 'AppVersion(versionName: $versionName, buildNumber: $buildNumber, isMandatory: $isMandatory, platform: $platform)';
  }

  /// Verifica se esta versão é compatível com a plataforma atual
  bool isCompatibleWith(String currentPlatform) {
    if (platform == null || platform == 'all') return true;
    return platform == currentPlatform;
  }
}
