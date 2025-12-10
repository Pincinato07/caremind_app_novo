class MetricaSaude {
  final String id;
  final String perfilId;
  final String tipo;
  final Map<String, dynamic> valor;
  final String? unidade;
  final DateTime dataHora;
  final String? observacoes;
  final DateTime createdAt;

  MetricaSaude({
    required this.id,
    required this.perfilId,
    required this.tipo,
    required this.valor,
    this.unidade,
    required this.dataHora,
    this.observacoes,
    required this.createdAt,
  });

  factory MetricaSaude.fromMap(Map<String, dynamic> map) {
    return MetricaSaude(
      id: map['id'] as String,
      perfilId: map['perfil_id'] as String,
      tipo: map['tipo'] as String,
      valor: map['valor'] as Map<String, dynamic>,
      unidade: map['unidade'] as String?,
      dataHora: DateTime.parse(map['data_hora'] as String),
      observacoes: map['observacoes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'perfil_id': perfilId,
      'tipo': tipo,
      'valor': valor,
      if (unidade != null) 'unidade': unidade,
      'data_hora': dataHora.toIso8601String(),
      if (observacoes != null) 'observacoes': observacoes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MetricaSaude copyWith({
    String? id,
    String? perfilId,
    String? tipo,
    Map<String, dynamic>? valor,
    String? unidade,
    DateTime? dataHora,
    String? observacoes,
    DateTime? createdAt,
  }) {
    return MetricaSaude(
      id: id ?? this.id,
      perfilId: perfilId ?? this.perfilId,
      tipo: tipo ?? this.tipo,
      valor: valor ?? this.valor,
      unidade: unidade ?? this.unidade,
      dataHora: dataHora ?? this.dataHora,
      observacoes: observacoes ?? this.observacoes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
