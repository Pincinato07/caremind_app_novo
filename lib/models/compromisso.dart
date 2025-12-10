class Compromisso {
  final String id; // uuid
  final String perfilId; // uuid
  final String titulo;
  final String? descricao;
  final DateTime dataHora;
  final String? local;
  final String? tipo;
  final int? lembreteMinutos;
  final DateTime createdAt;
  final DateTime updatedAt;

  Compromisso({
    required this.id,
    required this.perfilId,
    required this.titulo,
    this.descricao,
    required this.dataHora,
    this.local,
    this.tipo,
    this.lembreteMinutos,
    required this.createdAt,
    required this.updatedAt,
  });

  // Getter para compatibilidade com código existente
  String get nome => titulo;

  // Status virtual baseado na data
  String get status {
    final now = DateTime.now();
    if (dataHora.isBefore(now)) {
      return 'passado';
    }
    return 'pendente';
  }

  factory Compromisso.fromMap(Map<String, dynamic> map) {
    return Compromisso(
      id: map['id'] as String,
      perfilId: map['perfil_id'] as String,
      titulo: map['titulo'] as String,
      descricao: map['descricao'] as String?,
      dataHora: DateTime.parse(map['data_hora'] as String),
      local: map['local'] as String?,
      tipo: map['tipo'] as String?,
      lembreteMinutos: map['lembrete_minutos'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'perfil_id': perfilId,
      'titulo': titulo,
      'descricao': descricao,
      'data_hora': dataHora.toIso8601String(),
      'local': local,
      'tipo': tipo,
      'lembrete_minutos': lembreteMinutos,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'perfil_id': perfilId,
      'titulo': titulo,
      'descricao': descricao,
      'data_hora': dataHora.toIso8601String(),
      'local': local,
      'tipo': tipo,
      'lembrete_minutos': lembreteMinutos,
    };
  }

  Compromisso copyWith({
    String? id,
    String? perfilId,
    String? titulo,
    String? descricao,
    DateTime? dataHora,
    String? local,
    String? tipo,
    int? lembreteMinutos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Compromisso(
      id: id ?? this.id,
      perfilId: perfilId ?? this.perfilId,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      dataHora: dataHora ?? this.dataHora,
      local: local ?? this.local,
      tipo: tipo ?? this.tipo,
      lembreteMinutos: lembreteMinutos ?? this.lembreteMinutos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPendente => dataHora.isAfter(DateTime.now());
  bool get isPassado => dataHora.isBefore(DateTime.now());

  String get statusFormatado {
    if (isPassado) return 'Passado';
    return 'Pendente';
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