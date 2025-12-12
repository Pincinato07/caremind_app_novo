import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'

// Simulação de chaves (Dia 30 você põe as reais aqui)
const ASAAS_API_KEY = Deno.env.get('ASAAS_API_KEY') ?? ''; 

serve(async (req) => {
  // 1. CORS (Para o seu app conseguir chamar a função)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 2. Pega o Usuário que está chamando (Auth automática do Supabase)
    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')
    // Aqui você validaria o JWT com supabase-js se quisesse extrair o ID, 
    // mas vamos confiar no user_id enviado no body por enquanto ou usar o context.

    // 3. Recebe qual plano ele quer
    const { price_id, user_id } = await req.json()

    console.log(`Iniciando checkout para User: ${user_id} | Plano: ${price_id}`)

    // --- AQUI ENTRA A INTEGRAÇÃO COM ASAAS/STRIPE ---
    // Por enquanto, vamos retornar um link FAKE de sucesso para você testar o fluxo no App.
    
    // Quando tiver o CNPJ, você vai fazer um fetch('https://www.asaas.com/api/v3/payments'...)
    
    const fakeCheckoutUrl = "https://caremind.com.br/sucesso_fake?id=" + user_id;
    // ------------------------------------------------

    return new Response(
      JSON.stringify({ url: fakeCheckoutUrl }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
