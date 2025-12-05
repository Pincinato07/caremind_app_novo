class Medicamento {
  final int? id;
  final DateTime createdAt;
  final String nome;
  final String? userId; // Mantido para compatibilidade durante transição
  final String? perfilId; // Novo campo preferencial
  final String dosagem;
  final Map<String, dynamic> frequencia;
  final int quantidade;
  final String? horarios;
  final String? observacoes;
  final bool? ativo;
  final DateTime? dataInicio;
  final DateTime? dataFim;

  Medicamento({
    this.id,
    required this.createdAt,
    required this.nome,
    this.userId,
    this.perfilId,
    required this.dosagem,
    required this.frequencia,
    required this.quantidade,
    this.horarios,
    this.observacoes,
    this.ativo = true,
    this.dataInicio,
    this.dataFim,
  });

  factory Medicamento.fromMap(Map<String, dynamic> map) {
    return Medicamento(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      nome: map['nome'] as String,
      userId: map['user_id'] as String?,
      perfilId: map['perfil_id'] as String?,
      dosagem: map['dosagem'] as String,
      frequencia: Map<String, dynamic>.from(map['frequencia'] as Map),
      quantidade: map['quantidade'] as int,
      horarios: map['horarios'] as String?,
      observacoes: map['observacoes'] as String?,
      ativo: map['ativo'] as bool?,
      dataInicio: map['data_inicio'] != null ? DateTime.parse(map['data_inicio'] as String) : null,
      dataFim: map['data_fim'] != null ? DateTime.parse(map['data_fim'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt.toIso8601String(),
      'nome': nome,
      if (userId != null) 'user_id': userId, // Mantido para compatibilidade
      if (perfilId != null) 'perfil_id': perfilId, // Preferencial
      'dosagem': dosagem,
      'frequencia': frequencia,
      'quantidade': quantidade,
      if (horarios != null) 'horarios': horarios,
      if (observacoes != null) 'observacoes': observacoes,
      if (ativo != null) 'ativo': ativo,
      if (dataInicio != null) 'data_inicio': dataInicio!.toIso8601String(),
      if (dataFim != null) 'data_fim': dataFim!.toIso8601String(),
    };
  }

  Medicamento copyWith({
    int? id,
    DateTime? createdAt,
    String? nome,
    String? userId,
    String? perfilId,
    String? dosagem,
    Map<String, dynamic>? frequencia,
    int? quantidade,
    String? horarios,
    String? observacoes,
    bool? ativo,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) {
    return Medicamento(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      nome: nome ?? this.nome,
      userId: userId ?? this.userId,
      perfilId: perfilId ?? this.perfilId,
      dosagem: dosagem ?? this.dosagem,
      frequencia: frequencia ?? this.frequencia,
      quantidade: quantidade ?? this.quantidade,
      horarios: horarios ?? this.horarios,
      observacoes: observacoes ?? this.observacoes,
      ativo: ativo ?? this.ativo,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
    );
  }

  // Getter temporário para compatibilidade com código existente
  // TODO: Remover após refatorar UI para usar historico_eventos
  bool get concluido => false;

  // Método auxiliar para obter descrição da frequência
  String get frequenciaDescricao {
    if (frequencia.containsKey('tipo')) {
      switch (frequencia['tipo']) {
        case 'diario':
          return 'Diário - ${frequencia['vezes_por_dia']} vez(es) por dia';
        case 'semanal':
          final dias = (frequencia['dias_semana'] as List).join(', ');
          return 'Semanal - $dias';
        case 'personalizado':
          return 'Personalizado - ${frequencia['descricao']}';
        default:
          return 'Frequência não definida';
      }
    }
    return 'Frequência não definida';
  }
}