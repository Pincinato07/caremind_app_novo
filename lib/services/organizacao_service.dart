import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Modelo de Organização
class Organizacao {
  final String id;
  final String nome;
  final String? cnpj;
  final String? telefone;
  final String? email;
  final Map<String, dynamic>? endereco;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? statusAssinatura; // 'trialing', 'active', 'canceled', 'expired'
  final DateTime? trialEnd;
  final String? planoId;
  final String? asaasCustomerId;
  final String? asaasSubscriptionId;

  Organizacao({
    required this.id,
    required this.nome,
    this.cnpj,
    this.telefone,
    this.email,
    this.endereco,
    required this.ativo,
    required this.createdAt,
    required this.updatedAt,
    this.statusAssinatura,
    this.trialEnd,
    this.planoId,
    this.asaasCustomerId,
    this.asaasSubscriptionId,
  });

  factory Organizacao.fromJson(Map<String, dynamic> json) {
    return Organizacao(
      id: json['id'] as String,
      nome: json['nome'] as String,
      cnpj: json['cnpj'] as String?,
      telefone: json['telefone'] as String?,
      email: json['email'] as String?,
      endereco: json['endereco'] as Map<String, dynamic>?,
      ativo: json['ativo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      statusAssinatura: json['status_assinatura'] as String?,
      trialEnd: json['trial_end'] != null 
          ? DateTime.parse(json['trial_end'] as String)
          : null,
      planoId: json['plano_id'] as String?,
      asaasCustomerId: json['asaas_customer_id'] as String?,
      asaasSubscriptionId: json['asaas_subscription_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'cnpj': cnpj,
      'telefone': telefone,
      'email': email,
      'endereco': endereco,
      'ativo': ativo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Modelo de Membro da Organização
class MembroOrganizacao {
  final String id;
  final String organizacaoId;
  final String perfilId;
  final String role; // 'admin', 'medico', 'enfermeiro', 'cuidador', 'recepcionista'
  final bool ativo;
  final DateTime createdAt;
  final String? nomePerfil;
  final String? emailPerfil;

  MembroOrganizacao({
    required this.id,
    required this.organizacaoId,
    required this.perfilId,
    required this.role,
    required this.ativo,
    required this.createdAt,
    this.nomePerfil,
    this.emailPerfil,
  });

  factory MembroOrganizacao.fromJson(Map<String, dynamic> json) {
    final perfil = json['perfil'] as Map<String, dynamic>?;
    return MembroOrganizacao(
      id: json['id'] as String,
      organizacaoId: json['organizacao_id'] as String,
      perfilId: json['perfil_id'] as String,
      role: json['role'] as String,
      ativo: json['ativo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      nomePerfil: perfil?['nome'] as String?,
      emailPerfil: perfil?['email'] as String?,
    );
  }
}

/// Modelo de Idoso da Organização
class IdosoOrganizacao {
  final String id;
  final String organizacaoId;
  final String perfilId;
  final String? quarto;
  final String? setor;
  final String? observacoes;
  final DateTime createdAt;
  final String? nomePerfil;
  final String? telefonePerfil;
  final DateTime? dataNascimentoPerfil;
  final bool isVirtual;

  IdosoOrganizacao({
    required this.id,
    required this.organizacaoId,
    required this.perfilId,
    this.quarto,
    this.setor,
    this.observacoes,
    required this.createdAt,
    this.nomePerfil,
    this.telefonePerfil,
    this.dataNascimentoPerfil,
    required this.isVirtual,
  });

  factory IdosoOrganizacao.fromJson(Map<String, dynamic> json) {
    final perfil = json['perfil'] as Map<String, dynamic>?;
    return IdosoOrganizacao(
      id: json['id'] as String,
      organizacaoId: json['organizacao_id'] as String,
      perfilId: json['perfil_id'] as String,
      quarto: json['quarto'] as String?,
      setor: json['setor'] as String?,
      observacoes: json['observacoes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      nomePerfil: perfil?['nome'] as String?,
      telefonePerfil: perfil?['telefone'] as String?,
      dataNascimentoPerfil: perfil?['data_nascimento'] != null
          ? DateTime.parse(perfil!['data_nascimento'] as String)
          : null,
      isVirtual: perfil?['is_virtual'] as bool? ?? false,
    );
  }
}

/// Serviço para gerenciar organizações
class OrganizacaoService {
  final SupabaseService _supabaseService;

  OrganizacaoService(this._supabaseService);

  /// Criar nova organização
  Future<Organizacao> criarOrganizacao({
    required String nome,
    String? cnpj,
    String? telefone,
    String? email,
    Map<String, dynamic>? endereco,
  }) async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final response = await Supabase.instance.client.functions.invoke(
        'criar-organizacao',
        body: {
          'nome': nome,
          'cnpj': cnpj,
          'telefone': telefone,
          'email': email,
          'endereco': endereco,
        },
      );

      if (response.status != 200) {
        final error = response.data as Map<String, dynamic>?;
        throw Exception(error?['error'] ?? 'Erro ao criar organização');
      }

      final data = response.data as Map<String, dynamic>;
      return Organizacao.fromJson(data['organizacao'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erro ao criar organização: $e');
    }
  }

  /// Listar organizações do usuário
  Future<List<Organizacao>> listarOrganizacoes() async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        return [];
      }

      // Buscar perfil do usuário
      final perfilResponse = await Supabase.instance.client
          .from('perfis')
          .select('id')
          .eq('user_id', user.id)
          .single();

      final perfil = perfilResponse;
      final perfilId = perfil['id'] as String;

      // Buscar organizações onde o usuário é membro
      final membrosResponse = await Supabase.instance.client
          .from('membros_organizacao')
          .select('organizacao_id, organizacoes(*)')
          .eq('perfil_id', perfilId)
          .eq('ativo', true);

      if (membrosResponse.isEmpty) {
        return [];
      }

      return (membrosResponse as List)
          .map((m) {
            final orgData = (m as Map<String, dynamic>)['organizacoes'];
            if (orgData is Map<String, dynamic>) {
              return Organizacao.fromJson(orgData);
            }
            return null;
          })
          .whereType<Organizacao>()
          .toList();
    } catch (e) {
      throw Exception('Erro ao listar organizações: $e');
    }
  }

  /// Obter detalhes de uma organização
  Future<Organizacao> obterOrganizacao(String organizacaoId) async {
    try {
      final response = await Supabase.instance.client
          .from('organizacoes')
          .select('*')
          .eq('id', organizacaoId)
          .single();

      return Organizacao.fromJson(response);
    } catch (e) {
      throw Exception('Erro ao obter organização: $e');
    }
  }

  /// Atualizar organização
  Future<Organizacao> atualizarOrganizacao(
    String organizacaoId, {
    String? nome,
    String? cnpj,
    String? telefone,
    String? email,
    Map<String, dynamic>? endereco,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (nome != null) updates['nome'] = nome;
      if (cnpj != null) updates['cnpj'] = cnpj;
      if (telefone != null) updates['telefone'] = telefone;
      if (email != null) updates['email'] = email;
      if (endereco != null) updates['endereco'] = endereco;
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await Supabase.instance.client
          .from('organizacoes')
          .update(updates)
          .eq('id', organizacaoId)
          .select()
          .single();

      return Organizacao.fromJson(response);
    } catch (e) {
      throw Exception('Erro ao atualizar organização: $e');
    }
  }

  /// Obter role do usuário na organização
  Future<String?> obterRoleOrganizacao(String organizacaoId) async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) return null;

      final perfilResponse = await Supabase.instance.client
          .from('perfis')
          .select('id')
          .eq('user_id', user.id)
          .single();

      final perfil = perfilResponse;
      final perfilId = perfil['id'] as String;

      final membroResponse = await Supabase.instance.client
          .from('membros_organizacao')
          .select('role')
          .eq('organizacao_id', organizacaoId)
          .eq('perfil_id', perfilId)
          .eq('ativo', true)
          .single();

      final membro = membroResponse;
      return membro['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Verificar se usuário é membro da organização
  Future<bool> isMembroOrganizacao(String organizacaoId) async {
    final role = await obterRoleOrganizacao(organizacaoId);
    return role != null;
  }

  /// Verificar se usuário é admin
  Future<bool> isAdmin(String organizacaoId) async {
    final role = await obterRoleOrganizacao(organizacaoId);
    return role == 'admin';
  }
}

