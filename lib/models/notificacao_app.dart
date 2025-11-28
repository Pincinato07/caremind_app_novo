/// Model para notificações do app (tabela notificacoes_app)
class NotificacaoApp {
  final String id;
  final String perfilId;
  final String titulo;
  final String mensagem;
  final String tipo; // 'info', 'warning', 'error', 'success', 'medicamento', 'rotina', 'compromisso'
  final bool lida;
  final DateTime dataCriacao;
  final DateTime? dataLeitura;
  final int prioridade; // 0=normal, 1=alta, 2=urgente
  final Map<String, dynamic>? metadata;

  NotificacaoApp({
    required this.id,
    required this.perfilId,
    required this.titulo,
    required this.mensagem,
    required this.tipo,
    required this.lida,
    required this.dataCriacao,
    this.dataLeitura,
    this.prioridade = 0,
    this.metadata,
  });

  factory NotificacaoApp.fromMap(Map<String, dynamic> map) {
    return NotificacaoApp(
      id: map['id'] as String,
      perfilId: map['perfil_id'] as String,
      titulo: map['titulo'] as String,
      mensagem: map['mensagem'] as String,
      tipo: map['tipo'] as String? ?? 'info',
      lida: map['lida'] as bool? ?? false,
      dataCriacao: DateTime.parse(map['data_criacao'] as String),
      dataLeitura: map['data_leitura'] != null 
          ? DateTime.parse(map['data_leitura'] as String) 
          : null,
      prioridade: map['prioridade'] as int? ?? 0,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'perfil_id': perfilId,
      'titulo': titulo,
      'mensagem': mensagem,
      'tipo': tipo,
      'lida': lida,
      'data_criacao': dataCriacao.toIso8601String(),
      'data_leitura': dataLeitura?.toIso8601String(),
      'prioridade': prioridade,
      'metadata': metadata,
    };
  }

  NotificacaoApp copyWith({
    String? id,
    String? perfilId,
    String? titulo,
    String? mensagem,
    String? tipo,
    bool? lida,
    DateTime? dataCriacao,
    DateTime? dataLeitura,
    int? prioridade,
    Map<String, dynamic>? metadata,
  }) {
    return NotificacaoApp(
      id: id ?? this.id,
      perfilId: perfilId ?? this.perfilId,
      titulo: titulo ?? this.titulo,
      mensagem: mensagem ?? this.mensagem,
      tipo: tipo ?? this.tipo,
      lida: lida ?? this.lida,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      dataLeitura: dataLeitura ?? this.dataLeitura,
      prioridade: prioridade ?? this.prioridade,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Retorna o tempo relativo (ex: "Há 5 minutos", "Há 2 horas")
  String get tempoRelativo {
    final agora = DateTime.now();
    final diferenca = agora.difference(dataCriacao);

    if (diferenca.inSeconds < 60) {
      return 'Agora';
    } else if (diferenca.inMinutes < 60) {
      final minutos = diferenca.inMinutes;
      return 'Há $minutos ${minutos == 1 ? 'minuto' : 'minutos'}';
    } else if (diferenca.inHours < 24) {
      final horas = diferenca.inHours;
      return 'Há $horas ${horas == 1 ? 'hora' : 'horas'}';
    } else if (diferenca.inDays < 7) {
      final dias = diferenca.inDays;
      return 'Há $dias ${dias == 1 ? 'dia' : 'dias'}';
    } else {
      final semanas = (diferenca.inDays / 7).floor();
      return 'Há $semanas ${semanas == 1 ? 'semana' : 'semanas'}';
    }
  }

  /// Verifica se é uma notificação urgente
  bool get isUrgente => prioridade >= 2;

  /// Verifica se é uma notificação de alta prioridade
  bool get isAlta => prioridade >= 1;

  @override
  String toString() {
    return 'NotificacaoApp(id: $id, titulo: $titulo, tipo: $tipo, lida: $lida)';
  }
}

