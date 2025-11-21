# Edge Functions - CareMind

Este diretório contém as Edge Functions do Supabase para monitoramento automático de alertas.

## 📋 Funções Disponíveis

### 1. `monitorar-medicamentos`
**Objetivo:** Detecta medicamentos que deveriam ter sido tomados mas não foram (atrasados).

**Como funciona:**
- Verifica todos os medicamentos com `concluido = false`
- Compara horários da frequência com a hora atual
- Se o horário passou (com tolerância de 15 minutos), cria alerta `medicamento_atrasado`
- Evita duplicar alertas no mesmo dia

**Agendamento recomendado:** A cada hora (ex: `0 * * * *`)

### 2. `monitorar-rotinas`
**Objetivo:** Detecta rotinas que deveriam ter sido concluídas mas não foram.

**Como funciona:**
- Verifica todas as rotinas com `concluida = false`
- Verifica se a rotina deve ser executada hoje (baseado em `dias_semana`)
- Compara horário da rotina com a hora atual
- Se o horário passou (com tolerância de 30 minutos), cria alerta `rotina_nao_concluida`
- Evita duplicar alertas no mesmo dia

**Agendamento recomendado:** A cada hora (ex: `0 * * * *`)

### 3. `reset-status-diario`
**Objetivo:** Reseta o status diário de medicamentos e rotinas para permitir novo ciclo.

**Como funciona:**
- Reseta `concluido = false` em todos os medicamentos
- Reseta `concluida = false` em todas as rotinas
- Permite que o ciclo diário recomece

**Agendamento recomendado:** Diariamente à meia-noite (ex: `0 0 * * *`)

## 🚀 Como Configurar os Cron Jobs no Supabase

### Opção 1: Via Dashboard do Supabase

1. Acesse o Dashboard do Supabase: https://supabase.com/dashboard
2. Vá em **Database** → **Cron Jobs** (ou **Edge Functions** → **Cron Jobs**)
3. Clique em **New Cron Job**

#### Para `monitorar-medicamentos`:
- **Name:** `monitorar-medicamentos`
- **Schedule:** `0 * * * *` (a cada hora)
- **Function:** `monitorar-medicamentos`
- **Method:** `POST`

#### Para `monitorar-rotinas`:
- **Name:** `monitorar-rotinas`
- **Schedule:** `0 * * * *` (a cada hora)
- **Function:** `monitorar-rotinas`
- **Method:** `POST`

#### Para `reset-status-diario`:
- **Name:** `reset-status-diario`
- **Schedule:** `0 0 * * *` (diariamente à meia-noite)
- **Function:** `reset-status-diario`
- **Method:** `POST`

### Opção 2: Via SQL (pg_cron)

Execute no SQL Editor do Supabase:

```sql
-- Agendar monitoramento de medicamentos (a cada hora)
SELECT cron.schedule(
  'monitorar-medicamentos',
  '0 * * * *', -- A cada hora
  $$
  SELECT
    net.http_post(
      url := 'https://SEU_PROJECT_REF.supabase.co/functions/v1/monitorar-medicamentos',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer SEU_SERVICE_ROLE_KEY"}'::jsonb
    ) AS request_id;
  $$
);

-- Agendar monitoramento de rotinas (a cada hora)
SELECT cron.schedule(
  'monitorar-rotinas',
  '0 * * * *', -- A cada hora
  $$
  SELECT
    net.http_post(
      url := 'https://SEU_PROJECT_REF.supabase.co/functions/v1/monitorar-rotinas',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer SEU_SERVICE_ROLE_KEY"}'::jsonb
    ) AS request_id;
  $$
);

-- Agendar reset diário (meia-noite)
SELECT cron.schedule(
  'reset-status-diario',
  '0 0 * * *', -- Diariamente à meia-noite
  $$
  SELECT
    net.http_post(
      url := 'https://SEU_PROJECT_REF.supabase.co/functions/v1/reset-status-diario',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer SEU_SERVICE_ROLE_KEY"}'::jsonb
    ) AS request_id;
  $$
);
```

