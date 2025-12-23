# Testes do CareMind App

Este diretório contém os testes unitários e de integração para o aplicativo CareMind Flutter.

## Estrutura

```
test/
├── helpers/
│   ├── test_helpers.dart      # Configuração de mocks com Mockito
│   ├── mock_factories.dart     # Factories para criar dados de teste
│   └── test_setup.dart         # Setup básico para testes
└── services/
    ├── emergencia_service_test.dart
    ├── medicamento_service_test.dart
    ├── settings_service_test.dart
    ├── offline_sync_manager_test.dart
    ├── notification_service_test.dart
    ├── rotina_service_test.dart
    ├── supabase_service_test.dart
    ├── organizacao_validator_test.dart
    ├── ocr_offline_service_test.dart
    └── sync_resilience_service_test.dart
```

## Executando os Testes

### Todos os testes
```bash
flutter test
```

### Teste específico
```bash
flutter test test/services/settings_service_test.dart
```

### Com cobertura
```bash
flutter test --coverage
```

## Setup Configurado

### test_setup.dart

Foi criado um arquivo de setup completo (`test/helpers/test_setup.dart`) que:
- ✅ Inicializa Supabase com valores mockados para testes
- ✅ Configura GetIt com dependências mínimas (SupabaseClient, SupabaseService)
- ✅ Pode ser usado em todos os testes via `setUpAll(() async { await setupTests(); })`

### Como Usar o Setup

```dart
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() async {
    await setupTests();
  });

  // Seus testes aqui...
}
```

## Notas Importantes

### Dependências Externas

1. **Supabase**: Configurado automaticamente via `setupTests()` com valores mockados
   - URL: `https://test.supabase.co`
   - AnonKey: `test-anon-key-for-testing-only`
   - Não requer conexão real, mas alguns testes podem falhar se tentarem operações reais

2. **GetIt**: Configurado automaticamente via `setupTests()`
   - SupabaseClient registrado
   - SupabaseService registrado
   - SettingsService deve ser inicializado individualmente em cada teste (por causa do SharedPreferences)

### Testes que Funcionam Independentemente

Os seguintes testes funcionam sem dependências externas:
- `settings_service_test.dart` - Testa persistência local com SharedPreferences
- Testes de modelos (Medicamento, etc.)
- Testes de validação de estrutura
- Testes de enums e tipos

### Testes que Requerem Setup

Os seguintes testes podem precisar de setup adicional:
- Testes que interagem com Supabase diretamente
- Testes que requerem GetIt configurado
- Testes de integração end-to-end

## Cobertura de Testes

Os 10 testes críticos implementados cobrem:

1. ✅ **EmergenciaService** - Validações e tipos de emergência
2. ✅ **MedicamentoService** - CRUD, validações e modelo
3. ✅ **SettingsService** - Inicialização, persistência, ranges e reset
4. ✅ **OfflineSyncManager** - Inicialização e proteção contra concorrência
5. ✅ **NotificationService** - Agendamento e diferentes frequências
6. ✅ **RotinaService** - Migração de dados legados e estrutura
7. ✅ **SupabaseService** - Métodos de autenticação e estrutura
8. ✅ **OrganizacaoValidator** - Validação de permissões
9. ✅ **OcrOfflineService** - Processamento offline
10. ✅ **SyncResilienceService** - Sincronização resiliente

## Melhorias Futuras

Para aumentar a cobertura e qualidade dos testes:

1. **Mocks Avançados**: Implementar mocks completos do SupabaseClient usando Mockito
2. **Testes de Integração**: Criar testes de integração com Supabase local ou mock server
3. **Testes Widget**: Adicionar testes de widgets para componentes UI críticos
4. **Testes de Performance**: Adicionar testes de performance para operações críticas
5. **CI/CD**: Integrar testes no pipeline de CI/CD

