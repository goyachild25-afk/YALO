// Exporta TODOS los datos del usuario autenticado en un JSON. Cumple con el
// derecho de acceso y portabilidad (Ley 172-13 art. 15 / GDPR art. 20).
//
// El request DEBE incluir el JWT del usuario (verify_jwt=true). No hay bypass
// ni service-role aquí: si el JWT no valida, no devolvemos nada.

import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const anon = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: user, error: userErr } = await anon.auth.getUser();
  if (userErr || !user?.user) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const uid = user.user.id;

  // provider_profiles tiene su propio id (distinto de auth.uid()) y es lo
  // que provider_services.provider_id y bookings.provider_id referencian
  // como prestador. Antes se usaba uid directo contra esas columnas, así
  // que a todo prestador le exportaba provider_services vacío y le
  // faltaban sus reservas como prestador, sin ningún error visible.
  const { data: providerProfileRow } = await anon
    .from('provider_profiles')
    .select('*')
    .eq('user_id', uid)
    .maybeSingle();
  const providerProfileId = providerProfileRow?.id as string | undefined;

  const bookingsFilter = providerProfileId
    ? `client_id.eq.${uid},provider_id.eq.${providerProfileId}`
    : `client_id.eq.${uid}`;

  // Cargar todo lo del usuario en paralelo, en su propio contexto (respeta RLS)
  const [profile, providerServices, bookings, notifications, chatMessages, reviewsAsClient, disputesReported, verifRequests] = await Promise.all([
    anon.from('profiles').select('*').eq('id', uid).maybeSingle(),
    providerProfileId
      ? anon.from('provider_services').select('*').eq('provider_id', providerProfileId)
      : Promise.resolve({ data: [] as unknown[] }),
    anon.from('bookings').select('*').or(bookingsFilter),
    anon.from('notifications').select('*').eq('user_id', uid),
    anon.from('chat_messages').select('*').eq('sender_id', uid),
    anon.from('reviews').select('*').eq('client_id', uid),
    anon.from('disputes').select('*').eq('reporter_id', uid),
    anon.from('verification_requests').select('*').eq('user_id', uid),
  ]);

  const payload = {
    export: {
      at: new Date().toISOString(),
      user_id: uid,
      email: user.user.email,
      note: 'Estos son todos los datos personales que YALO tiene sobre ti conforme a la Ley 172-13. Los archivos multimedia (avatar, fotos de servicios) tienen URL en cada registro. Para descargarlos, sigue la URL de cada archivo.',
    },
    profile: profile.data,
    provider_profile: providerProfileRow,
    provider_services: providerServices.data,
    bookings: bookings.data,
    notifications: notifications.data,
    chat_messages_sent: chatMessages.data,
    reviews_written: reviewsAsClient.data,
    disputes_reported: disputesReported.data,
    verification_requests: verifRequests.data,
  };

  return new Response(JSON.stringify(payload, null, 2), {
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'Content-Disposition': `attachment; filename="yalo-mis-datos-${uid.substring(0, 8)}.json"`,
    },
  });
});
