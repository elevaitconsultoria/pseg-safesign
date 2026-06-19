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

    const supabaseUrl  = Deno.env.get('SUPABASE_URL')!;
    const serviceKey   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const anonKey      = Deno.env.get('SUPABASE_ANON_KEY')!;

    // Verificar se o chamador é super_admin
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: perfil } = await callerClient
      .from('perfis')
      .select('role')
      .eq('id', (await callerClient.auth.getUser()).data.user?.id ?? '')
      .single();

    if (perfil?.role !== 'super_admin') {
      return new Response(JSON.stringify({ error: 'Acesso negado' }), { status: 403, headers: corsHeaders });
    }

    const { email, nome_empresa, nome_responsavel } = await req.json();
    if (!email || !nome_empresa) {
      return new Response(JSON.stringify({ error: 'email e nome_empresa são obrigatórios' }), { status: 400, headers: corsHeaders });
    }

    // Convidar usando service_role
    const adminClient = createClient(supabaseUrl, serviceKey);
    const { error } = await adminClient.auth.admin.inviteUserByEmail(email, {
      data: { nome_responsavel, nome_empresa, role: 'admin' },
    });

    if (error) throw error;

    return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message || String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
