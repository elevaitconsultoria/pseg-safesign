/**
 * PSEG SafeSign — Edge Function: webhook-billing
 *
 * Recebe eventos de pagamento do Stripe e Asaas e atualiza o plano do tenant.
 *
 * Stripe:  POST /functions/v1/webhook-billing?provider=stripe
 * Asaas:   POST /functions/v1/webhook-billing?provider=asaas
 *
 * Variáveis de ambiente:
 *   STRIPE_WEBHOOK_SECRET  — whsec_...  (do painel Stripe → Webhooks)
 *   ASAAS_WEBHOOK_TOKEN    — token configurado no painel Asaas
 *   SUPABASE_URL           — injetado automaticamente
 *   SUPABASE_SERVICE_ROLE_KEY — injetado automaticamente
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { crypto } from 'https://deno.land/std@0.168.0/crypto/mod.ts'

serve(async (req) => {
  const url      = new URL(req.url)
  const provider = url.searchParams.get('provider') || 'stripe'
  const body     = await req.text()

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  try {
    if (provider === 'stripe') {
      return await handleStripe(req, body, supabase)
    }
    if (provider === 'asaas') {
      return await handleAsaas(req, body, supabase)
    }
    return new Response('provider desconhecido', { status: 400 })
  } catch (e) {
    console.error('[webhook-billing]', e)
    return new Response('Erro interno: ' + (e as Error).message, { status: 500 })
  }
})

// ─────────────────────────────────────────────────────────────────
// Stripe
// ─────────────────────────────────────────────────────────────────
async function handleStripe(req: Request, body: string, supabase: any) {
  const sig     = req.headers.get('stripe-signature') || ''
  const secret  = Deno.env.get('STRIPE_WEBHOOK_SECRET') || ''

  // Verificar assinatura Stripe (HMAC-SHA256)
  if (secret && !await verifyStripeSignature(body, sig, secret)) {
    return new Response('Assinatura inválida', { status: 400 })
  }

  const event = JSON.parse(body)
  console.log('[Stripe webhook]', event.type)

  switch (event.type) {

    case 'checkout.session.completed': {
      const session    = event.data.object
      const tenantId   = session.metadata?.tenant_id
      const plano      = session.metadata?.plano
      if (!tenantId || !plano) break

      await supabase.rpc('aplicar_plano_tenant', {
        p_tenant_id:    tenantId,
        p_plano:        plano,
        p_provider:     'stripe',
        p_provider_sub: session.subscription,
      })

      // Registrar pagamento
      await supabase.from('pagamentos').insert({
        tenant_id:           tenantId,
        provider:            'stripe',
        provider_payment_id: session.payment_intent,
        valor_centavos:      session.amount_total,
        moeda:               (session.currency || 'brl').toUpperCase(),
        status:              'paid',
        metodo:              'cartao_credito',
        pago_em:             new Date().toISOString(),
      })
      break
    }

    case 'invoice.payment_succeeded': {
      const invoice    = event.data.object
      const tenantId   = invoice.subscription_details?.metadata?.tenant_id
      const plano      = invoice.subscription_details?.metadata?.plano
      if (!tenantId || !plano) break

      await supabase.rpc('aplicar_plano_tenant', {
        p_tenant_id:    tenantId,
        p_plano:        plano,
        p_provider:     'stripe',
        p_provider_sub: invoice.subscription,
        p_periodo_fim:  new Date(invoice.period_end * 1000).toISOString(),
      })

      await supabase.from('pagamentos').insert({
        tenant_id:           tenantId,
        provider:            'stripe',
        provider_payment_id: invoice.payment_intent,
        valor_centavos:      invoice.amount_paid,
        moeda:               invoice.currency.toUpperCase(),
        status:              'paid',
        metodo:              'cartao_credito',
        pago_em:             new Date().toISOString(),
      })
      break
    }

    case 'customer.subscription.deleted': {
      const sub      = event.data.object
      const tenantId = sub.metadata?.tenant_id
      if (!tenantId) break

      // Downgrade para trial (sem limites limpos — usuário já usou o trial)
      await supabase.from('tenants').update({
        plano:    'trial',
        trial_ate: null,   // trial expirado permanentemente
        updated_at: new Date().toISOString(),
      }).eq('id', tenantId)

      await supabase.from('subscriptions')
        .update({ status: 'canceled', cancelado_em: new Date().toISOString() })
        .eq('provider_sub_id', sub.id)
      break
    }

    case 'invoice.payment_failed': {
      const invoice  = event.data.object
      const tenantId = invoice.subscription_details?.metadata?.tenant_id
      if (!tenantId) break

      await supabase.from('subscriptions')
        .update({ status: 'past_due', updated_at: new Date().toISOString() })
        .eq('tenant_id', tenantId)
        .eq('status', 'active')
      break
    }
  }

  return new Response('ok', { status: 200 })
}

// ─────────────────────────────────────────────────────────────────
// Asaas
// ─────────────────────────────────────────────────────────────────
async function handleAsaas(req: Request, body: string, supabase: any) {
  const token         = req.headers.get('asaas-access-token') || ''
  const expectedToken = Deno.env.get('ASAAS_WEBHOOK_TOKEN') || ''

  if (expectedToken && token !== expectedToken) {
    return new Response('Token inválido', { status: 401 })
  }

  const event = JSON.parse(body)
  console.log('[Asaas webhook]', event.event)

  if (event.event === 'PAYMENT_RECEIVED' || event.event === 'PAYMENT_CONFIRMED') {
    const payment  = event.payment
    const ref      = payment.externalReference || ''  // tenant_id::plano
    const [tenantId, plano] = ref.split('::')

    if (!tenantId || !plano) {
      console.warn('[Asaas] externalReference sem tenant_id::plano:', ref)
      return new Response('ok', { status: 200 })
    }

    await supabase.rpc('aplicar_plano_tenant', {
      p_tenant_id: tenantId,
      p_plano:     plano,
      p_provider:  'asaas',
    })

    await supabase.from('pagamentos')
      .update({
        status:   'paid',
        pago_em:  new Date().toISOString(),
      })
      .eq('provider_payment_id', payment.id)
  }

  return new Response('ok', { status: 200 })
}

// ─── Verificação de assinatura Stripe ──────────────────────────
async function verifyStripeSignature(payload: string, header: string, secret: string): Promise<boolean> {
  try {
    const parts    = Object.fromEntries(header.split(',').map(p => p.split('=')))
    const ts       = parts['t']
    const sig      = parts['v1']
    const signed   = `${ts}.${payload}`
    const key      = await crypto.subtle.importKey(
      'raw', new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
    )
    const mac      = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signed))
    const expected = Array.from(new Uint8Array(mac)).map(b => b.toString(16).padStart(2,'0')).join('')
    return expected === sig
  } catch {
    return false
  }
}
