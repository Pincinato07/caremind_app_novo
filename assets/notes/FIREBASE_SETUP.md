# 📲 Configuração de Push Notifications com Supabase + FCM

Este guia explica como configurar push notifications remotas no aplicativo Caremind.

## ⚠️ Importante: Por que Firebase?

**O backend usa 100% Supabase**, mas para push notifications remotas funcionarem com o app fechado, é **tecnicamente necessário** usar FCM (Firebase Cloud Messaging) no cliente Android e APNs no iOS. Não há como contornar isso - é uma limitação das plataformas móveis.

**Arquitetura:**
- ✅ **Backend**: 100% Supabase (banco de dados, autenticação, Edge Functions)
- ✅ **Envio de notificações**: Supabase Edge Functions chamam FCM API
- ⚠️ **Recepção no cliente**: FCM mínimo necessário (apenas para receber notificações)

O Firebase é usado **APENAS** para FCM - você não precisa configurar Analytics, Auth, ou qualquer outro serviço do Firebase.

## 📋 Pré-requisitos

- Conta no [Firebase Console](https://console.firebase.google.com/) - **apenas para FCM**
- Projeto Supabase configurado - **backend principal**
- Projeto Flutter configurado
- Android Studio (para Android)
- Xcode (para iOS)

## 🚀 Passo a Passo

### 1. Criar Projeto no Firebase Console (APENAS para FCM)

1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Clique em **"Adicionar projeto"** ou selecione um projeto existente
3. Siga o assistente para criar/configurar o projeto
4. **NÃO é necessário** ativar Google Analytics ou outros serviços - apenas FCM
5. **IMPORTANTE**: Este projeto Firebase é usado APENAS para FCM. Todo o backend usa Supabase.

### 2. Configurar Android

#### 2.1. Registrar App Android no Firebase

1. No Firebase Console, clique em **"Adicionar app"** → **Android**
2. Preencha os dados:
   - **Nome do pacote Android**: `com.example.caremind` (ou o package name do seu app)
   - **Apelido do app** (opcional): `Caremind Android`
   - **Certificado de depuração SHA-1** (opcional para desenvolvimento)
3. Clique em **"Registrar app"**

#### 2.2. Baixar arquivo `google-services.json`

1. Após registrar o app, baixe o arquivo `google-services.json`
2. **IMPORTANTE**: Coloque este arquivo em:
   ```
   android/app/google-services.json
   ```
   ⚠️ **NÃO** coloque em `android/google-services.json` (erro comum!)

#### 2.3. Verificar configuração do Android

Os arquivos já foram configurados automaticamente:
- ✅ `android/settings.gradle` - Plugin do Google Services adicionado
- ✅ `android/app/build.gradle` - Plugin e dependências do Firebase adicionadas
- ✅ `android/app/src/main/AndroidManifest.xml` - Permissões e serviços FCM configurados

### 3. Configurar iOS

#### 3.1. Registrar App iOS no Firebase

1. No Firebase Console, clique em **"Adicionar app"** → **iOS**
2. Preencha os dados:
   - **ID do pacote iOS**: O Bundle ID do seu app (ex: `com.example.caremind`)
   - **Apelido do app** (opcional): `Caremind iOS`
   - **App Store ID** (opcional)
3. Clique em **"Registrar app"**

#### 3.2. Baixar arquivo `GoogleService-Info.plist`

1. Após registrar o app, baixe o arquivo `GoogleService-Info.plist`
2. **IMPORTANTE**: Adicione este arquivo ao projeto Xcode:
   - Abra o projeto no Xcode: `ios/Runner.xcworkspace`
   - Arraste o arquivo `GoogleService-Info.plist` para a pasta `Runner` no Xcode
   - ✅ Marque **"Copy items if needed"**
   - ✅ Selecione o target **"Runner"**

#### 3.3. Configurar Push Notifications no Xcode

1. No Xcode, selecione o projeto **Runner**
2. Vá em **"Signing & Capabilities"**
3. Clique em **"+ Capability"**
4. Adicione **"Push Notifications"**
5. Adicione **"Background Modes"** e marque:
   - ✅ **Remote notifications**

#### 3.4. Verificar configuração do iOS

Os arquivos já foram configurados automaticamente:
- ✅ `ios/Runner/AppDelegate.swift` - Firebase e FCM configurados
- ✅ `ios/Runner/Info.plist` - Background modes configurados

### 4. Configurar Certificado APNs (iOS - Produção)

Para notificações push funcionarem em **produção no iOS**, você precisa:

1. **Criar certificado APNs no Apple Developer:**
   - Acesse [Apple Developer](https://developer.apple.com/)
   - Vá em **Certificates, Identifiers & Profiles**
   - Crie um **Apple Push Notification service SSL Certificate**
   - Baixe o certificado

2. **Upload no Firebase Console:**
   - No Firebase Console → **Project Settings** → **Cloud Messaging**
   - Na seção **Apple app configuration**, faça upload do certificado APNs
   - Ou configure **APNs Authentication Key** (método mais moderno)

### 5. Configurar Credenciais FCM V1 no Supabase

**IMPORTANTE**: A API FCM V1 (recomendada) usa OAuth2 ao invés de Server Key.

1. No Firebase Console → **Project Settings** → **Service Accounts**
2. Clique em **"Gerar nova chave privada"** (ou use uma conta de serviço existente)
3. Baixe o arquivo JSON da conta de serviço
4. Do arquivo JSON, você precisa de:
   - `project_id` → `FCM_PROJECT_ID`
   - `private_key` → `FCM_PRIVATE_KEY` (chave privada completa)
   - `client_email` → `FCM_CLIENT_EMAIL`

5. Configure as variáveis de ambiente no Supabase:
   ```bash
   supabase secrets set FCM_PROJECT_ID=seu-project-id
   supabase secrets set FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   supabase secrets set FCM_CLIENT_EMAIL=seu-service-account@project.iam.gserviceaccount.com
   ```

**Nota**: A `FCM_PRIVATE_KEY` deve incluir as quebras de linha `\n` e as marcações `-----BEGIN PRIVATE KEY-----` e `-----END PRIVATE KEY-----`.

### 6. Criar Tabela no Supabase para Tokens FCM

Execute este SQL no Supabase para criar a tabela de tokens:

```sql
-- Criar tabela para armazenar tokens FCM
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'unknown')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, token)
);

-- Criar índice para buscas rápidas
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token ON fcm_tokens(token);

-- Habilitar RLS (Row Level Security)
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Política: Usuários só podem ver/editar seus próprios tokens
CREATE POLICY "Users can manage their own FCM tokens"
  ON fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

### 7. Deploy da Edge Function de Push Notifications

A Edge Function `enviar-push-notification` já foi criada. Faça o deploy:

```bash
cd supabase/functions/enviar-push-notification
supabase functions deploy enviar-push-notification
```

### 8. Testar a Configuração

#### 8.1. Executar o App

```bash
# Android
flutter run

# iOS
flutter run
```

#### 8.2. Verificar Logs

Procure por estas mensagens no console:
- ✅ `Firebase inicializado com sucesso`
- ✅ `Handler de background FCM configurado`
- ✅ `FCMTokenService inicializado`
- ✅ `Token FCM obtido: [token]`
- ✅ `Token salvo no backend`

#### 8.3. Enviar Notificação de Teste via Supabase

Você pode testar enviando uma notificação via Supabase Edge Function:

```bash
curl -X POST 'https://seu-projeto.supabase.co/functions/v1/enviar-push-notification' \
  -H 'Authorization: Bearer SEU_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "user-id-aqui",
    "title": "Teste Caremind",
    "body": "Esta é uma notificação de teste",
    "priority": "high"
  }'
```

Ou use o Firebase Console para teste direto (apenas para desenvolvimento):

1. No Firebase Console → **Cloud Messaging**
2. Clique em **"Nova notificação"**
3. Preencha:
   - **Título**: `Teste Caremind`
   - **Texto**: `Esta é uma notificação de teste`
4. Clique em **"Enviar mensagem de teste"**
5. Cole o **Token FCM** obtido nos logs do app
6. Clique em **"Testar"**

### 9. Como Funciona o Envio de Notificações

O sistema funciona assim:

1. **App cliente** registra token FCM e salva no Supabase (tabela `fcm_tokens`)
2. **Edge Function `monitorar-medicamentos`** detecta medicamento atrasado
3. **Edge Function `enviar-push-notification`** é chamada com o `userId` do familiar
4. A função busca tokens FCM do usuário no Supabase
5. Envia notificação via FCM API usando a `FCM_SERVER_KEY`

**A Edge Function `enviar-push-notification` já está criada e pronta para uso!**

Ela está localizada em: `supabase/functions/enviar-push-notification/index.ts`

**Chamada da Edge Function:**

```typescript
// Exemplo: Chamar a Edge Function de push notification
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const response = await fetch(
  `${supabaseUrl}/functions/v1/enviar-push-notification`,
  {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${supabaseServiceKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      userId: "user-id-do-familiar",
      title: "💊 Medicamento Atrasado",
      body: "Paracetamol não foi tomado no horário 08:00",
      data: {
        tipo: "medicamento_atrasado",
        medicamento_id: "123",
      },
      priority: "high",
    }),
  }
);
```

A função `monitorar-medicamentos` já está configurada para chamar automaticamente esta função quando detecta um medicamento atrasado.

## 🔑 Configuração Final

### Credenciais FCM V1 (para Supabase Edge Functions)

A API FCM V1 usa OAuth2 com Service Account. Configure:

1. **Criar Service Account no Firebase:**
   - Firebase Console → **Project Settings** → **Service Accounts**
   - Clique em **"Gerar nova chave privada"**
   - Baixe o arquivo JSON

2. **Extrair credenciais do JSON:**
   ```json
   {
     "project_id": "seu-project-id",
     "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
     "client_email": "firebase-adminsdk-xxxxx@project.iam.gserviceaccount.com"
   }
   ```

3. **Configurar no Supabase:**
   ```bash
   supabase secrets set FCM_PROJECT_ID=seu-project-id
   supabase secrets set FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   supabase secrets set FCM_CLIENT_EMAIL=firebase-adminsdk-xxxxx@project.iam.gserviceaccount.com
   ```

**IMPORTANTE**: 
- A `FCM_PRIVATE_KEY` deve incluir as quebras de linha `\n` e as marcações completas
- Essas credenciais são usadas apenas pelas Edge Functions do Supabase
- O cliente não precisa dessas credenciais

### Verificar Configuração

Execute este comando para verificar se tudo está configurado:

```bash
# Verificar se google-services.json existe (Android)
ls android/app/google-services.json

