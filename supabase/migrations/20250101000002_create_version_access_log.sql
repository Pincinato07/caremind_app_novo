-- Tabela de log de acesso a versões
-- Para rastrear quais dispositivos estão usando quais versões

CREATE TABLE IF NOT EXISTS public.app_version_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_id UUID NOT NULL REFERENCES public.app_versions_control(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    app_version TEXT NOT NULL,
    build_number INTEGER NOT NULL,
    os_version TEXT,
    platform TEXT,
    accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Restrições
    CONSTRAINT valid_platform CHECK (platform IN ('all', 'android', 'ios', 'web'))
);

-- Índices para performance e analytics
CREATE INDEX idx_version_access_version_id ON public.app_version_access_log(version_id);
CREATE INDEX idx_version_access_user_id ON public.app_version_access_log(user_id);
CREATE INDEX idx_version_access_device_id ON public.app_version_access_log(device_id);
CREATE INDEX idx_version_access_accessed_at ON public.app_version_access_log(accessed_at DESC);
CREATE INDEX idx_version_access_build_number ON public.app_version_access_log(build_number);

-- Tabela para dispositivos dos usuários
CREATE TABLE IF NOT EXISTS public.user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_model TEXT,
    os_version TEXT,
    platform TEXT,
    app_version TEXT,
    build_number INTEGER,
    last_sync TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Restrições
    CONSTRAINT unique_user_device UNIQUE (user_id, device_id),
    CONSTRAINT valid_platform CHECK (platform IN ('all', 'android', 'ios', 'web'))
);

-- Índices
CREATE INDEX idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX idx_user_devices_last_sync ON public.user_devices(last_sync DESC);

-- Trigger para atualizar last_sync
CREATE OR REPLACE FUNCTION update_last_sync_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_sync = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_devices_last_sync
    BEFORE UPDATE ON public.user_devices
    FOR EACH ROW
    EXECUTE FUNCTION update_last_sync_column();

-- Habilitar RLS
ALTER TABLE public.app_version_access_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

-- Políticas de segurança para app_version_access_log
-- Permitir inserção apenas para usuários autenticados
CREATE POLICY "Allow authenticated insert for version access log"
    ON public.app_version_access_log
    FOR INSERT
    WITH CHECK (auth.jwt() IS NOT NULL);

-- Permitir leitura apenas para usuários autenticados (próprios dados) e admins
CREATE POLICY "Allow read for version access log"
    ON public.app_version_access_log
    FOR SELECT
    USING (
        auth.jwt() IS NOT NULL AND (
            user_id = auth.uid() OR 
            auth.jwt() ->> 'user_role' = 'admin'
        )
    );

-- Políticas de segurança para user_devices
-- Permitir inserção e atualização apenas para o próprio usuário
CREATE POLICY "Allow user manage own devices"
    ON public.user_devices
    FOR ALL
    USING (user_id = auth.uid());

-- Permitir leitura para admins
CREATE POLICY "Allow admin read user devices"
    ON public.user_devices
    FOR SELECT
    USING (auth.jwt() ->> 'user_role' = 'admin');

-- Comentários para documentação
COMMENT ON TABLE public.app_version_access_log IS 'Log de acesso a versões do app. Usado para analytics e debug.';
COMMENT ON TABLE public.user_devices IS 'Dispositivos dos usuários. Usado para rastrear versões por dispositivo.';
COMMENT ON COLUMN public.app_version_access_log.device_id IS 'ID único do dispositivo';
COMMENT ON COLUMN public.user_devices.device_id IS 'ID único do dispositivo';

-- Função para limpar logs antigos (executar periodicamente)
CREATE OR REPLACE FUNCTION cleanup_old_version_logs(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.app_version_access_log 
    WHERE accessed_at < NOW() - (days_to_keep || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Função para analytics: versões em uso
CREATE OR REPLACE VIEW public.analytics_version_usage AS
SELECT 
    v.version_name,
    v.build_number,
    v.is_mandatory,
    COUNT(DISTINCT l.device_id) as device_count,
    COUNT(DISTINCT l.user_id) as user_count,
    MAX(l.accessed_at) as last_access,
    MIN(l.accessed_at) as first_access
FROM public.app_versions_control v
LEFT JOIN public.app_version_access_log l ON v.id = l.version_id
WHERE l.accessed_at > NOW() - INTERVAL '30 days'
GROUP BY v.id, v.version_name, v.build_number, v.is_mandatory
ORDER BY v.build_number DESC;

COMMENT ON VIEW public.analytics_version_usage IS 'Analytics de uso de versões (últimos 30 dias)';
