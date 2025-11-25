# ✅ Checklist: Configuração FCM V1 - O que falta fazer

## ✅ O que já está feito:

1. ✅ Firebase inicializado no `main.dart` com `DefaultFirebaseOptions.currentPlatform`
2. ✅ Edge Function `enviar-push-notification` atualizada para API V1
3. ✅ Edge Function `monitorar-medicamentos` configurada para enviar push notifications
4. ✅ Tabela `fcm_tokens` criada no Supabase
5. ✅ Cliente Flutter configurado para sincronizar tokens com Supabase

## 🔧 O que você precisa fazer:

### 1. Obter Credenciais da Service Account (Firebase Console)

1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Vá em **Project Settings** → **Service Accounts**
3. Clique em **"Gerar nova chave privada"**
4. Baixe o arquivo JSON

### 2. Extrair Informações do JSON

Do arquivo JSON baixado, você precisa de 3 valores:

```json
{
  "project_id": "seu-project-id-aqui",           ← FCM_PROJECT_ID
  "private_key": "-----BEGIN PRIVATE KEY-----\n...",  ← FCM_PRIVATE_KEY
  "client_email": "firebase-adminsdk-xxxxx@..."   ← FCM_CLIENT_EMAIL
}
```

### 3. Configurar no Supabase

Execute estes comandos no terminal (substitua pelos valores reais):

```bash
# 1. Project ID
supabase secrets set FCM_PROJECT_ID=seu-project-id-aqui

# 2. Private Key (IMPORTANTE: incluir as quebras de linha \n)
supabase secrets set FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n"

# 3. Client Email
supabase secrets set FCM_CLIENT_EMAIL=firebase-adminsdk-xxxxx@seu-project.iam.gserviceaccount.com
```

**⚠️ ATENÇÃO**: A `FCM_PRIVATE_KEY` deve incluir:
- As quebras de linha `\n`
- As marcações `-----BEGIN PRIVATE KEY-----` e `-----END PRIVATE KEY-----`
- Toda a chave completa

### 4. Fazer Deploy da Edge Function

```bash
cd supabase/functions/enviar-push-notification
supabase functions deploy enviar-push-notification
```

### 5. Verificar se está funcionando

1. Execute o app Flutter
2. Faça login
3. Verifique os logs - deve aparecer:
   ```
   ✅ Firebase inicializado (apenas para FCM - push notifications)
   ✅ Handler de background FCM configurado
   ✅ Supabase inicializado (backend principal)
   ✅ FCMTokenService inicializado (tokens sincronizados com Supabase)
   ✅ Token FCM obtido: [token]
   ✅ Token salvo no backend
   ```

4. Verifique no Supabase se o token foi salvo:
   ```sql
   SELECT * FROM fcm_tokens;
   ```

### 6. Testar Push Notification

Você pode testar enviando uma notificação manualmente:

```bash
curl -X POST 'https://seu-projeto.supabase.co/functions/v1/enviar-push-notification' \
  -H 'Authorization: Bearer SEU_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "user-id-do-usuario",
    "title": "Teste Caremind",
    "body": "Esta é uma notificação de teste",
    "priority": "high"
  }'
```

## 📝 Resumo da Arquitetura

```
App Flutter
├── Firebase (mínimo - apenas FCM)
│   └── Recebe push notifications
│
└── Supabase (backend principal)
    ├── Armazena tokens FCM
    ├── Edge Function: monitorar-medicamentos
    │   └── Detecta medicamentos atrasados
    │       └── Chama → enviar-push-notification
    │
    └── Edge Function: enviar-push-notification
        └── Usa credenciais FCM V1
            └── Envia via FCM API V1
```

## ❓ Problemas Comuns

### Erro: "FCM_PROJECT_ID não configurada"
- Verifique se executou `supabase secrets set FCM_PROJECT_ID=...`

### Erro: "Invalid JWT"
- Verifique se a `FCM_PRIVATE_KEY` inclui as quebras de linha `\n`
- Verifique se inclui `-----BEGIN PRIVATE KEY-----` e `-----END PRIVATE KEY-----`

### Token não é gerado
- Verifique se os arquivos `google-services.json` (Android) e `GoogleService-Info.plist` (iOS) estão no lugar correto
- Verifique os logs do app para erros

### Notificações não chegam
- Verifique se a Edge Function foi deployada
- Verifique se as credenciais estão corretas no Supabase
- Verifique os logs da Edge Function no Supabase Dashboard

---

**Pronto!** Após seguir estes passos, as push notifications devem funcionar! 🎉

