import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabaseAdmin } from '../_shared/supabase.ts'
import { sendFCMNotification, sendFCMToMultiple } from '../_shared/firebase.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { perfil_id, title, body, data } = await req.json()

    if (!perfil_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'perfil_id, title e body são obrigatórios' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: fcmTokens, error } = await supabaseAdmin
      .from('fcm_tokens')
      .select('token')
      .eq('perfil_id', perfil_id)
      .eq('ativo', true)

    if (error) throw error

    if (!fcmTokens || fcmTokens.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'Nenhum token FCM encontrado' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const tokens = fcmTokens.map(t => t.token)
    const result = await sendFCMToMultiple(tokens, title, body, data)

    await supabaseAdmin.from('historico_notificacoes').insert({
      perfil_id,
      titulo: title,
      corpo: body,
      tipo: 'push',
      sucesso: result.sent > 0,
      tokens_enviados: tokens.length,
      tokens_sucesso: result.sent
    })

    return new Response(
      JSON.stringify({ success: result.sent > 0, sent: result.sent, failed: result.failed }),
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
