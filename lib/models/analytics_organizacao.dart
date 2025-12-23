/// Modelo de Analytics de Organização
class AnalyticsOrganizacao {
  final int totalIdosos;
  final int totalMedicamentos;
  final int totalRotinas;
  final int medicamentosPendentes;
  final int eventosHoje;
  final int eventosAtrasados;
  final double taxaAdesaoGeral;
  final List<AdesaoPorIdoso> adesaoPorIdoso;
  final List<MedicamentoStats> medicamentosStats;
  final List<EventoPorDia> eventosPorDia;

  AnalyticsOrganizacao({
    required this.totalIdosos,
    required this.totalMedicamentos,
    required this.totalRotinas,
    required this.medicamentosPendentes,
    required this.eventosHoje,
    required this.eventosAtrasados,
    required this.taxaAdesaoGeral,
    required this.adesaoPorIdoso,
    required this.medicamentosStats,
    required this.eventosPorDia,
  });

  factory AnalyticsOrganizacao.fromJson(Map<String, dynamic> json) {
    return AnalyticsOrganizacao(
      totalIdosos: json['total_idosos'] as int? ?? 0,
      totalMedicamentos: json['total_medicamentos'] as int? ?? 0,
      totalRotinas: json['total_rotinas'] as int? ?? 0,
      medicamentosPendentes: json['medicamentos_pendentes'] as int? ?? 0,
      eventosHoje: json['eventos_hoje'] as int? ?? 0,
      eventosAtrasados: json['eventos_atrasados'] as int? ?? 0,
      taxaAdesaoGeral: (json['taxa_adesao_geral'] as num?)?.toDouble() ?? 0.0,
      adesaoPorIdoso: (json['adesao_por_idoso'] as List<dynamic>?)
              ?.map((e) => AdesaoPorIdoso.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      medicamentosStats: (json['medicamentos_stats'] as List<dynamic>?)
              ?.map((e) =>
                  MedicamentoStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      eventosPorDia: (json['eventos_por_dia'] as List<dynamic>?)
              ?.map((e) => EventoPorDia.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_idosos': totalIdosos,
      'total_medicamentos': totalMedicamentos,
      'total_rotinas': totalRotinas,
      'medicamentos_pendentes': medicamentosPendentes,
      'eventos_hoje': eventosHoje,
      'eventos_atrasados': eventosAtrasados,
      'taxa_adesao_geral': taxaAdesaoGeral,
      'adesao_por_idoso': adesaoPorIdoso.map((e) => e.toJson()).toList(),
      'medicamentos_stats':
          medicamentosStats.map((e) => e.toJson()).toList(),
      'eventos_por_dia': eventosPorDia.map((e) => e.toJson()).toList(),
    };
  }
}

/// Estatísticas de adesão por idoso
class AdesaoPorIdoso {
  final String idosoId;
  final String idosoNome;
  final int totalEventos;
  final int eventosConcluidos;
  final double taxaAdesao;

  AdesaoPorIdoso({
    required this.idosoId,
    required this.idosoNome,
    required this.totalEventos,
    required this.eventosConcluidos,
    required this.taxaAdesao,
  });

  factory AdesaoPorIdoso.fromJson(Map<String, dynamic> json) {
    return AdesaoPorIdoso(
      idosoId: json['idoso_id'] as String,
      idosoNome: json['idoso_nome'] as String,
      totalEventos: json['total_eventos'] as int? ?? 0,
      eventosConcluidos: json['eventos_concluidos'] as int? ?? 0,
      taxaAdesao: (json['taxa_adesao'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idoso_id': idosoId,
      'idoso_nome': idosoNome,
      'total_eventos': totalEventos,
      'eventos_concluidos': eventosConcluidos,
      'taxa_adesao': taxaAdesao,
    };
  }
}

/// Estatísticas de medicamentos por idoso
class MedicamentoStats {
  final String idosoId;
  final String idosoNome;
  final int totalMedicamentos;
  final int medicamentosPendentes;
  final int medicamentosAtrasados;

  MedicamentoStats({
    required this.idosoId,
    required this.idosoNome,
    required this.totalMedicamentos,
    required this.medicamentosPendentes,
    required this.medicamentosAtrasados,
  });

  factory MedicamentoStats.fromJson(Map<String, dynamic> json) {
    return MedicamentoStats(
      idosoId: json['idoso_id'] as String,
      idosoNome: json['idoso_nome'] as String,
      totalMedicamentos: json['total_medicamentos'] as int? ?? 0,
      medicamentosPendentes: json['medicamentos_pendentes'] as int? ?? 0,
      medicamentosAtrasados: json['medicamentos_atrasados'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idoso_id': idosoId,
      'idoso_nome': idosoNome,
      'total_medicamentos': totalMedicamentos,
      'medicamentos_pendentes': medicamentosPendentes,
      'medicamentos_atrasados': medicamentosAtrasados,
    };
  }
}

/// Estatísticas de eventos por dia
class EventoPorDia {
  final String data;
  final int total;
  final int concluidos;
  final int pendentes;
  final int atrasados;

  EventoPorDia({
    required this.data,
    required this.total,
    required this.concluidos,
    required this.pendentes,
    required this.atrasados,
  });

  factory EventoPorDia.fromJson(Map<String, dynamic> json) {
    return EventoPorDia(
      data: json['data'] as String,
      total: json['total'] as int? ?? 0,
      concluidos: json['concluidos'] as int? ?? 0,
      pendentes: json['pendentes'] as int? ?? 0,
      atrasados: json['atrasados'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'total': total,
      'concluidos': concluidos,
      'pendentes': pendentes,
      'atrasados': atrasados,
    };
  }
}

