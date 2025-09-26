# 📋 Documentação de Instalação - Caremind

## 🛠️ Pré-requisitos

Antes de começar, certifique-se de ter instalado em sua máquina:

- Flutter SDK (versão estável mais recente)
- Dart SDK (vem com o Flutter)
- Android Studio / Xcode (para desenvolvimento mobile)
- Git
- Uma conta no Supabase (para o backend)

## 🔧 Configuração do Ambiente

### 1. Clonar o repositório
```bash
git clone https://github.com/seu-usuario/caremind.git
cd caremind
```

### 2. Configurar variáveis de ambiente
Crie um arquivo `.env` na raiz do projeto com as seguintes variáveis:

```
SUPABASE_URL=sua_url_do_supabase
SUPABASE_ANON_KEY=sua_chave_anonima_do_supabase
```

### 3. Instalar dependências
```bash
flutter pub get
```

## 📱 Dependências do Projeto

### Dependências principais
- `supabase_flutter: ^2.5.6` - Cliente Supabase para Flutter
- `flutter_dotenv: ^5.1.0` - Gerenciamento de variáveis de ambiente
- `mobile_scanner: ^5.2.3` - Leitor de QR Code
- `permission_handler: ^11.3.1` - Gerenciamento de permissões
- `url_launcher: ^6.2.5` - Abertura de URLs externas

### Dependências de desenvolvimento
- `flutter_launcher_icons: ^0.13.1` - Geração de ícones
- `flutter_native_splash: ^2.3.8` - Configuração de splash screen

## 🔄 Comandos úteis

### Rodar o aplicativo
```bash
flutter run
```

### Gerar ícones do aplicativo
```bash
flutter pub run flutter_launcher_icons:main
```

### Gerar splash screen
```bash
flutter pub run flutter_native_splash:create
```

### Limpar e reconstruir
```bash
flutter clean
flutter pub get
```

## 🚀 Estrutura do Projeto

```
lib/
├── main.dart              # Ponto de entrada do aplicativo
├── models/               # Modelos de dados
├── screens/              # Telas do aplicativo
├── services/             # Serviços (API, autenticação, etc.)
├── utils/                # Utilitários e helpers
├── widgets/              # Componentes reutilizáveis
└── assets/               # Recursos estáticos
    ├── images/           # Imagens
    └── fonts/            # Fontes personalizadas
```

## 🔐 Configuração do Supabase

1. Crie um novo projeto no [Supabase](https://supabase.com/)
2. Vá para as configurações do projeto > API
3. Copie a URL e a chave anônima para o arquivo `.env`
4. Habilite a autenticação por e-mail/senha nas configurações de autenticação

## 📱 Executando em diferentes plataformas

### Android
```bash
flutter run -d chrome  # Web
flutter run -d windows # Windows
dart run build_runner build --delete-conflicting-outputs  # Geração de código
```

## 🐛 Solução de Problemas

### Erro de dependências
Se encontrar erros de dependências, tente:
```bash
flutter pub cache repair
flutter pub get
```

### Problemas com o Supabase
- Verifique se as credenciais no `.env` estão corretas
- Confirme se o Supabase está rodando e acessível
- Verifique as permissões das tabelas no painel do Supabase

## 📄 Licença
Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.
