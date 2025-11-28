-- =================================================================
-- 🔧 CAREMIND - Script de Limpeza e Otimização dos Cron Jobs
-- =================================================================
-- Versão: 2.1
-- Data: 2025
-- 
-- Este script realiza:
-- 1. Criação da tabela notificacoes_app
-- 2. Remoção de jobs redundantes
-- 3. Atualização da função job_verificar_falhas_confirmacao
-- 4. Funções RPC para o app mobile
-- =================================================================

-- =================================================================
-- PASSO 0: Criar tabela de notificações do app (se não existir)
-- =================================================================

CREATE TABLE IF NOT EXISTS notificacoes_app (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    perfil_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    mensagem TEXT NOT NULL,
    tipo TEXT NOT NULL DEFAULT 'info', -- 'info', 'warning', 'error', 'success', 'medicamento', 'rotina', 'compromisso'
    lida BOOLEAN DEFAULT FALSE,
    data_criacao TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_leitura TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}', -- dados adicionais (ex: evento_id, medicamento_id, etc.)
    prioridade INTEGER DEFAULT 0 -- 0=normal, 1=alta, 2=urgente
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_notificacoes_app_perfil_id ON notificacoes_app(perfil_id);
CREATE INDEX IF NOT EXISTS idx_notificacoes_app_lida ON notificacoes_app(lida);
CREATE INDEX IF NOT EXISTS idx_notificacoes_app_data ON notificacoes_app(data_criacao DESC);
CREATE INDEX IF NOT EXISTS idx_notificacoes_app_tipo ON notificacoes_app(tipo);

-- RLS Policies
ALTER TABLE notificacoes_app ENABLE ROW LEVEL SECURITY;

-- Policy: Usuário pode ver suas próprias notificações
DROP POLICY IF EXISTS "Usuarios podem ver suas notificacoes" ON notificacoes_app;
CREATE POLICY "Usuarios podem ver suas notificacoes" ON notificacoes_app
    FOR SELECT USING (auth.uid() = perfil_id);

-- Policy: Usuário pode atualizar suas próprias notificações (marcar como lida)
DROP POLICY IF EXISTS "Usuarios podem atualizar suas notificacoes" ON notificacoes_app;
CREATE POLICY "Usuarios podem atualizar suas notificacoes" ON notificacoes_app
    FOR UPDATE USING (auth.uid() = perfil_id);

-- Policy: Service role pode inserir notificações (para cron jobs e edge functions)
DROP POLICY IF EXISTS "Service pode inserir notificacoes" ON notificacoes_app;
CREATE POLICY "Service pode inserir notificacoes" ON notificacoes_app
    FOR INSERT WITH CHECK (true);

-- =================================================================
-- PASSO 1: REMOVER JOBS REDUNDANTES
-- =================================================================

-- ❌ REMOVER Job 2 (agendamento-diario-caremind)
-- Motivo: Redundante com Job 6 (gerar-eventos-diarios) que roda no mesmo horário
SELECT cron.unschedule(2);

-- ❌ REMOVER Job 9 (monitorar-medicamentos) 
-- Motivo: Vai ser coberto pelo Job 4 (verificar-falhas) que é mais eficiente
SELECT cron.unschedule(9);

-- ❌ REMOVER Job 10 (monitorar-rotinas)
-- Motivo: Vai ser coberto pelo Job 4 (verificar-falhas) que é mais eficiente
SELECT cron.unschedule(10);

-- =================================================================
-- PASSO 2: Atualizar frequência do Job 4 (verificar-falhas)
-- =================================================================
-- Mudar de 5 em 5 minutos para 15 em 15 minutos (mais eficiente)
-- O Job 11 (disparar-lembretes-alexa) já roda a cada 5 min para lembretes de voz

SELECT cron.alter_job(
    job_id := 4,
    schedule := '*/15 * * * *'  -- A cada 15 minutos
);

-- =================================================================
-- PASSO 3: DROPAR função existente antes de recriar
-- =================================================================

DROP FUNCTION IF EXISTS public.job_verificar_falhas_confirmacao();

-- =================================================================
-- PASSO 4: Recriar função job_verificar_falhas_confirmacao
-- =================================================================
-- Esta função agora cobre:
-- - Medicamentos atrasados
-- - Rotinas não concluídas  
-- - Compromissos atrasados
-- - Envia push notifications
-- - Salva notificações na tabela notificacoes_app

