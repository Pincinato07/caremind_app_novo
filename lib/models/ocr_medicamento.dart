/// Modelo para medicamento extraído via OCR
class OcrMedicamento {
  String nome;
  String dosagem;
  String frequencia;
  int quantidade;
  String? via;
  String? observacoes;

  OcrMedicamento({
    required this.nome,
    this.dosagem = '',
    this.frequencia = '',
    this.quantidade = 0,
    this.via,
    this.observacoes,
  });

  factory OcrMedicamento.fromJson(Map<String, dynamic> json) {
    return OcrMedicamento(
      nome: json['nome'] as String? ?? json['name'] as String? ?? '',
      dosagem: json['dosagem'] as String? ?? json['dosage'] as String? ?? '',
      frequencia: json['frequencia'] as String? ?? json['frequency'] as String? ?? '',
      quantidade: _parseQuantidade(json['quantidade'] ?? json['quantity']),
      via: json['via'] as String? ?? json['route'] as String?,
      observacoes: json['observacoes'] as String? ?? json['notes'] as String?,
    );
  }

  static int _parseQuantidade(dynamic value) {
    if (value == null) return 30; // Valor padrão
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 30;
    }
    return 30;
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'dosagem': dosagem,
      'frequencia': frequencia,
      'quantidade': quantidade,
      'via': via,
      'observacoes': observacoes,
    };
  }

  /// Converte a frequência texto para o formato JSON esperado pela tabela medicamentos
  Map<String, dynamic> toFrequenciaJson() {
    // Tentar interpretar a frequência
    final freq = frequencia.toLowerCase();
    
    if (freq.contains('1x') || freq.contains('uma vez') || freq.contains('1 vez')) {
      return {
        'tipo': 'diario',
        'vezes_por_dia': 1,
        'horarios': ['08:00'],
      };
    } else if (freq.contains('2x') || freq.contains('duas vezes') || freq.contains('2 vezes')) {
      return {
        'tipo': 'diario',
        'vezes_por_dia': 2,
        'horarios': ['08:00', '20:00'],
      };
    } else if (freq.contains('3x') || freq.contains('três vezes') || freq.contains('3 vezes')) {
      return {
        'tipo': 'diario',
        'vezes_por_dia': 3,
        'horarios': ['08:00', '14:00', '20:00'],
      };
    } else if (freq.contains('4x') || freq.contains('quatro vezes') || freq.contains('4 vezes')) {
      return {
        'tipo': 'diario',
        'vezes_por_dia': 4,
        'horarios': ['06:00', '12:00', '18:00', '22:00'],
      };
    } else if (freq.contains('8/8') || freq.contains('8 em 8')) {
      return {
        'tipo': 'diario',
        'vezes_por_dia': 3,
        'horarios': ['06:00', '14:00', '22:00'],
      };
    } else if (freq.contains('12/12') || freq.contains('12 em 12')) {
      return {
        'tipo': 'diario',
        'vezes_por_dia': 2,
        'horarios': ['08:00', '20:00'],
      };
    } else if (freq.contains('6/6') || freq.contains('6 em 6')) {
      return {
        'tipo': 'diario',
        'vezes_por_dia': 4,
        'horarios': ['06:00', '12:00', '18:00', '00:00'],
      };
    }
    
    // Padrão: 1x ao dia
    return {
      'tipo': 'diario',
      'vezes_por_dia': 1,
      'horarios': ['08:00'],
      'descricao': frequencia.isNotEmpty ? frequencia : 'Conforme prescrição',
    };
  }

  OcrMedicamento copyWith({
    String? nome,
    String? dosagem,
    String? frequencia,
    int? quantidade,
    String? via,
    String? observacoes,
  }) {
    return OcrMedicamento(
      nome: nome ?? this.nome,
      dosagem: dosagem ?? this.dosagem,
      frequencia: frequencia ?? this.frequencia,
      quantidade: quantidade ?? this.quantidade,
      via: via ?? this.via,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}