**⚠️ IMPORTANTE:** Substitua:
- `SEU_PROJECT_REF` pelo seu Project Reference do Supabase
- `SEU_SERVICE_ROLE_KEY` pela sua Service Role Key (encontrada em Settings → API)

## 📦 Como Fazer Deploy das Edge Functions

### Via Supabase CLI:

```bash
# Instalar Supabase CLI (se ainda não tiver)
npm install -g supabase

# Login no Supabase
supabase login

# Linkar ao projeto
supabase link --project-ref SEU_PROJECT_REF

# Deploy de todas as funções
supabase functions deploy monitorar-medicamentos
supabase functions deploy monitorar-rotinas
supabase functions deploy reset-status-diario
```

### Via Dashboard do Supabase:

1. Acesse **Edge Functions** no Dashboard
2. Clique em **New Function**
3. Cole o código de cada função
4. Clique em **Deploy**

## 🔍 Verificar se está Funcionando

### Testar Manualmente:

```bash
# Testar monitorar-medicamentos
curl -X POST https://SEU_PROJECT_REF.supabase.co/functions/v1/monitorar-medicamentos \
  -H "Authorization: Bearer SEU_ANON_KEY" \
  -H "Content-Type: application/json"

# Testar monitorar-rotinas
curl -X POST https://SEU_PROJECT_REF.supabase.co/functions/v1/monitorar-rotinas \
  -H "Authorization: Bearer SEU_ANON_KEY" \
  -H "Content-Type: application/json"

# Testar reset-status-diario
curl -X POST https://SEU_PROJECT_REF.supabase.co/functions/v1/reset-status-diario \
  -H "Authorization: Bearer SEU_ANON_KEY" \
  -H "Content-Type: application/json"
```

### Verificar Logs:

No Dashboard do Supabase:
1. Vá em **Edge Functions**
2. Clique na função desejada
3. Vá na aba **Logs** para ver execuções e erros

## 📊 Estrutura de Dados Esperada

### Tabela `medicamentos`:
- `id` (integer)
- `user_id` (uuid) - ID do perfil
- `nome` (text)
- `frequencia` (jsonb) - Ex: `{"tipo": "diario", "horarios": ["08:00", "20:00"]}`
- `concluido` (boolean)

### Tabela `rotinas`:
- `id` (integer)
- `user_id` (uuid) - ID do perfil
- `nome` (text)
- `horario` (text) - Formato "HH:mm"
- `dias_semana` (integer[]) - Array de dias [0=domingo, 6=sábado]
- `concluida` (boolean)

### Tabela `historico_eventos`:
- `id` (integer)
- `perfil_id` (uuid)
- `tipo_evento` (text) - Ex: "medicamento_atrasado", "rotina_nao_concluida", "estoque_baixo"
- `data_hora` (timestamp)
- `descricao` (text)
- `referencia_id` (text) - ID do medicamento/rotina
- `tipo_referencia` (text) - "medicamento" ou "rotina"

## ⚙️ Configurações de Ambiente

As Edge Functions usam automaticamente as variáveis de ambiente do Supabase:
- `SUPABASE_URL` - URL do projeto
- `SUPABASE_SERVICE_ROLE_KEY` - Service Role Key (com acesso total)

Essas variáveis são configuradas automaticamente pelo Supabase, não é necessário configurar manualmente.

## 🐛 Troubleshooting

### Problema: Cron Jobs não estão executando
- Verifique se o pg_cron extension está habilitado no Supabase
- Verifique os logs das Edge Functions
- Confirme que o schedule está correto (formato cron)

### Problema: Alertas não aparecem
- Verifique se os medicamentos/rotinas têm horários válidos
- Verifique se o campo `concluido`/`concluida` está como `false`
- Verifique os logs das Edge Functions para erros

### Problema: Alertas duplicados
- As funções já têm lógica para evitar duplicatas no mesmo dia
- Se ainda houver duplicatas, verifique a lógica de verificação de alertas existentes

