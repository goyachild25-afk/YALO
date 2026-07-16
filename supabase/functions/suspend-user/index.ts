// Revoca (o restaura) el acceso real de un usuario suspendido/reactivado.
//
// El toggle de "Suspender" en el panel Admin solo cambiaba
// profiles.is_active — is_active no se verifica en RLS, así que la sesión
// ya emitida seguía renovándose indefinidamente vía refresh token, sin
// límite real. Esta función usa el mecanismo de baneo nativo de Supabase
// Auth (ban_duration) para que el próximo intento de refrescar el token
// falle en el servidor: el access token ya emitido (~1h por defecto) sigue
// siendo válido hasta que expira por su cuenta, pero no se puede renovar.
//
// Requiere que quien llama sea admin (verificado con su propio JWT antes
// de usar la service-role key).

import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // 1) Validar identidad del que llama con su propio JWT
  const authHeader = req.headers.get('Authorization') ?? '';
  const anon = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: caller, error: callerErr } = await anon.auth.getUser();
  if (callerErr || !caller?.user) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  // 2) Confirmar que quien llama es admin
  const { data: callerProfile } = await admin
    .from('profiles')
    .select('role')
    .eq('id', caller.user.id)
    .maybeSingle();
  if (callerProfile?.role !== 'admin') {
    return new Response(JSON.stringify({ error: 'forbidden' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // 3) Banear/desbanear al usuario objetivo
  let body: { user_id?: string; banned?: boolean };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'invalid_json' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  const { user_id, banned } = body;
  if (!user_id || typeof banned !== 'boolean') {
    return new Response(JSON.stringify({ error: 'user_id y banned son obligatorios' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const { error: banErr } = await admin.auth.admin.updateUserById(user_id, {
    ban_duration: banned ? '876000h' : 'none',
  });
  if (banErr) {
    console.error('suspend-user: updateUserById failed', banErr);
    return new Response(JSON.stringify({ error: 'ban_update_failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
