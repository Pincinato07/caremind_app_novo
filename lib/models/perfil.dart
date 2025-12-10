class Perfil {
  final String id; // uuid
  final DateTime createdAt;
  final String? nome;
  final String? tipo; // 'individual', 'familiar', 'idoso'
  final String? codigoVinculacao;
  final String? fotoUsuario;
  final DateTime? codigoVinculacaoExpiraEm;
  final String? telefone;
  final String? dataNascimento; // Formato ISO: YYYY-MM-DD
  final String? timezone; // Fuso horário IANA (ex: America/Sao_Paulo)
  final bool? dataSharingConsent; // Consentimento LGPD
  final DateTime? termsAcceptedAt; // Data de aceite dos termos

  Perfil({
    required this.id,
    required this.createdAt,
    this.nome,
    this.tipo,
    this.codigoVinculacao,
    this.fotoUsuario,
    this.codigoVinculacaoExpiraEm,
    this.telefone,
    this.dataNascimento,
    this.timezone,
    this.dataSharingConsent,
    this.termsAcceptedAt,
  });

  factory Perfil.fromMap(Map<String, dynamic> map) {
    try {
      return Perfil(
        id: map['id'] as String,
        createdAt: map['created_at'] != null 
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
        nome: map['nome'] as String?,
        tipo: map['tipo'] as String?,
        codigoVinculacao: map['codigo_vinculacao'] as String?,
        fotoUsuario: map['foto_usuario'] as String?,
        codigoVinculacaoExpiraEm: map['codigo_vinculacao_expira_em'] != null
            ? DateTime.parse(map['codigo_vinculacao_expira_em'] as String)
            : null,
        telefone: map['telefone'] as String?,
        dataNascimento: map['data_nascimento'] as String?,
        timezone: map['timezone'] as String?,
        dataSharingConsent: map['data_sharing_consent'] as bool?,
        termsAcceptedAt: map['terms_accepted_at'] != null
            ? DateTime.parse(map['terms_accepted_at'] as String)
            : null,
      );
    } catch (e) {
      throw Exception('Erro ao converter Perfil: $e. Map: $map');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'nome': nome,
      'tipo': tipo,
      'codigo_vinculacao': codigoVinculacao,
      'foto_usuario': fotoUsuario,
      'codigo_vinculacao_expira_em': codigoVinculacaoExpiraEm?.toIso8601String(),
      'telefone': telefone,
      'data_nascimento': dataNascimento,
      'timezone': timezone,
      'data_sharing_consent': dataSharingConsent,
      'terms_accepted_at': termsAcceptedAt?.toIso8601String(),
    };
  }

  Perfil copyWith({
    String? id,
    DateTime? createdAt,
    String? nome,
    String? tipo,
    String? codigoVinculacao,
    String? fotoUsuario,
    DateTime? codigoVinculacaoExpiraEm,
    String? telefone,
    String? dataNascimento,
    String? timezone,
    bool? dataSharingConsent,
    DateTime? termsAcceptedAt,
  }) {
    return Perfil(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      nome: nome ?? this.nome,
      tipo: tipo ?? this.tipo,
      codigoVinculacao: codigoVinculacao ?? this.codigoVinculacao,
      fotoUsuario: fotoUsuario ?? this.fotoUsuario,
      codigoVinculacaoExpiraEm: codigoVinculacaoExpiraEm ?? this.codigoVinculacaoExpiraEm,
      telefone: telefone ?? this.telefone,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      timezone: timezone ?? this.timezone,
      dataSharingConsent: dataSharingConsent ?? this.dataSharingConsent,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
    );
  }
}