/// Modelo de Notificação para Organização
class NotificacaoOrganizacao {
  final String organizacaoId;
  final String titulo;
  final String mensagem;
  final TipoNotificacaoOrganizacao tipo;
  final DestinatarioNotificacao destinatario;
  final String? roleEspecifico; // Se destinatario == role, especificar qual role
  final String? membroEspecificoId; // Se destinatario == membro, especificar qual membro

  NotificacaoOrganizacao({
    required this.organizacaoId,
    required this.titulo,
    required this.mensagem,
    required this.tipo,
    required this.destinatario,
    this.roleEspecifico,
    this.membroEspecificoId,
  });

  Map<String, dynamic> toJson() {
    return {
      'organizacao_id': organizacaoId,
      'titulo': titulo,
      'mensagem': mensagem,
      'tipo': tipo.name,
      'destinatario': destinatario.name,
      if (roleEspecifico != null) 'role_especifico': roleEspecifico,
      if (membroEspecificoId != null) 'membro_especifico_id': membroEspecificoId,
    };
  }
}

/// Tipos de notificação de organização
enum TipoNotificacaoOrganizacao {
  estoqueBaixo,
  eventoPendente,
  novoIdoso,
  novoMembro,
  eventoAtrasado,
  alertaGeral,
}

/// Destinatários da notificação
enum DestinatarioNotificacao {
  todos, // Todos os membros da organização
  role, // Apenas membros com role específico
  membro, // Apenas um membro específico
  admins, // Apenas administradores
}

