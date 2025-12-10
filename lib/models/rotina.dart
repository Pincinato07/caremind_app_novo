class Rotina {
  final int? id;
  final DateTime createdAt;
  final String? titulo;
  final String? userId;
  final String? descricao;
  final bool concluido;
  final DateTime? data;
  final Map<String, dynamic>? frequencia;
  final String perfilId;

  Rotina({
    this.id,
    required this.createdAt,
    this.titulo,
    this.userId,
    this.descricao,
    this.concluido = false,
    this.data,
    this.frequencia,
    required this.perfilId,
  });

  factory Rotina.fromMap(Map<String, dynamic> map) {
    return Rotina(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      titulo: map['titulo'] as String?,
      userId: map['user_id'] as String?,
      descricao: map['descricao'] as String?,
      concluido: map['concluido'] as bool? ?? false,
      data: map['data'] != null ? DateTime.parse(map['data'] as String) : null,
      frequencia: map['frequencia'] as Map<String, dynamic>?,
      perfilId: map['perfil_id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt.toIso8601String(),
      if (titulo != null) 'titulo': titulo,
      if (userId != null) 'user_id': userId,
      if (descricao != null) 'descricao': descricao,
      'concluido': concluido,
      if (data != null) 'data': data!.toIso8601String(),
      if (frequencia != null) 'frequencia': frequencia,
      'perfil_id': perfilId,
    };
  }

  Rotina copyWith({
    int? id,
    DateTime? createdAt,
    String? titulo,
    String? userId,
    String? descricao,
    bool? concluido,
    DateTime? data,
    Map<String, dynamic>? frequencia,
    String? perfilId,
  }) {
    return Rotina(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      titulo: titulo ?? this.titulo,
      userId: userId ?? this.userId,
      descricao: descricao ?? this.descricao,
      concluido: concluido ?? this.concluido,
      data: data ?? this.data,
      frequencia: frequencia ?? this.frequencia,
      perfilId: perfilId ?? this.perfilId,
    );
  }
}
