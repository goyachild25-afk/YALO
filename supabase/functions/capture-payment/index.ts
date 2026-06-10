// Supabase Edge Function — capture-payment
// Captura un PaymentIntent ya autorizado (escrow → cobro real).
// Se llama cuando el prestador marca el servicio como "completado".

import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { booking_id, payment_intent_id } = await req.json();

    if (!booking_id || !payment_intent_id) {
      return new Response(
        JSON.stringify({ error: "booking_id y payment_intent_id son requeridos" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Capturar el pago en Stripe (cobra la tarjeta reservada)
    const paymentIntent = await stripe.paymentIntents.capture(payment_intent_id);

    if (paymentIntent.status !== "succeeded") {
      return new Response(
        JSON.stringify({ error: `Estado inesperado de Stripe: ${paymentIntent.status}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Actualizar la reserva en Supabase usando la service role key
    //    (necesita permisos de escritura sin RLS del usuario)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error: dbError } = await supabase
      .from("bookings")
      .update({
        payment_status: "released",
        status: "completed",
        updated_at: new Date().toISOString(),
      })
      .eq("id", booking_id);

    if (dbError) {
      // El pago se capturó en Stripe pero la BD falló — loguear para reconciliación manual
      console.error("Stripe capture OK pero DB update falló:", dbError.message);
      return new Response(
        JSON.stringify({ success: true, warning: "Pago capturado pero DB no actualizada" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, payment_status: "released" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Error en capture-payment:", err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "Error interno" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
