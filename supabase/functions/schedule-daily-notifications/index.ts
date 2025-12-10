import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabaseAdmin } from '../_shared/supabase.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const hoje = new Date()
    const amanha = new Date(hoje)
    amanha.setDate(amanha.getDate() + 1)
    amanha.setHours(0, 0, 0, 0)
    
    const fimAmanha = new Date(amanha)
    fimAmanha.setHours(23, 59, 59, 999)

    const { data: perfis, error: perfisError } = await supabaseAdmin
      .from('perfis')
      .select('id, nome')
      .eq('notificacoes_ativas', true)

    if (perfisError) throw perfisError

    let medicamentosAgendados = 0
    let compromissosAgendados = 0

    for (const perfil of perfis || []) {
      const { data: medicamentos } = await supabaseAdmin
        .from('medicamentos')
        .select('id, nome, horarios')
        .eq('perfil_id', perfil.id)
        .eq('ativo', true)

      for (const med of medicamentos || []) {
        const horarios = med.horarios || []
        for (const horario of horarios) {
          const [hora, minuto] = horario.split(':').map(Number)
          const dataNotif = new Date(amanha)
          dataNotif.setHours(hora, minuto - 5, 0, 0)

          if (dataNotif > hoje) {
            const { error } = await supabaseAdmin
              .from('notificacoes_agendadas')
              .upsert({
                perfil_id: perfil.id,
                tipo: 'medicamento',
                referencia_id: med.id,
                titulo: 'Hora do medicamento',
                corpo: `Lembrete: ${med.nome} às ${horario}`,
                data_agendada: dataNotif.toISOString(),
                processado: false
              }, {
                onConflict: 'perfil_id,tipo,referencia_id,data_agendada'
              })

            if (!error) medicamentosAgendados++
          }
        }
      }

      const { data: compromissos } = await supabaseAdmin
        .from('compromissos')
        .select('id, titulo, data_hora')
        .eq('perfil_id', perfil.id)
        .gte('data_hora', amanha.toISOString())
        .lte('data_hora', fimAmanha.toISOString())

      for (const comp of compromissos || []) {
        const dataComp = new Date(comp.data_hora)
        const dataNotif = new Date(dataComp)
        dataNotif.setMinutes(dataNotif.getMinutes() - 30)

        if (dataNotif > hoje) {
          const { error } = await supabaseAdmin
            .from('notificacoes_agendadas')
            .upsert({
              perfil_id: perfil.id,
              tipo: 'compromisso',
              referencia_id: comp.id,
              titulo: 'Lembrete de compromisso',
              corpo: `${comp.titulo} em 30 minutos`,
              data_agendada: dataNotif.toISOString(),
              processado: false
            }, {
              onConflict: 'perfil_id,tipo,referencia_id,data_agendada'
            })

          if (!error) compromissosAgendados++
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        perfis_processados: perfis?.length || 0,
        medicamentos_agendados: medicamentosAgendados,
        compromissos_agendados: compromissosAgendados
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
