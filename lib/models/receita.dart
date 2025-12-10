class Receita {
  final int? id;
  final DateTime createdAt;
  final String perfilId;
  final String? nomeMedico;
  final DateTime? dataReceita;
  final String arquivoUrl;

  Receita({
    this.id,
    required this.createdAt,
    required this.perfilId,
    this.nomeMedico,
    this.dataReceita,
    required this.arquivoUrl,
  });

  factory Receita.fromMap(Map<String, dynamic> map) {
    return Receita(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      perfilId: map['perfil_id'] as String,
      nomeMedico: map['nome_medico'] as String?,
      dataReceita: map['data_receita'] != null 
          ? DateTime.parse(map['data_receita'] as String) 
          : null,
      arquivoUrl: map['arquivo_url'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt.toIso8601String(),
      'perfil_id': perfilId,
      if (nomeMedico != null) 'nome_medico': nomeMedico,
      if (dataReceita != null) 'data_receita': dataReceita!.toIso8601String().split('T').first,
      'arquivo_url': arquivoUrl,
    };
  }

  Receita copyWith({
    int? id,
    DateTime? createdAt,
    String? perfilId,
    String? nomeMedico,
    DateTime? dataReceita,
    String? arquivoUrl,
  }) {
    return Receita(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      perfilId: perfilId ?? this.perfilId,
      nomeMedico: nomeMedico ?? this.nomeMedico,
      dataReceita: dataReceita ?? this.dataReceita,
      arquivoUrl: arquivoUrl ?? this.arquivoUrl,
    );
  }
}
