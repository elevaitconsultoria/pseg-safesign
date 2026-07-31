import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return new Response(JSON.stringify({ error: 'Sem autorização' }), { status: 401, headers: corsHeaders });

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const anonKey     = Deno.env.get('SUPABASE_ANON_KEY')!;

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

    const { user_id: userId } = await req.json();
    if (!userId) {
      return new Response(JSON.stringify({ error: 'user_id é obrigatório' }), { status: 400, headers: corsHeaders });
    }
    if (userId === authData.user.id) {
      return new Response(JSON.stringify({ error: 'Você não pode excluir sua própria conta por aqui' }), { status: 400, headers: corsHeaders });
    }

    const adminClient = createClient(supabaseUrl, serviceKey);

    const { data: alvoPerfil, error: alvoError } = await adminClient
      .from('perfis')
      .select('id, tenant_id, role')
      .eq('id', userId)
      .single();
    if (alvoError || !alvoPerfil) {
      return new Response(JSON.stringify({ error: 'Usuário não encontrado' }), { status: 404, headers: corsHeaders });
    }
    if (alvoPerfil.role === 'super_admin') {
      return new Response(JSON.stringify({ error: 'Acesso negado' }), { status: 403, headers: corsHeaders });
    }
    if (callerRole === 'admin' && alvoPerfil.tenant_id !== callerPerfil.tenant_id) {
      return new Response(JSON.stringify({ error: 'Acesso negado' }), { status: 403, headers: corsHeaders });
    }

    // perfis.id -> auth.users(id) ON DELETE CASCADE: apagar o usuário do Auth
    // já remove a linha correspondente em perfis.
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteError) throw deleteError;

    return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message || String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
