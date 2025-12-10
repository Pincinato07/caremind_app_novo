class Medicamento {
  final int? id; // bigint
  final DateTime createdAt;
  final String nome;
  final String perfilId;
  final String? dosagem;
  final Map<String, dynamic>? frequencia;
  final int? quantidade;
  final String? via;

  Medicamento({
    this.id,
    required this.createdAt,
    required this.nome,
    required this.perfilId,
    this.dosagem,
    this.frequencia,
    this.quantidade,
    this.via,
  });

  factory Medicamento.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? frequenciaMap;
    if (map['frequencia'] != null && map['frequencia'] is Map) {
      frequenciaMap = Map<String, dynamic>.from(map['frequencia'] as Map);
    }

    return Medicamento(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      nome: map['nome'] as String? ?? '',
      perfilId: map['perfil_id'] as String,
      dosagem: map['dosagem'] as String?,
      frequencia: frequenciaMap,
      quantidade: map['quantidade'] as int?,
      via: map['via'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt.toIso8601String(),
      'nome': nome,
      'perfil_id': perfilId,
      'dosagem': dosagem,
      'frequencia': frequencia,
      'quantidade': quantidade,
      'via': via,
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'nome': nome,
      'perfil_id': perfilId,
      'dosagem': dosagem,
      'frequencia': frequencia,
      'quantidade': quantidade,
      'via': via,
    };
  }

  Medicamento copyWith({
    int? id,
    DateTime? createdAt,
    String? nome,
    String? perfilId,
    String? dosagem,
    Map<String, dynamic>? frequencia,
    int? quantidade,
    String? via,
  }) {
    return Medicamento(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      nome: nome ?? this.nome,
      perfilId: perfilId ?? this.perfilId,
      dosagem: dosagem ?? this.dosagem,
      frequencia: frequencia ?? this.frequencia,
      quantidade: quantidade ?? this.quantidade,
      via: via ?? this.via,
    );
  }

  String get frequenciaDescricao {
    if (frequencia == null) return 'Frequência não definida';
    if (frequencia!.containsKey('tipo')) {
      switch (frequencia!['tipo']) {
        case 'diario':
          return 'Diário - ${frequencia!['vezes_por_dia']} vez(es) por dia';
        case 'semanal':
          final dias = (frequencia!['dias_semana'] as List?)?.join(', ') ?? '';
          return 'Semanal - $dias';
        case 'personalizado':
          return 'Personalizado - ${frequencia!['descricao']}';
        default:
          return 'Frequência não definida';
      }
    }
    return 'Frequência não definida';
  }

  // Getter para compatibilidade com código existente
  String? get horarios {
    if (frequencia == null) return null;
    final horariosList = frequencia!['horarios'];
    if (horariosList is List) {
      return horariosList.join(', ');
    }
    return null;
  }

  // Getter para compatibilidade
  bool get ativo => true;

  // Getter para compatibilidade com código existente que usa userId
  String? get userId => perfilId;
}