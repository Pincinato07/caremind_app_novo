import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabaseAdmin } from '../_shared/supabase.ts'
import { sendFCMToMultiple } from '../_shared/firebase.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const now = new Date().toISOString()
    
    const { data: pendingNotifs, error } = await supabaseAdmin
      .from('notificacoes_agendadas')
      .select('*')
      .eq('processado', false)
      .lte('data_agendada', now)
      .limit(100)

    if (error) throw error

    if (!pendingNotifs || pendingNotifs.length === 0) {
      return new Response(
        JSON.stringify({ message: 'Nenhuma notificação pendente', processed: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let processed = 0
    let successful = 0
    let failed = 0

    for (const notif of pendingNotifs) {
      try {
        const { data: fcmTokens } = await supabaseAdmin
          .from('fcm_tokens')
          .select('token')
          .eq('perfil_id', notif.perfil_id)
          .eq('ativo', true)

        let success = false
        let errorMsg = ''

        if (fcmTokens && fcmTokens.length > 0) {
          const tokens = fcmTokens.map(t => t.token)
          const result = await sendFCMToMultiple(tokens, notif.titulo, notif.corpo, {
            tipo: notif.tipo,
            referencia_id: notif.referencia_id || ''
          })
          success = result.sent > 0
          if (!success) errorMsg = result.errors.join('; ')
        } else {
          errorMsg = 'Nenhum token FCM ativo'
        }

        await supabaseAdmin
          .from('notificacoes_agendadas')
          .update({
            processado: true,
            sucesso: success,
            erro: errorMsg || null,
            processado_em: new Date().toISOString()
          })
          .eq('id', notif.id)

        processed++
        if (success) successful++
        else failed++

      } catch (e) {
        await supabaseAdmin
          .from('notificacoes_agendadas')
          .update({
            processado: true,
            sucesso: false,
            erro: e instanceof Error ? e.message : 'Erro desconhecido',
            processado_em: new Date().toISOString()
          })
          .eq('id', notif.id)
        
        processed++
        failed++
      }
    }

    return new Response(
      JSON.stringify({ processed, successful, failed }),
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
