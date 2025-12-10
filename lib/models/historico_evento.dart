class HistoricoEvento {
  final int? id;
  final DateTime createdAt;
  final String perfilId;
  final String tipoEvento;
  final int eventoId;
  final DateTime dataPrevista;
  final String status;
  final DateTime? horarioProgramado;
  final String? bemEstarRegistrado;
  final String? idEventoOrigem;
  final String? tipoReferencia;
  final String? referenciaId;
  final String? titulo;
  final String? descricao;
  final int? medicamentoId;
  final int? rotinaId;

  HistoricoEvento({
    this.id,
    required this.createdAt,
    required this.perfilId,
    required this.tipoEvento,
    required this.eventoId,
    required this.dataPrevista,
    this.status = 'pendente',
    this.horarioProgramado,
    this.bemEstarRegistrado,
    this.idEventoOrigem,
    this.tipoReferencia,
    this.referenciaId,
    this.titulo,
    this.descricao,
    this.medicamentoId,
    this.rotinaId,
  });

  factory HistoricoEvento.fromMap(Map<String, dynamic> map) {
    return HistoricoEvento(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      perfilId: map['perfil_id'] as String,
      tipoEvento: map['tipo_evento'] as String,
      eventoId: map['evento_id'] as int,
      dataPrevista: DateTime.parse(map['data_prevista'] as String),
      status: map['status'] as String? ?? 'pendente',
      horarioProgramado: map['horario_programado'] != null 
          ? DateTime.parse(map['horario_programado'] as String) 
          : null,
      bemEstarRegistrado: map['bem_estar_registrado'] as String?,
      idEventoOrigem: map['id_evento_origem'] as String?,
      tipoReferencia: map['tipo_referencia'] as String?,
      referenciaId: map['referencia_id'] as String?,
      titulo: map['titulo'] as String?,
      descricao: map['descricao'] as String?,
      medicamentoId: map['medicamento_id'] as int?,
      rotinaId: map['rotina_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt.toIso8601String(),
      'perfil_id': perfilId,
      'tipo_evento': tipoEvento,
      'evento_id': eventoId,
      'data_prevista': dataPrevista.toIso8601String(),
      'status': status,
      'horario_programado': horarioProgramado?.toIso8601String(),
      'bem_estar_registrado': bemEstarRegistrado,
      'id_evento_origem': idEventoOrigem,
      'tipo_referencia': tipoReferencia,
      'referencia_id': referenciaId,
      'titulo': titulo,
      'descricao': descricao,
      'medicamento_id': medicamentoId,
      'rotina_id': rotinaId,
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'perfil_id': perfilId,
      'tipo_evento': tipoEvento,
      'evento_id': eventoId,
      'data_prevista': dataPrevista.toIso8601String(),
      'status': status,
      'horario_programado': horarioProgramado?.toIso8601String(),
      'bem_estar_registrado': bemEstarRegistrado,
      'id_evento_origem': idEventoOrigem,
      'tipo_referencia': tipoReferencia,
      'referencia_id': referenciaId,
      'titulo': titulo,
      'descricao': descricao,
      'medicamento_id': medicamentoId,
      'rotina_id': rotinaId,
    };
  }

  HistoricoEvento copyWith({
    int? id,
    DateTime? createdAt,
    String? perfilId,
    String? tipoEvento,
    int? eventoId,
    DateTime? dataPrevista,
    String? status,
    DateTime? horarioProgramado,
    String? bemEstarRegistrado,
    String? idEventoOrigem,
    String? tipoReferencia,
    String? referenciaId,
    String? titulo,
    String? descricao,
    int? medicamentoId,
    int? rotinaId,
  }) {
    return HistoricoEvento(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      perfilId: perfilId ?? this.perfilId,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      eventoId: eventoId ?? this.eventoId,
      dataPrevista: dataPrevista ?? this.dataPrevista,
      status: status ?? this.status,
      horarioProgramado: horarioProgramado ?? this.horarioProgramado,
      bemEstarRegistrado: bemEstarRegistrado ?? this.bemEstarRegistrado,
      idEventoOrigem: idEventoOrigem ?? this.idEventoOrigem,
      tipoReferencia: tipoReferencia ?? this.tipoReferencia,
      referenciaId: referenciaId ?? this.referenciaId,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      medicamentoId: medicamentoId ?? this.medicamentoId,
      rotinaId: rotinaId ?? this.rotinaId,
    );
  }

  bool get isPendente => status == 'pendente';
  bool get isConcluido => status == 'concluido';
  bool get isCancelado => status == 'cancelado';

  String get statusFormatado {
    switch (status) {
      case 'pendente':
        return 'Pendente';
      case 'concluido':
        return 'Concluído';
      case 'cancelado':
        return 'Cancelado';
      default:
        return status;
    }
  }
}