# Verificar se GoogleService-Info.plist existe (iOS)
ls ios/Runner/GoogleService-Info.plist
```

## ⚠️ Troubleshooting

### Android: "google-services.json not found"

- ✅ Verifique se o arquivo está em `android/app/google-services.json` (não em `android/`)
- ✅ Verifique se o `package name` no Firebase corresponde ao `applicationId` no `build.gradle`

### iOS: "GoogleService-Info.plist not found"

- ✅ Adicione o arquivo via Xcode (não apenas copie para a pasta)
- ✅ Verifique se o arquivo está no target "Runner"
- ✅ Verifique se o Bundle ID no Firebase corresponde ao do Xcode

### Token FCM não é gerado

- ✅ Verifique se o Firebase foi inicializado antes do Supabase no `main.dart`
- ✅ Verifique os logs para erros de inicialização
- ✅ No Android, verifique se as permissões estão no `AndroidManifest.xml`
- ✅ No iOS, verifique se as capabilities estão configuradas no Xcode

### Notificações não chegam em background

- ✅ Verifique se o handler de background está configurado no `main.dart`
- ✅ No Android, verifique se o serviço FCM está no `AndroidManifest.xml`
- ✅ No iOS, verifique se "Remote notifications" está marcado em Background Modes

## 📚 Recursos Adicionais

- [Documentação oficial do Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [FlutterFire - Firebase para Flutter](https://firebase.flutter.dev/)
- [Guia de Push Notifications no Flutter](https://firebase.flutter.dev/docs/messaging/overview)

## ✅ Checklist Final

- [ ] Projeto criado no Firebase Console (apenas para FCM)
- [ ] App Android registrado e `google-services.json` baixado
- [ ] App iOS registrado e `GoogleService-Info.plist` adicionado ao Xcode
- [ ] Certificado APNs configurado (iOS produção)
- [ ] Tabela `fcm_tokens` criada no Supabase
- [ ] Credenciais FCM V1 configuradas no Supabase:
  - [ ] `FCM_PROJECT_ID`
  - [ ] `FCM_PRIVATE_KEY`
  - [ ] `FCM_CLIENT_EMAIL`
- [ ] Edge Function `enviar-push-notification` deployada
- [ ] App compila e executa sem erros
- [ ] Token FCM é gerado e salvo no Supabase
- [ ] Notificação de teste funciona via Supabase Edge Function

## 📝 Resumo da Arquitetura

```
┌─────────────────┐
│   App Flutter   │
│  (Cliente)      │
│                 │
│  - FCM mínimo   │ ← Apenas para receber notificações
│  - Supabase SDK │ ← Backend principal
└────────┬────────┘
         │
         │ Salva token FCM
         ▼
┌─────────────────┐
│    Supabase     │
│   (Backend)     │
│                 │
│  - fcm_tokens   │ ← Armazena tokens
│  - Edge Funcs   │ ← Envia notificações via FCM API
└────────┬────────┘
         │
         │ Usa FCM_SERVER_KEY
         ▼
┌─────────────────┐
│  Firebase FCM   │
│   (Serviço)     │
│                 │
│  - Apenas FCM   │ ← Envia push notifications
└─────────────────┘
```

**Backend**: 100% Supabase  
**Cliente**: Supabase + FCM mínimo (apenas para receber notificações)

---

**Nota**: Esta configuração permite que o app receba notificações push mesmo quando está fechado, resolvendo o problema de alertas de medicamentos atrasados não chegarem aos familiares.

