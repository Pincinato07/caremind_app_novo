class Compromisso {
  final int? id;
  final DateTime createdAt;
  final String nome;
  final String? userId; // Mantido para compatibilidade durante transição
  final String? perfilId; // Novo campo preferencial
  final DateTime dataHora;
  final String status; // 'pendente', 'concluido', 'cancelado'
  final String? observacoes;
  final String? local;
  final String? tipo; // 'consulta', 'exame', 'procedimento', etc.

  Compromisso({
    this.id,
    required this.createdAt,
    required this.nome,
    this.userId,
    this.perfilId,
    required this.dataHora,
    this.status = 'pendente',
    this.observacoes,
    this.local,
    this.tipo,
  });

  factory Compromisso.fromMap(Map<String, dynamic> map) {
    return Compromisso(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      nome: map['nome'] as String,
      userId: map['user_id'] as String?,
      perfilId: map['perfil_id'] as String?,
      dataHora: DateTime.parse(map['data_hora'] as String),
      status: map['status'] as String? ?? 'pendente',
      observacoes: map['observacoes'] as String?,
      local: map['local'] as String?,
      tipo: map['tipo'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt.toIso8601String(),
      'nome': nome,
      if (userId != null) 'user_id': userId, // Mantido para compatibilidade
      if (perfilId != null) 'perfil_id': perfilId, // Preferencial
      'data_hora': dataHora.toIso8601String(),
      'status': status,
      if (observacoes != null) 'observacoes': observacoes,
      if (local != null) 'local': local,
      if (tipo != null) 'tipo': tipo,
    };
  }

  Compromisso copyWith({
    int? id,
    DateTime? createdAt,
    String? nome,
    String? userId,
    String? perfilId,
    DateTime? dataHora,
    String? status,
    String? observacoes,
    String? local,
    String? tipo,
  }) {
    return Compromisso(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      nome: nome ?? this.nome,
      userId: userId ?? this.userId,
      perfilId: perfilId ?? this.perfilId,
      dataHora: dataHora ?? this.dataHora,
      status: status ?? this.status,
      observacoes: observacoes ?? this.observacoes,
      local: local ?? this.local,
      tipo: tipo ?? this.tipo,
    );
  }

  // Métodos auxiliares
  bool get isConcluido => status == 'concluido';
  bool get isPendente => status == 'pendente';
  bool get isCancelado => status == 'cancelado';
  
  String get statusFormatado {
    switch (status) {
      case 'concluido':
        return 'Realizado';
      case 'cancelado':
        return 'Cancelado';
      case 'pendente':
      default:
        return 'Pendente';
    }
  }

  String get dataFormatada {
    final now = DateTime.now();
    final difference = dataHora.difference(now).inDays;

    if (difference == 0) {
      return 'Hoje, ${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}';
    } else if (difference == 1) {
      return 'Amanhã, ${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}';
    } else if (difference == -1) {
      return 'Ontem, ${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dataHora.day.toString().padLeft(2, '0')}/${dataHora.month.toString().padLeft(2, '0')} às ${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}';
    }
  }
}
