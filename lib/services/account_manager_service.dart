import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AccountInfo {
  final String userId;
  final String email;
  final String? nome;
  final String? fotoUrl;
  final String? tipo;
  final DateTime lastLogin;

  AccountInfo({
    required this.userId,
    required this.email,
    this.nome,
    this.fotoUrl,
    this.tipo,
    required this.lastLogin,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'nome': nome,
      'fotoUrl': fotoUrl,
      'tipo': tipo,
      'lastLogin': lastLogin.toIso8601String(),
    };
  }

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      userId: json['userId'] as String,
      email: json['email'] as String,
      nome: json['nome'] as String?,
      fotoUrl: json['fotoUrl'] as String?,
      tipo: json['tipo'] as String?,
      lastLogin: DateTime.parse(json['lastLogin'] as String),
    );
  }
}

class AccountManagerService {
  static const String _accountsKey = 'saved_accounts';
  static const String _currentAccountKey = 'current_account_id';

  /// Salva informações da conta atual
  Future<void> saveAccount({
    required String userId,
    required String email,
    String? nome,
    String? fotoUrl,
    String? tipo,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Carregar contas existentes
    final accounts = await getSavedAccounts();

    // Atualizar ou adicionar conta
    final accountInfo = AccountInfo(
      userId: userId,
      email: email,
      nome: nome,
      fotoUrl: fotoUrl,
      tipo: tipo,
      lastLogin: DateTime.now(),
    );

    // Remover conta antiga se existir (mesmo userId)
    accounts.removeWhere((acc) => acc.userId == userId);

    // Adicionar nova conta no início (mais recente primeiro)
    accounts.insert(0, accountInfo);

    // Limitar a 5 contas salvas
    if (accounts.length > 5) {
      accounts.removeRange(5, accounts.length);
    }

    // Salvar lista de contas
    final accountsJson = accounts.map((acc) => acc.toJson()).toList();
    await prefs.setString(_accountsKey, jsonEncode(accountsJson));

    // Salvar conta atual
    await prefs.setString(_currentAccountKey, userId);
  }

  /// Obtém todas as contas salvas
  Future<List<AccountInfo>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_accountsKey);

    if (accountsJson == null || accountsJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(accountsJson);
      return decoded
          .map((json) => AccountInfo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtém o ID da conta atual
  Future<String?> getCurrentAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentAccountKey);
  }

  /// Remove uma conta da lista
  Future<void> removeAccount(String userId) async {
    final accounts = await getSavedAccounts();
    accounts.removeWhere((acc) => acc.userId == userId);

    final prefs = await SharedPreferences.getInstance();
    final accountsJson = accounts.map((acc) => acc.toJson()).toList();
    await prefs.setString(_accountsKey, jsonEncode(accountsJson));

    // Se a conta removida era a atual, limpar referência
    final currentId = await getCurrentAccountId();
    if (currentId == userId) {
      await prefs.remove(_currentAccountKey);
    }
  }

  /// Atualiza informações de uma conta existente
  Future<void> updateAccountInfo({
    required String userId,
    String? nome,
    String? fotoUrl,
    String? tipo,
  }) async {
    final accounts = await getSavedAccounts();
    final accountIndex = accounts.indexWhere((acc) => acc.userId == userId);

    if (accountIndex != -1) {
      final account = accounts[accountIndex];
      accounts[accountIndex] = AccountInfo(
        userId: account.userId,
        email: account.email,
        nome: nome ?? account.nome,
        fotoUrl: fotoUrl ?? account.fotoUrl,
        tipo: tipo ?? account.tipo,
        lastLogin: account.lastLogin,
      );

      final prefs = await SharedPreferences.getInstance();
      final accountsJson = accounts.map((acc) => acc.toJson()).toList();
      await prefs.setString(_accountsKey, jsonEncode(accountsJson));
    }
  }

  /// Limpa todas as contas salvas
  Future<void> clearAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
    await prefs.remove(_currentAccountKey);
  }
}
