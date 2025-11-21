// Edge Function: Monitorar Medicamentos Atrasados
// Roda via Cron Job (agendado no Supabase Dashboard)
// Detecta medicamentos que deveriam ter sido tomados mas não foram

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface Medicamento {
  id: number;
  user_id: string;
  nome: string;
  frequencia: any;
  concluido: boolean;
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

    // Buscar todos os medicamentos ativos (não concluídos)
    const { data: medicamentos, error: medicamentosError } = await supabaseClient
      .from("medicamentos")
      .select("*")
      .eq("concluido", false);

    if (medicamentosError) {
      throw medicamentosError;
    }

    if (!medicamentos || medicamentos.length === 0) {
      return new Response(
        JSON.stringify({ message: "Nenhum medicamento pendente encontrado" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    const alertasGerados = [];

    for (const medicamento of medicamentos as Medicamento[]) {
      try {
        // Extrair horários da frequência
        const horarios = extrairHorarios(medicamento.frequencia);

        if (horarios.length === 0) {
          continue;
        }

        // Verificar cada horário
        for (const horario of horarios) {
          const [hora, minuto] = horario.split(":").map(Number);
          
          // Calcular minutos totais do horário do medicamento
          const minutosTotaisMedicamento = hora * 60 + minuto;
          
          // Tolerância de 15 minutos
          const toleranciaMinutos = 15;
          const minutosTotaisComTolerancia = minutosTotaisMedicamento + toleranciaMinutos;

          // Comparar: se a hora do Brasil já passou do horário do medicamento + tolerância
          if (minutosTotaisBrasil > minutosTotaisComTolerancia) {
            // Criar data/hora para o alerta (usando fuso de Brasília)
            // Usar a data de hoje no Brasil e criar data com horário do medicamento
            const ano = anoBrasil;
            const mes = String(mesBrasil + 1).padStart(2, '0');
            const dia = String(diaBrasil).padStart(2, '0');
            const horarioFormatado = `${hora.toString().padStart(2, '0')}:${minuto.toString().padStart(2, '0')}`;
            
            // Criar data ISO no fuso de Brasília (usar offset detectado automaticamente)
            const offsetStr = offsetNum === -2 ? '-02:00' : '-03:00';
            const dataHoraBrasilStr = `${ano}-${mes}-${dia}T${horarioFormatado}:00${offsetStr}`;
            const horarioMedicamento = new Date(dataHoraBrasilStr);
            
            // Verificar se já existe um alerta de atraso hoje para este medicamento neste horário
            // Usar data de hoje no fuso de Brasília (início e fim do dia)
            const dataInicio = new Date(`${ano}-${mes}-${dia}T00:00:00${offsetStr}`);
            const dataFim = new Date(`${ano}-${mes}-${dia}T23:59:59${offsetStr}`);

            const { data: alertaExistente } = await supabaseClient
              .from("historico_eventos")
              .select("id")
              .eq("perfil_id", medicamento.user_id)
              .eq("tipo_evento", "medicamento_atrasado")
              .eq("referencia_id", medicamento.id.toString())
              .eq("tipo_referencia", "medicamento")
              .gte("data_hora", dataInicio.toISOString())
              .lte("data_hora", dataFim.toISOString())
              .maybeSingle();

            // Se não existe alerta, criar um
            if (!alertaExistente) {
              const { error: insertError } = await supabaseClient
                .from("historico_eventos")
                .insert({
                  perfil_id: medicamento.user_id,
                  tipo_evento: "medicamento_atrasado",
                  data_hora: horarioMedicamento.toISOString(),
                  descricao: `Medicamento "${medicamento.nome}" não foi tomado no horário ${horario}`,
                  referencia_id: medicamento.id.toString(),
                  tipo_referencia: "medicamento",
                });

              if (!insertError) {
                alertasGerados.push({
                  medicamento_id: medicamento.id,
                  medicamento_nome: medicamento.nome,
                  horario: horario,
                  user_id: medicamento.user_id,
                });
              }
            }
          }
        }
      } catch (error) {
        console.error(
          `Erro ao processar medicamento ${medicamento.id}:`,
          error
        );
        // Continua processando outros medicamentos
      }
    }

    return new Response(
      JSON.stringify({
        message: "Monitoramento concluído",
        alertas_gerados: alertasGerados.length,
        detalhes: alertasGerados,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Erro no monitoramento:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

// Função auxiliar para extrair horários da frequência
function extrairHorarios(frequencia: any): string[] {
  const horarios: string[] = [];

  if (!frequencia || typeof frequencia !== "object") {
    return horarios;
  }

  // Caso 1: Horários explícitos
  if (frequencia.horarios && Array.isArray(frequencia.horarios)) {
    return frequencia.horarios.map((h: any) => {
      if (typeof h === "string") {
        return h;
      }
      return String(h);
    });
  }

  // Caso 2: Frequência diária com vezes_por_dia
  if (frequencia.tipo === "diario" && frequencia.vezes_por_dia) {
    const vezesPorDia = Number(frequencia.vezes_por_dia) || 1;
    const horariosPadrao = ["08:00", "14:00", "20:00"];
    return horariosPadrao.slice(0, vezesPorDia);
  }

  return horarios;
}

