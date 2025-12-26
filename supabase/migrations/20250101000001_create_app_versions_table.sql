-- Tabela para gerenciamento de versões do aplicativo CareMind
-- Esta tabela controla quais versões estão disponíveis e se são obrigatórias

CREATE TABLE IF NOT EXISTS public.app_versions_control (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_name TEXT NOT NULL,
    build_number INTEGER NOT NULL,
    download_url TEXT NOT NULL,
    is_mandatory BOOLEAN DEFAULT false,
    changelog TEXT,
    platform TEXT DEFAULT 'all', -- 'all', 'android', 'ios'
    min_os_version TEXT, -- Ex: 'Android 8.0', 'iOS 13.0'
    release_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Restrições
    CONSTRAINT unique_build_number UNIQUE (build_number),
    CONSTRAINT valid_platform CHECK (platform IN ('all', 'android', 'ios')),
    CONSTRAINT positive_build_number CHECK (build_number > 0)
);

-- Índices para performance
CREATE INDEX idx_app_versions_control_build_number ON public.app_versions_control(build_number DESC);
CREATE INDEX idx_app_versions_control_mandatory ON public.app_versions_control(is_mandatory);
CREATE INDEX idx_app_versions_control_platform ON public.app_versions_control(platform);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_app_versions_control_updated_at
    BEFORE UPDATE ON public.app_versions_control
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Habilitar RLS (Row Level Security)
ALTER TABLE public.app_versions_control ENABLE ROW LEVEL SECURITY;

-- Políticas de segurança
-- Permitir leitura pública (para qualquer usuário autenticado ou não)
CREATE POLICY "Allow public read for app versions control"
    ON public.app_versions_control
    FOR SELECT
    USING (true);

-- Permitir inserção apenas para usuários autenticados com role de admin
CREATE POLICY "Allow admin insert for app versions control"
    ON public.app_versions_control
    FOR INSERT
    WITH CHECK (
        auth.jwt() ->> 'user_role' = 'admin'
    );

-- Permitir atualização apenas para usuários autenticados com role de admin
CREATE POLICY "Allow admin update for app versions control"
    ON public.app_versions_control
    FOR UPDATE
    USING (
        auth.jwt() ->> 'user_role' = 'admin'
    );

-- Permitir deleção apenas para usuários autenticados com role de admin
CREATE POLICY "Allow admin delete for app versions control"
    ON public.app_versions_control
    FOR DELETE
    USING (
        auth.jwt() ->> 'user_role' = 'admin'
    );

-- Comentários para documentação
COMMENT ON TABLE public.app_versions_control IS 'Tabela de controle de versões do aplicativo CareMind. Gerencia atualizações obrigatórias e opcionais.';
COMMENT ON COLUMN public.app_versions_control.version_name IS 'Nome da versão (ex: 1.2.0)';
COMMENT ON COLUMN public.app_versions_control.build_number IS 'Número de build (deve ser incrementado a cada versão)';
COMMENT ON COLUMN public.app_versions_control.download_url IS 'URL para download da versão (Play Store/App Store)';
COMMENT ON COLUMN public.app_versions_control.is_mandatory IS 'Se a atualização é obrigatória (bloqueia o app)';
COMMENT ON COLUMN public.app_versions_control.changelog IS 'Descrição das mudanças nesta versão';
COMMENT ON COLUMN public.app_versions_control.platform IS 'Plataforma alvo: all, android, ou ios';
COMMENT ON COLUMN public.app_versions_control.min_os_version IS 'Versão mínima do sistema operacional requerida';
COMMENT ON COLUMN public.app_versions_control.release_date IS 'Data de lançamento da versão';

-- Inserir versão inicial (exemplo)
INSERT INTO public.app_versions_control (
    version_name,
    build_number,
    download_url,
    is_mandatory,
    changelog,
    platform
) VALUES (
    '1.0.0',
    1,
    'https://play.google.com/store/apps/details?id=com.caremind.app',
    false,
    'Versão inicial do aplicativo',
    'all'
);
