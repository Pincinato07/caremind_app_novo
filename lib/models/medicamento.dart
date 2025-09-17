class Medicamento {
  final int? id;
  final DateTime createdAt;
  final String nome;
  final String userId;
  final String dosagem;
  final Map<String, dynamic> frequencia;
  final int quantidade;
  final bool concluido;

  Medicamento({
    this.id,
    required this.createdAt,
    required this.nome,
    required this.userId,
    required this.dosagem,
    required this.frequencia,
    required this.quantidade,
    this.concluido = false,
  });

  factory Medicamento.fromMap(Map<String, dynamic> map) {
    return Medicamento(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      nome: map['nome'] as String,
      userId: map['user_id'] as String,
      dosagem: map['dosagem'] as String,
      frequencia: Map<String, dynamic>.from(map['frequencia'] as Map),
      quantidade: map['quantidade'] as int,
      concluido: map['concluido'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt.toIso8601String(),
      'nome': nome,
      'user_id': userId,
      'dosagem': dosagem,
      'frequencia': frequencia,
      'quantidade': quantidade,
      'concluido': concluido,
    };
  }

  Medicamento copyWith({
    int? id,
    DateTime? createdAt,
    String? nome,
    String? userId,
    String? dosagem,
    Map<String, dynamic>? frequencia,
    int? quantidade,
    bool? concluido,
  }) {
    return Medicamento(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      nome: nome ?? this.nome,
      userId: userId ?? this.userId,
      dosagem: dosagem ?? this.dosagem,
      frequencia: frequencia ?? this.frequencia,
      quantidade: quantidade ?? this.quantidade,
      concluido: concluido ?? this.concluido,
    );
  }

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