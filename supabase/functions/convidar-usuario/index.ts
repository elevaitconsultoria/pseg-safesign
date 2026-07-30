import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

const ROLES_PERMITIDAS = ['admin', 'consultor', 'cliente_viewer'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return new Response(JSON.stringify({ error: 'Sem autorização' }), { status: 401, headers: corsHeaders });

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const anonKey     = Deno.env.get('SUPABASE_ANON_KEY')!;

    // Verificar identidade e role do caller via client autenticado com o JWT dele —
    // nunca confiar em role/tenant_id enviados no body.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: authData, error: userError } = await callerClient.auth.getUser();
    if (userError || !authData?.user) {
      return new Response(JSON.stringify({ error: 'Sessão inválida' }), { status: 401, headers: corsHeaders });
    }

    const { data: callerPerfil, error: perfilError } = await callerClient
      .from('perfis')
      .select('role, tenant_id')
      .eq('id', authData.user.id)
      .single();

    if (perfilError || !callerPerfil) {
      return new Response(JSON.stringify({ error: 'Perfil do solicitante não encontrado' }), { status: 403, headers: corsHeaders });
    }

    const callerRole = callerPerfil.role;
    if (callerRole !== 'admin' && callerRole !== 'super_admin') {
      return new Response(JSON.stringify({ error: 'Acesso negado' }), { status: 403, headers: corsHeaders });
    }

    const body = await req.json();
    const email = (body.email || '').trim();
    const nome = (body.nome || '').trim();
    const role = body.role;
    let tenantId = body.tenant_id;

    if (!email || !nome || !role) {
      return new Response(JSON.stringify({ error: 'email, nome e role são obrigatórios' }), { status: 400, headers: corsHeaders });
    }
    if (!ROLES_PERMITIDAS.includes(role)) {
      return new Response(JSON.stringify({ error: 'role inválida' }), { status: 400, headers: corsHeaders });
    }

    const adminClient = createClient(supabaseUrl, serviceKey);

    if (callerRole === 'admin') {
      // admin de EST só pode convidar para o próprio tenant — ignora qualquer
      // tenant_id enviado no body.
      if (!callerPerfil.tenant_id) {
        return new Response(JSON.stringify({ error: 'Solicitante sem tenant associado' }), { status: 403, headers: corsHeaders });
      }
      tenantId = callerPerfil.tenant_id;
    } else {
      // super_admin deve informar explicitamente o tenant de destino, e ele precisa existir.
      if (!tenantId) {
        return new Response(JSON.stringify({ error: 'tenant_id é obrigatório para super_admin' }), { status: 400, headers: corsHeaders });
      }
      const { data: tenant, error: tenantError } = await adminClient
        .from('tenants')
        .select('id')
        .eq('id', tenantId)
        .single();
      if (tenantError || !tenant) {
        return new Response(JSON.stringify({ error: 'tenant_id inválido' }), { status: 400, headers: corsHeaders });
      }
    }

    const { data: invited, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, {
      data: { nome },
    });
    if (inviteError) throw inviteError;

    // O trigger handle_new_user() já criou a linha default em perfis — corrigir
    // role/tenant_id/nome para os valores pretendidos pelo convite.
    const { error: updateError } = await adminClient
      .from('perfis')
      .update({ nome, role, tenant_id: tenantId })
      .eq('id', invited.user.id);
    if (updateError) throw updateError;

    return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message || String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
