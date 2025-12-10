import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabaseAdmin } from '../_shared/supabase.ts'
import { sendFCMNotification, sendFCMToMultiple } from '../_shared/firebase.ts'

interface NotificationRequest {
  perfil_id?: string
  perfil_ids?: string[]
  token?: string
  tokens?: string[]
  titulo: string
  corpo: string
  tipo?: string
  data?: Record<string, string>
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body: NotificationRequest = await req.json()
    const { perfil_id, perfil_ids, token, tokens, titulo, corpo, tipo = 'geral', data } = body

    if (!titulo || !corpo) {
      return new Response(
        JSON.stringify({ error: 'titulo e corpo são obrigatórios' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let targetTokens: string[] = []

    if (token) {
      targetTokens = [token]
    } else if (tokens && tokens.length > 0) {
      targetTokens = tokens
    } else if (perfil_id) {
      const { data: fcmData, error } = await supabaseAdmin
        .from('fcm_tokens')
        .select('token')
        .eq('perfil_id', perfil_id)
        .eq('ativo', true)

      if (error) throw error
      targetTokens = fcmData?.map(t => t.token) || []
    } else if (perfil_ids && perfil_ids.length > 0) {
      const { data: fcmData, error } = await supabaseAdmin
        .from('fcm_tokens')
        .select('token')
        .in('perfil_id', perfil_ids)
        .eq('ativo', true)

      if (error) throw error
      targetTokens = fcmData?.map(t => t.token) || []
    }

    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Nenhum token FCM encontrado',
          sent: 0,
          failed: 0
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const result = await sendFCMToMultiple(targetTokens, titulo, corpo, data)

    if (perfil_id || (perfil_ids && perfil_ids.length > 0)) {
      const perfilIdForLog = perfil_id || perfil_ids![0]
      await supabaseAdmin.from('historico_notificacoes').insert({
        perfil_id: perfilIdForLog,
        titulo,
        corpo,
        tipo,
        sucesso: result.sent > 0,
        tokens_enviados: targetTokens.length,
        tokens_sucesso: result.sent
      })
    }

    if (result.failed > 0) {
      const failedTokens = result.errors
        .map(e => {
          const match = e.match(/Token (\d+):/)
          return match ? targetTokens[parseInt(match[1])] : null
        })
        .filter(Boolean)

      if (failedTokens.length > 0) {
        await supabaseAdmin
          .from('fcm_tokens')
          .update({ ativo: false })
          .in('token', failedTokens)
      }
    }

    return new Response(
      JSON.stringify({
        success: result.sent > 0,
        sent: result.sent,
        failed: result.failed,
        total: targetTokens.length,
        errors: result.errors.length > 0 ? result.errors : undefined
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : 'Erro desconhecido',
        success: false
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
