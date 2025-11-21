// Edge Function: Monitorar Rotinas Não Concluídas
// Roda via Cron Job (agendado no Supabase Dashboard)
// Detecta rotinas que deveriam ter sido concluídas mas não foram

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface Rotina {
  id: number;
  user_id: string;
  nome: string;
  horario: string; // Formato "HH:mm"
  dias_semana?: number[]; // [0=domingo, 1=segunda, ..., 6=sábado]
  concluida: boolean;
  created_at: string;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Pega a hora atual, mas força o fuso de São Paulo
    const now = new Date();
    
    // Formata para string no horário do Brasil (ex: "14:30")
    // Isso garante que independente do servidor ser UTC, a string será BRT
    const horaBrasil = now.toLocaleTimeString('pt-BR', {
      timeZone: 'America/Sao_Paulo',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    });

    console.log(`🕒 Hora no Servidor (UTC): ${now.toISOString()}`);
    console.log(`🇧🇷 Hora no Brasil (Comparação): ${horaBrasil}`);

    // Extrair hora e minuto do Brasil para comparação numérica
    const [horaBrasilNum, minutoBrasilNum] = horaBrasil.split(':').map(Number);
    const minutosTotaisBrasil = horaBrasilNum * 60 + minutoBrasilNum;

    // Obter dia da semana no fuso de Brasília
    const diaSemanaAtual = new Date(now.toLocaleString('en-US', { timeZone: 'America/Sao_Paulo' })).getDay(); // 0 = domingo, 6 = sábado

    // Criar cliente Supabase
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // Data de hoje no fuso de Brasília para comparações de data
    // Usar Intl.DateTimeFormat para obter componentes da data no fuso correto
    const formatterData = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/Sao_Paulo',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    const partesData = formatterData.formatToParts(now);
    const anoBrasil = parseInt(partesData.find(p => p.type === 'year')?.value || '0');
    const mesBrasil = parseInt(partesData.find(p => p.type === 'month')?.value || '0') - 1; // Mês é 0-indexed
    const diaBrasil = parseInt(partesData.find(p => p.type === 'day')?.value || '0');
    const hojeBrasil = new Date(anoBrasil, mesBrasil, diaBrasil);
    
    // Obter offset do fuso de Brasília (considera horário de verão automaticamente)
    // Usar uma abordagem simples: detectar se estamos em horário de verão
    // Horário de verão no Brasil geralmente é de outubro a fevereiro (mas pode variar)
    // Para simplificar, vamos detectar o offset real comparando UTC com horário de Brasília
    const utcHour = now.getUTCHours();
    const brasilHour = parseInt(horaBrasil.split(':')[0]);
    // Calcular diferença (pode ser -2 ou -3 horas)
    let offsetHours = brasilHour - utcHour;
    if (offsetHours > 12) offsetHours -= 24; // Ajustar se passar da meia-noite
    if (offsetHours < -12) offsetHours += 24;
    const offsetStr = offsetHours === -2 ? '-02:00' : '-03:00'; // BRST ou BRT

    // Buscar todas as rotinas ativas (não concluídas)
    const { data: rotinas, error: rotinasError } = await supabaseClient
      .from("rotinas")
      .select("*")
      .eq("concluida", false);

    if (rotinasError) {
      throw rotinasError;
    }

    if (!rotinas || rotinas.length === 0) {
      return new Response(
        JSON.stringify({ message: "Nenhuma rotina pendente encontrada" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    const alertasGerados = [];

    for (const rotina of rotinas as Rotina[]) {
      try {
        // Verificar se a rotina deve ser executada hoje
        if (rotina.dias_semana && Array.isArray(rotina.dias_semana)) {
          if (!rotina.dias_semana.includes(diaSemanaAtual)) {
            continue; // Rotina não deve ser executada hoje
          }
        }

        // Parsear horário da rotina
        if (!rotina.horario) {
          continue;
        }

        const [hora, minuto] = rotina.horario.split(":").map(Number);
        if (isNaN(hora) || isNaN(minuto)) {
          continue;
        }

        // Calcular minutos totais do horário da rotina
        const minutosTotaisRotina = hora * 60 + minuto;
        
        // Tolerância de 30 minutos
        const toleranciaMinutos = 30;
        const minutosTotaisComTolerancia = minutosTotaisRotina + toleranciaMinutos;

        // Comparar: se a hora do Brasil já passou do horário da rotina + tolerância
        if (minutosTotaisBrasil > minutosTotaisComTolerancia) {
          // Criar data/hora para o alerta (usando fuso de Brasília)
          // Usar a data de hoje no Brasil e criar data com horário da rotina
          const ano = anoBrasil;
          const mes = String(mesBrasil + 1).padStart(2, '0');
          const dia = String(diaBrasil).padStart(2, '0');
          
          // Criar data ISO no fuso de Brasília (usar offset detectado automaticamente)
          const dataHoraBrasilStr = `${ano}-${mes}-${dia}T${rotina.horario}:00${offsetStr}`;
          const horarioRotina = new Date(dataHoraBrasilStr);
          
          // Verificar se já existe um alerta de rotina não concluída hoje
          // Usar data de hoje no fuso de Brasília (início e fim do dia)
          const dataInicio = new Date(`${ano}-${mes}-${dia}T00:00:00${offsetStr}`);
          const dataFim = new Date(`${ano}-${mes}-${dia}T23:59:59${offsetStr}`);

          const { data: alertaExistente } = await supabaseClient
            .from("historico_eventos")
            .select("id")
            .eq("perfil_id", rotina.user_id)
            .eq("tipo_evento", "rotina_nao_concluida")
            .eq("referencia_id", rotina.id.toString())
            .eq("tipo_referencia", "rotina")
            .gte("data_hora", dataInicio.toISOString())
            .lte("data_hora", dataFim.toISOString())
            .maybeSingle();

          // Se não existe alerta, criar um
          if (!alertaExistente) {
            const { error: insertError } = await supabaseClient
              .from("historico_eventos")
              .insert({
                perfil_id: rotina.user_id,
                tipo_evento: "rotina_nao_concluida",
                data_hora: horarioRotina.toISOString(),
                descricao: `Rotina "${rotina.nome}" não foi concluída no horário ${rotina.horario}`,
                referencia_id: rotina.id.toString(),
                tipo_referencia: "rotina",
              });

            if (!insertError) {
              alertasGerados.push({
                rotina_id: rotina.id,
                rotina_nome: rotina.nome,
                horario: rotina.horario,
                user_id: rotina.user_id,
              });
            }
          }
        }
      } catch (error) {
        console.error(`Erro ao processar rotina ${rotina.id}:`, error);
        // Continua processando outras rotinas
      }
    }

    return new Response(
      JSON.stringify({
        message: "Monitoramento de rotinas concluído",
        alertas_gerados: alertasGerados.length,
        detalhes: alertasGerados,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Erro no monitoramento de rotinas:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

