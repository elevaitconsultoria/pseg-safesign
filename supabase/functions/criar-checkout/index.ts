/**
 * PSEG SafeSign — Edge Function: criar-checkout
 *
 * Cria uma sessão de pagamento (Stripe ou Asaas) para upgrade de plano.
 * Chamada pelo front com: POST /functions/v1/criar-checkout
 *
 * Body: { plano: 'starter'|'professional'|'enterprise', provider: 'stripe'|'asaas', metodo?: 'pix'|'boleto'|'cartao' }
 * Retorna: { url?: string, pix?: { qr_code, qr_code_base64, expira_em }, boleto?: { url, linha, expira_em } }
 *
 * Variáveis de ambiente necessárias (Supabase Vault / Secrets):
 *   STRIPE_SECRET_KEY         — sk_live_... ou sk_test_...
 *   STRIPE_PRICE_STARTER      — price_...
 *   STRIPE_PRICE_PROFESSIONAL — price_...
 *   STRIPE_PRICE_ENTERPRISE   — price_...
 *   ASAAS_API_KEY             — $aact_...
 *   ASAAS_BASE_URL            — https://api.asaas.com/v3 (prod) ou https://sandbox.asaas.com/api/v3 (sandbox)
 *   SUPABASE_URL              — injetado automaticamente
 *   SUPABASE_SERVICE_ROLE_KEY — injetado automaticamente
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Preços em centavos BRL
const PRECOS: Record<string, number> = {
  starter:      19700,   // R$ 197,00
  professional: 49700,   // R$ 497,00
  enterprise:   99700,   // R$ 997,00
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    // ── Auth: extrair tenant do JWT ──────────────────────────────
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const jwt = req.headers.get('authorization')?.replace('Bearer ', '')
    if (!jwt) return error(401, 'Não autenticado')

    const { data: { user }, error: authErr } = await supabase.auth.getUser(jwt)
    if (authErr || !user) return error(401, 'Token inválido')

    const { data: perfil } = await supabase
      .from('perfis').select('tenant_id, role').eq('id', user.id).single()
    if (!perfil?.tenant_id) return error(400, 'Tenant não encontrado — complete o onboarding')
    if (perfil.role !== 'admin') return error(403, 'Apenas admins podem alterar o plano')

    const { data: tenant } = await supabase
      .from('tenants').select('*').eq('id', perfil.tenant_id).single()
    if (!tenant) return error(404, 'Tenant não encontrado')

    // ── Payload ──────────────────────────────────────────────────
    const body = await req.json()
    const { plano, provider = 'stripe', metodo = 'cartao' } = body

    if (!['starter', 'professional', 'enterprise'].includes(plano)) {
      return error(400, 'Plano inválido')
    }

    // ── Roteamento por provider ───────────────────────────────────
    if (provider === 'stripe') {
      return await criarCheckoutStripe({ tenant, plano, supabase, jwt })
    }

    if (provider === 'asaas') {
      return await criarCobrancaAsaas({ tenant, plano, metodo, supabase })
    }

    return error(400, 'Provider inválido. Use "stripe" ou "asaas"')

  } catch (e) {
    console.error('[criar-checkout]', e)
    return error(500, 'Erro interno: ' + (e as Error).message)
  }
})

// ─────────────────────────────────────────────────────────────────
// Stripe: criar Checkout Session (redirect para página de pagamento)
// ─────────────────────────────────────────────────────────────────
async function criarCheckoutStripe({ tenant, plano, supabase, jwt }: any) {
  const STRIPE_KEY = Deno.env.get('STRIPE_SECRET_KEY')
  if (!STRIPE_KEY) return error(500, 'STRIPE_SECRET_KEY não configurada')

  const priceEnvKey = `STRIPE_PRICE_${plano.toUpperCase()}`
  const priceId = Deno.env.get(priceEnvKey)
  if (!priceId) return error(500, `${priceEnvKey} não configurada`)

  // Criar ou recuperar customer Stripe
  let customerId = tenant.stripe_customer_id
  if (!customerId) {
    const custRes = await stripePost('/customers', STRIPE_KEY, {
      email: tenant.criado_por_email || '',
      name:  tenant.nome,
      metadata: { tenant_id: tenant.id, plano },
    })
    customerId = custRes.id
    await supabase.from('tenants').update({ stripe_customer_id: customerId }).eq('id', tenant.id)
  }

  // Criar Checkout Session
  const appUrl = Deno.env.get('APP_URL') || 'https://elevaitconsultoria.github.io/pseg-safesign'
  const session = await stripePost('/checkout/sessions', STRIPE_KEY, {
    customer:             customerId,
    mode:                 'subscription',
    line_items:           [{ price: priceId, quantity: 1 }],
    success_url:          `${appUrl}?payment=success&plano=${plano}`,
    cancel_url:           `${appUrl}?payment=canceled`,
    metadata:             { tenant_id: tenant.id, plano },
    subscription_data:    { metadata: { tenant_id: tenant.id, plano } },
    allow_promotion_codes: true,
    locale:               'pt-BR',
  })

  return json({ url: session.url, session_id: session.id })
}

// ─────────────────────────────────────────────────────────────────
// Asaas: criar cobrança PIX / Boleto
// ─────────────────────────────────────────────────────────────────
async function criarCobrancaAsaas({ tenant, plano, metodo, supabase }: any) {
  const ASAAS_KEY     = Deno.env.get('ASAAS_API_KEY')
  const ASAAS_URL     = Deno.env.get('ASAAS_BASE_URL') || 'https://sandbox.asaas.com/api/v3'
  if (!ASAAS_KEY) return error(500, 'ASAAS_API_KEY não configurada')

  const billingType = metodo === 'pix' ? 'PIX' : metodo === 'boleto' ? 'BOLETO' : 'UNDEFINED'
  const valor = (PRECOS[plano] || 0) / 100

  // Criar ou recuperar customer Asaas
  let asaasCustomerId = tenant.asaas_customer_id
  if (!asaasCustomerId) {
    const custRes = await asaasPost(`${ASAAS_URL}/customers`, ASAAS_KEY, {
      name:        tenant.nome,
      externalReference: tenant.id,
    })
    asaasCustomerId = custRes.id
    await supabase.from('tenants').update({ asaas_customer_id: asaasCustomerId }).eq('id', tenant.id)
  }

  // Criar cobrança
  const dueDate = new Date()
  dueDate.setDate(dueDate.getDate() + 3)

  const cobranca = await asaasPost(`${ASAAS_URL}/payments`, ASAAS_KEY, {
    customer:        asaasCustomerId,
    billingType,
    value:           valor,
    dueDate:         dueDate.toISOString().split('T')[0],
    description:     `PSEG SafeSign — Plano ${plano}`,
    externalReference: `${tenant.id}::${plano}`,
  })

  // Buscar QR Code PIX se necessário
  let pix = null
  if (metodo === 'pix') {
    const pixData = await asaasGet(`${ASAAS_URL}/payments/${cobranca.id}/pixQrCode`, ASAAS_KEY)
    pix = {
      qr_code:        pixData.payload,
      qr_code_base64: pixData.encodedImage,
      expira_em:      pixData.expirationDate,
    }
  }

  // Salvar pagamento no banco
  await supabase.from('pagamentos').insert({
    tenant_id:           tenant.id,
    provider:            'asaas',
    provider_payment_id: cobranca.id,
    valor_centavos:      PRECOS[plano],
    metodo:              metodo,
    status:              'pending',
    pix_qr_code:         pix?.qr_code,
    pix_qr_code_base64:  pix?.qr_code_base64,
    pix_expira_em:       pix?.expira_em,
    boleto_url:          cobranca.bankSlipUrl,
    boleto_linha:        cobranca.nossoNumero,
    boleto_expira_em:    cobranca.dueDate,
  })

  return json({
    payment_id:   cobranca.id,
    valor,
    pix,
    boleto: metodo === 'boleto' ? {
      url:      cobranca.bankSlipUrl,
      expira_em: cobranca.dueDate,
    } : null,
  })
}

// ─── Helpers ────────────────────────────────────────────────────
async function stripePost(path: string, key: string, body: Record<string, unknown>) {
  const params = new URLSearchParams()
  flattenObject(body, '', params)
  const res = await fetch(`https://api.stripe.com/v1${path}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${key}`,
      'Content-Type':  'application/x-www-form-urlencoded',
    },
    body: params.toString(),
  })
  const data = await res.json()
  if (!res.ok) throw new Error(`Stripe ${path}: ${data.error?.message}`)
  return data
}

function flattenObject(obj: any, prefix: string, params: URLSearchParams) {
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}[${k}]` : k
    if (v !== null && v !== undefined) {
      if (typeof v === 'object' && !Array.isArray(v)) flattenObject(v, key, params)
      else if (Array.isArray(v)) v.forEach((item, i) => params.set(`${key}[${i}]`, String(item)))
      else params.set(key, String(v))
    }
  }
}

async function asaasPost(url: string, key: string, body: unknown) {
  const res = await fetch(url, {
    method:  'POST',
    headers: { 'access_token': key, 'Content-Type': 'application/json' },
    body:    JSON.stringify(body),
  })
  const data = await res.json()
  if (!res.ok) throw new Error(`Asaas POST ${url}: ${JSON.stringify(data.errors)}`)
  return data
}

async function asaasGet(url: string, key: string) {
  const res = await fetch(url, { headers: { 'access_token': key } })
  const data = await res.json()
  if (!res.ok) throw new Error(`Asaas GET ${url}: ${JSON.stringify(data.errors)}`)
  return data
}

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...CORS, 'Content-Type': 'application/json' } })

const error = (status: number, msg: string) =>
  new Response(JSON.stringify({ error: msg }), { status, headers: { ...CORS, 'Content-Type': 'application/json' } })
