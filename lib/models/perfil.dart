class Perfil {
  final String id; // uuid
  final DateTime createdAt;
  final String? nome;
  final String? tipo; // 'individual', 'familiar', 'idoso'
  final String? codigoVinculacao;
  final String? fotoUsuario;
  final DateTime? codigoVinculacaoExpiraEm;

  Perfil({
    required this.id,
    required this.createdAt,
    this.nome,
    this.tipo,
    this.codigoVinculacao,
    this.fotoUsuario,
    this.codigoVinculacaoExpiraEm,
  });

  factory Perfil.fromMap(Map<String, dynamic> map) {
    return Perfil(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      nome: map['nome'] as String?,
      tipo: map['tipo'] as String?,
      codigoVinculacao: map['codigo_vinculacao'] as String?,
      fotoUsuario: map['foto_usuario'] as String?,
      codigoVinculacaoExpiraEm: map['codigo_vinculacao_expira_em'] != null
          ? DateTime.parse(map['codigo_vinculacao_expira_em'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'nome': nome,
      'tipo': tipo,
      'codigo_vinculacao': codigoVinculacao,
      'foto_usuario': fotoUsuario,
      'codigo_vinculacao_expira_em': codigoVinculacaoExpiraEm?.toIso8601String(),
    };
  }

  Perfil copyWith({
    String? id,
    DateTime? createdAt,
    String? nome,
    String? tipo,
    String? codigoVinculacao,
    String? fotoUsuario,
    DateTime? codigoVinculacaoExpiraEm,
  }) {
    return Perfil(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      nome: nome ?? this.nome,
      tipo: tipo ?? this.tipo,
      codigoVinculacao: codigoVinculacao ?? this.codigoVinculacao,
      fotoUsuario: fotoUsuario ?? this.fotoUsuario,
      codigoVinculacaoExpiraEm: codigoVinculacaoExpiraEm ?? this.codigoVinculacaoExpiraEm,
    );
  }
}
