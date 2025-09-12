class VinculoFamiliar {
  final String id; // uuid
  final String idIdoso; // uuid
  final String idFamiliar; // uuid
  final DateTime createdAt;

  VinculoFamiliar({
    required this.id,
    required this.idIdoso,
    required this.idFamiliar,
    required this.createdAt,
  });

  factory VinculoFamiliar.fromMap(Map<String, dynamic> map) {
    return VinculoFamiliar(
      id: map['id'] as String,
      idIdoso: map['id_idoso'] as String,
      idFamiliar: map['id_familiar'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_idoso': idIdoso,
      'id_familiar': idFamiliar,
      'created_at': createdAt.toIso8601String(),
    };
  }

  VinculoFamiliar copyWith({
    String? id,
    String? idIdoso,
    String? idFamiliar,
    DateTime? createdAt,
  }) {
    return VinculoFamiliar(
      id: id ?? this.id,
      idIdoso: idIdoso ?? this.idIdoso,
      idFamiliar: idFamiliar ?? this.idFamiliar,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