CREATE OR REPLACE FUNCTION public.job_verificar_falhas_confirmacao()
RETURNS void AS $$
DECLARE
    v_evento RECORD;
    v_idoso_nome TEXT;
    v_familiar_id UUID;
    v_minutos_atraso INTEGER;
    v_titulo TEXT;
    v_mensagem TEXT;
    v_tipo_alerta TEXT;
    v_supabase_url TEXT := 'https://njxsuqvqaeesxmoajzyb.supabase.co';
BEGIN
    -- =========================================================
    -- PARTE A: Verificar MEDICAMENTOS atrasados
    -- =========================================================
    FOR v_evento IN 
        SELECT 
            m.id,
            m.perfil_id,
            m.nome,
            m.dosagem,
            m.frequencia,
            ad.data_prevista,
            EXTRACT(EPOCH FROM (NOW() - ad.data_prevista)) / 60 AS minutos_atraso
        FROM medicamentos m
        INNER JOIN agenda_diaria ad ON ad.medicamento_id = m.id
        WHERE ad.data_prevista::date = CURRENT_DATE
          AND ad.status = 'pendente'
          AND ad.data_prevista < NOW() - INTERVAL '30 minutes'
          -- Evitar duplicatas: não alertar se já existe alerta hoje para este medicamento
          AND NOT EXISTS (
              SELECT 1 FROM notificacoes_app na 
              WHERE na.perfil_id = m.perfil_id 
              AND na.tipo = 'medicamento'
              AND DATE(na.data_criacao) = CURRENT_DATE
              AND na.mensagem ILIKE '%' || m.nome || '%'
              AND na.titulo ILIKE '%atrasado%'
          )
    LOOP
        v_minutos_atraso := GREATEST(v_evento.minutos_atraso::INTEGER, 30);
        v_titulo := '⚠️ Medicamento Atrasado';
        v_mensagem := v_evento.nome || ' (' || COALESCE(v_evento.dosagem, '') || ') está ' || v_minutos_atraso || ' min atrasado';
        v_tipo_alerta := 'medicamento';
        
        -- Inserir no histórico de eventos (mantém compatibilidade)
        INSERT INTO historico_eventos (perfil_id, tipo_evento, descricao, data_hora)
        VALUES (v_evento.perfil_id, 'medicamento_atrasado', v_mensagem, NOW());
        
        -- ✅ Inserir notificação na tabela notificacoes_app para o idoso/usuário
        INSERT INTO notificacoes_app (perfil_id, titulo, mensagem, tipo, prioridade, metadata)
        VALUES (
            v_evento.perfil_id, 
            v_titulo, 
            v_mensagem, 
            v_tipo_alerta,
            CASE WHEN v_minutos_atraso > 60 THEN 2 ELSE 1 END,
            jsonb_build_object('medicamento_id', v_evento.id, 'minutos_atraso', v_minutos_atraso)
        );
        
        -- Enviar push notification via Edge Function
        PERFORM net.http_post(
            url := v_supabase_url || '/functions/v1/send-push',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('supabase.service_role_key', true)
            ),
            body := jsonb_build_object(
                'userId', v_evento.perfil_id,
                'title', v_titulo,
                'body', v_mensagem,
                'data', jsonb_build_object('type', 'medicamento_atrasado', 'medicamento_id', v_evento.id)
            )
        );
        
        -- Notificar familiar vinculado também
        SELECT vf.id_familiar, p.nome INTO v_familiar_id, v_idoso_nome
        FROM vinculos_familiares vf
        INNER JOIN perfis p ON p.id = v_evento.perfil_id
        WHERE vf.id_idoso = v_evento.perfil_id
        LIMIT 1;
        
        IF v_familiar_id IS NOT NULL THEN
            -- ✅ Inserir notificação para o familiar na tabela notificacoes_app
            INSERT INTO notificacoes_app (perfil_id, titulo, mensagem, tipo, prioridade, metadata)
            VALUES (
                v_familiar_id, 
                v_titulo, 
                COALESCE(v_idoso_nome, 'Idoso') || ': ' || v_mensagem,
                v_tipo_alerta,
                CASE WHEN v_minutos_atraso > 60 THEN 2 ELSE 1 END,
                jsonb_build_object('medicamento_id', v_evento.id, 'idoso_id', v_evento.perfil_id, 'idoso_nome', v_idoso_nome)
            );
            
            PERFORM net.http_post(
                url := v_supabase_url || '/functions/v1/send-push',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || current_setting('supabase.service_role_key', true)
                ),
                body := jsonb_build_object(
                    'userId', v_familiar_id,
                    'title', v_titulo || ' - ' || COALESCE(v_idoso_nome, 'Idoso'),
                    'body', v_mensagem,
                    'data', jsonb_build_object('type', 'medicamento_atrasado', 'idoso_id', v_evento.perfil_id)
                )
            );
        END IF;
    END LOOP;

    -- =========================================================
    -- PARTE B: Verificar ROTINAS não concluídas
    -- =========================================================
    FOR v_evento IN 
        SELECT 
            r.id,
            r.perfil_id,
            r.nome,
            r.horario,
            ad.data_prevista,
            EXTRACT(EPOCH FROM (NOW() - ad.data_prevista)) / 60 AS minutos_atraso
        FROM rotinas r
        INNER JOIN agenda_diaria ad ON ad.rotina_id = r.id
        WHERE ad.data_prevista::date = CURRENT_DATE
          AND ad.status = 'pendente'
          AND ad.data_prevista < NOW() - INTERVAL '30 minutes'
          AND NOT EXISTS (
              SELECT 1 FROM notificacoes_app na 
              WHERE na.perfil_id = r.perfil_id 
              AND na.tipo = 'rotina'
              AND DATE(na.data_criacao) = CURRENT_DATE
              AND na.mensagem ILIKE '%' || r.nome || '%'
              AND na.titulo ILIKE '%conclu%'
          )
    LOOP
        v_minutos_atraso := GREATEST(v_evento.minutos_atraso::INTEGER, 30);
        v_titulo := '⚠️ Rotina Não Concluída';
        v_mensagem := v_evento.nome || ' está ' || v_minutos_atraso || ' min atrasada';
        v_tipo_alerta := 'rotina';
        
        INSERT INTO historico_eventos (perfil_id, tipo_evento, descricao, data_hora)
        VALUES (v_evento.perfil_id, 'rotina_nao_concluida', v_mensagem, NOW());
        
        -- ✅ Inserir notificação na tabela notificacoes_app
        INSERT INTO notificacoes_app (perfil_id, titulo, mensagem, tipo, prioridade, metadata)
        VALUES (
            v_evento.perfil_id, 
            v_titulo, 
            v_mensagem, 
            v_tipo_alerta,
            CASE WHEN v_minutos_atraso > 60 THEN 2 ELSE 1 END,
            jsonb_build_object('rotina_id', v_evento.id, 'minutos_atraso', v_minutos_atraso)
        );
        
        PERFORM net.http_post(
            url := v_supabase_url || '/functions/v1/send-push',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('supabase.service_role_key', true)
            ),
            body := jsonb_build_object(
                'userId', v_evento.perfil_id,
                'title', v_titulo,
                'body', v_mensagem,
                'data', jsonb_build_object('type', 'rotina_nao_concluida', 'rotina_id', v_evento.id)
            )
        );
        
        -- Notificar familiar
        SELECT vf.id_familiar, p.nome INTO v_familiar_id, v_idoso_nome
        FROM vinculos_familiares vf
        INNER JOIN perfis p ON p.id = v_evento.perfil_id
        WHERE vf.id_idoso = v_evento.perfil_id
        LIMIT 1;
        
        IF v_familiar_id IS NOT NULL THEN
            -- ✅ Inserir notificação para o familiar
            INSERT INTO notificacoes_app (perfil_id, titulo, mensagem, tipo, prioridade, metadata)
            VALUES (
                v_familiar_id, 
                v_titulo, 
                COALESCE(v_idoso_nome, 'Idoso') || ': ' || v_mensagem,
                v_tipo_alerta,
                1,
                jsonb_build_object('rotina_id', v_evento.id, 'idoso_id', v_evento.perfil_id)
            );
            
            PERFORM net.http_post(
                url := v_supabase_url || '/functions/v1/send-push',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || current_setting('supabase.service_role_key', true)
                ),
                body := jsonb_build_object(
                    'userId', v_familiar_id,
                    'title', v_titulo || ' - ' || COALESCE(v_idoso_nome, 'Idoso'),
                    'body', v_mensagem,
                    'data', jsonb_build_object('type', 'rotina_nao_concluida', 'idoso_id', v_evento.perfil_id)
                )
            );
        END IF;
    END LOOP;

    -- =========================================================
    -- PARTE C: Verificar COMPROMISSOS atrasados
    -- =========================================================
    FOR v_evento IN 
        SELECT 
            c.id,
            c.perfil_id,
            c.titulo,
            c.data_hora,
            EXTRACT(EPOCH FROM (NOW() - c.data_hora)) / 60 AS minutos_atraso
        FROM compromissos c
        WHERE c.data_hora::date = CURRENT_DATE
          AND c.status = 'pendente'
          AND c.data_hora < NOW() - INTERVAL '30 minutes'
          AND NOT EXISTS (
              SELECT 1 FROM notificacoes_app na 
              WHERE na.perfil_id = c.perfil_id 
              AND na.tipo = 'compromisso'
              AND DATE(na.data_criacao) = CURRENT_DATE
              AND na.mensagem ILIKE '%' || c.titulo || '%'
              AND na.titulo ILIKE '%atrasado%'
          )
    LOOP
        v_minutos_atraso := GREATEST(v_evento.minutos_atraso::INTEGER, 30);
        v_titulo := '⚠️ Compromisso Atrasado';
        v_mensagem := v_evento.titulo || ' está ' || v_minutos_atraso || ' min atrasado';
        v_tipo_alerta := 'compromisso';
        
        INSERT INTO historico_eventos (perfil_id, tipo_evento, descricao, data_hora)
        VALUES (v_evento.perfil_id, 'compromisso_atrasado', v_mensagem, NOW());
        
        -- ✅ Inserir notificação na tabela notificacoes_app
        INSERT INTO notificacoes_app (perfil_id, titulo, mensagem, tipo, prioridade, metadata)
        VALUES (
            v_evento.perfil_id, 
            v_titulo, 
            v_mensagem, 
            v_tipo_alerta,
            CASE WHEN v_minutos_atraso > 60 THEN 2 ELSE 1 END,
            jsonb_build_object('compromisso_id', v_evento.id, 'minutos_atraso', v_minutos_atraso)
        );
        
        PERFORM net.http_post(
            url := v_supabase_url || '/functions/v1/send-push',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('supabase.service_role_key', true)
            ),
            body := jsonb_build_object(
                'userId', v_evento.perfil_id,
                'title', v_titulo,
                'body', v_mensagem,
                'data', jsonb_build_object('type', 'compromisso_atrasado', 'compromisso_id', v_evento.id)
            )
        );
        
        -- Notificar familiar
        SELECT vf.id_familiar, p.nome INTO v_familiar_id, v_idoso_nome
        FROM vinculos_familiares vf
        INNER JOIN perfis p ON p.id = v_evento.perfil_id
        WHERE vf.id_idoso = v_evento.perfil_id
        LIMIT 1;
        
        IF v_familiar_id IS NOT NULL THEN
            -- ✅ Inserir notificação para o familiar
            INSERT INTO notificacoes_app (perfil_id, titulo, mensagem, tipo, prioridade, metadata)
            VALUES (
                v_familiar_id, 
                v_titulo, 
                COALESCE(v_idoso_nome, 'Idoso') || ': ' || v_mensagem,
                v_tipo_alerta,
                1,
                jsonb_build_object('compromisso_id', v_evento.id, 'idoso_id', v_evento.perfil_id)
            );
            
            PERFORM net.http_post(
                url := v_supabase_url || '/functions/v1/send-push',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || current_setting('supabase.service_role_key', true)
                ),
                body := jsonb_build_object(
                    'userId', v_familiar_id,
                    'title', v_titulo || ' - ' || COALESCE(v_idoso_nome, 'Idoso'),
                    'body', v_mensagem,
                    'data', jsonb_build_object('type', 'compromisso_atrasado', 'idoso_id', v_evento.perfil_id)
                )
            );
        END IF;
    END LOOP;

    RAISE NOTICE 'job_verificar_falhas_confirmacao executado às %', NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- PASSO 5: DROPAR funções RPC existentes antes de recriar
