// Supabase Edge Function — create-payment-intent
// Se ejecuta en el servidor de Supabase (Deno runtime)
// Crea un PaymentIntent en Stripe de forma segura

import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

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
  // Manejar preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { amount, currency, description, booking_id, metadata } =
      await req.json();

    // Validaciones básicas
    if (!amount || amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Monto inválido" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Modelo de comisión 5% + 5%:
    //   'amount' recibido = clientTotal = basePrice × 1.05 (ya incluye la Garantía del cliente)
    //   basePrice = amount / 1.05
    //   Membresía de Visibilidad del prestador = basePrice × 0.05
    //   Garantía ServiciosYa del cliente = basePrice × 0.05
    //   applicationFee (metadato) = ambas comisiones = basePrice × 0.10
    const clientFeeFactor = 1.05;
    const basePrice = amount / clientFeeFactor;
    const applicationFee = Math.round(basePrice * 0.10); // 5% clientFee + 5% providerFee

    // Crear PaymentIntent con captura manual (escrow):
    // La tarjeta queda AUTORIZADA (reservada) pero NO cobrada.
    // El cobro real ocurre cuando el prestador marca el servicio como completado
    // y el servidor llama a stripe.paymentIntents.capture().
    const paymentIntent = await stripe.paymentIntents.create({
      amount,                 // En centavos (ej: 250000 = RD$2,500)
      currency,               // 'dop' para pesos dominicanos
      description,
      capture_method: "manual", // ← ESCROW: no cobra hasta capture()
      automatic_payment_methods: { enabled: true },
      metadata: {
        booking_id,
        platform_fee: applicationFee.toString(),
        ...metadata,
      },
    });

    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
        platform_fee: applicationFee,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("Error creating payment intent:", err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "Error interno" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