-- =================================================================

DROP FUNCTION IF EXISTS marcar_notificacao_lida(UUID);
DROP FUNCTION IF EXISTS marcar_todas_notificacoes_lidas();
DROP FUNCTION IF EXISTS contar_notificacoes_nao_lidas();
DROP FUNCTION IF EXISTS buscar_notificacoes(INTEGER, INTEGER, BOOLEAN);
DROP FUNCTION IF EXISTS limpar_notificacoes_antigas();

-- =================================================================
-- PASSO 6: Criar Funções RPC para o App Mobile
-- =================================================================

-- Marcar uma notificação como lida
CREATE OR REPLACE FUNCTION marcar_notificacao_lida(p_notificacao_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notificacoes_app 
    SET lida = TRUE, data_leitura = NOW()
    WHERE id = p_notificacao_id 
    AND perfil_id = auth.uid();
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Marcar todas as notificações como lidas
CREATE OR REPLACE FUNCTION marcar_todas_notificacoes_lidas()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE notificacoes_app 
    SET lida = TRUE, data_leitura = NOW()
    WHERE perfil_id = auth.uid()
    AND lida = FALSE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Contar notificações não lidas
CREATE OR REPLACE FUNCTION contar_notificacoes_nao_lidas()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM notificacoes_app 
    WHERE perfil_id = auth.uid()
    AND lida = FALSE;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Buscar notificações com paginação
CREATE OR REPLACE FUNCTION buscar_notificacoes(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0,
    p_apenas_nao_lidas BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    id UUID,
    perfil_id UUID,
    titulo TEXT,
    mensagem TEXT,
    tipo TEXT,
    lida BOOLEAN,
    data_criacao TIMESTAMP WITH TIME ZONE,
    data_leitura TIMESTAMP WITH TIME ZONE,
    prioridade INTEGER,
    metadata JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        n.perfil_id,
        n.titulo,
        n.mensagem,
        n.tipo,
        n.lida,
        n.data_criacao,
        n.data_leitura,
        n.prioridade,
        n.metadata
    FROM notificacoes_app n
    WHERE n.perfil_id = auth.uid()
    AND (NOT p_apenas_nao_lidas OR n.lida = FALSE)
    ORDER BY n.data_criacao DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- PASSO 7: Função de Limpeza de Notificações Antigas
-- =================================================================

CREATE OR REPLACE FUNCTION limpar_notificacoes_antigas()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
    v_deleted INTEGER;
BEGIN
    -- Remover notificações lidas com mais de 30 dias
    DELETE FROM notificacoes_app 
    WHERE lida = TRUE 
    AND data_criacao < NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    v_count := v_count + v_deleted;
    
    -- Remover notificações não lidas com mais de 90 dias
    DELETE FROM notificacoes_app 
    WHERE lida = FALSE 
    AND data_criacao < NOW() - INTERVAL '90 days';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    v_count := v_count + v_deleted;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Agendar limpeza diária (se não existir)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'limpar-notificacoes-antigas') THEN
        PERFORM cron.schedule(
            'limpar-notificacoes-antigas',
            '0 2 * * *', -- Diariamente às 02:00
            'SELECT limpar_notificacoes_antigas()'
        );
    END IF;
END $$;

-- =================================================================
-- VERIFICAÇÃO FINAL
-- =================================================================

-- Listar jobs ativos após limpeza
SELECT 
    jobid,
    jobname,
    schedule,
    LEFT(command, 60) as command_preview,
    active
FROM cron.job
WHERE active = true
ORDER BY jobid;

-- =================================================================
-- RESUMO DOS JOBS FINAIS:
-- =================================================================
-- ✅ Job 4  | verificar-falhas           | */15 * * * * | Auditor unificado
-- ✅ Job 6  | gerar-eventos-diarios      | 1 0 * * *    | Gera agenda às 00:01
-- ✅ Job 8  | reset-status-diario        | 0 0 * * *    | Reset às 00:00
-- ✅ Job 11 | disparar-lembretes-alexa   | */5 * * * *  | Coração - Alexa
-- ✅ NEW    | limpar-notificacoes-antigas| 0 2 * * *    | Manutenção às 02:00
-- 
-- ❌ REMOVIDOS:
-- Job 2  | agendamento-diario-caremind | Redundante com Job 6
-- Job 9  | monitorar-medicamentos      | Coberto pelo Job 4
-- Job 10 | monitorar-rotinas           | Coberto pelo Job 4
-- =================================================================

-- =================================================================
-- COMENTÁRIO DA FUNÇÃO PRINCIPAL
-- =================================================================
COMMENT ON FUNCTION job_verificar_falhas_confirmacao() IS 
'Função de auditoria unificada que verifica eventos não confirmados após 30 minutos.
- Verifica medicamentos, rotinas e compromissos atrasados
- Insere notificações na tabela notificacoes_app (para o app mobile)
- Mantém compatibilidade com historico_eventos
- Dispara push notifications via Edge Function send-push
- Notifica tanto o idoso quanto o familiar vinculado
Executada a cada 15 minutos pelo cron job verificar-falhas (Job ID 4).';
