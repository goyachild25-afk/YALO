// ─────────────────────────────────────────────────────────────────────────────
// Edge Function: send-booking-email
// Envía email de confirmación cuando se crea una reserva.
//
// DEPLOY:
//   supabase functions deploy send-booking-email --no-verify-jwt
//
// VARIABLES DE ENTORNO requeridas en Supabase Dashboard > Settings > Edge Functions:
//   RESEND_API_KEY  → Obtener gratis en resend.com (100 emails/día free)
//   FROM_EMAIL      → El email verificado en Resend (ej: noreply@serviciosya.app)
//   SUPABASE_URL    → Auto-inyectado por Supabase
//   SUPABASE_SERVICE_ROLE_KEY → Auto-inyectado por Supabase
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") ?? "noreply@serviciosya.app";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const body = await req.json();
    const { bookingId, clientId, providerName, serviceName, scheduledDate, address, price } = body;

    // Obtener email del cliente desde profiles
    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, email")
      .eq("id", clientId)
      .maybeSingle();

    if (!profile?.email) {
      return new Response(JSON.stringify({ error: "Client email not found" }), { status: 404 });
    }

    // Formatear fecha
    const date = new Date(scheduledDate);
    const formattedDate = date.toLocaleDateString("es-DO", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    const priceText = price
      ? `<p><strong>Precio acordado:</strong> RD$${price.toLocaleString("es-DO")}</p>`
      : `<p><strong>Precio:</strong> Por cotización (acordar con el prestador)</p>`;

    const shortId = bookingId.replace(/-/g, "").substring(0, 8).toUpperCase();

    const html = `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f9fafb; margin: 0; padding: 20px;">
  <div style="max-width: 520px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08);">

    <!-- Header -->
    <div style="background: linear-gradient(135deg, #0D9488, #0F766E); padding: 32px 28px; text-align: center;">
      <h1 style="color: white; margin: 0; font-size: 22px; font-weight: 700;">ServiciosYa</h1>
      <p style="color: rgba(255,255,255,0.8); margin: 6px 0 0; font-size: 14px;">Plataforma de servicios del hogar</p>
    </div>

    <!-- Body -->
    <div style="padding: 28px;">
      <div style="text-align: center; margin-bottom: 24px;">
        <div style="width: 64px; height: 64px; background: #D1FAE5; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font-size: 32px;">✅</div>
        <h2 style="color: #111827; margin: 12px 0 4px; font-size: 20px;">¡Solicitud enviada!</h2>
        <p style="color: #6B7280; margin: 0; font-size: 14px;">Tu prestador revisará y confirmará en breve</p>
      </div>

      <div style="background: #F9FAFB; border: 1px solid #E5E7EB; border-radius: 12px; padding: 20px; margin-bottom: 20px;">
        <p style="color: #6B7280; font-size: 11px; font-weight: 600; text-transform: uppercase; margin: 0 0 12px;">Detalles de la reserva</p>
        <p><strong>N° de reserva:</strong> #SY-${shortId}</p>
        <p><strong>Servicio:</strong> ${serviceName}</p>
        <p><strong>Prestador:</strong> ${providerName}</p>
        <p><strong>Fecha y hora:</strong> ${formattedDate}</p>
        <p><strong>Dirección:</strong> ${address}</p>
        ${priceText}
      </div>

      <div style="background: #EFF6FF; border: 1px solid #BFDBFE; border-radius: 10px; padding: 14px; margin-bottom: 20px;">
        <p style="color: #1D4ED8; font-size: 13px; margin: 0;">
          🔒 <strong>Tu pago está protegido.</strong> No se realiza ningún cobro hasta que confirmes que el servicio fue completado satisfactoriamente.
        </p>
      </div>

      <div style="text-align: center;">
        <p style="color: #6B7280; font-size: 13px;">¿Necesitas ayuda? Contáctanos en <a href="mailto:soporte@serviciosya.app" style="color: #0D9488;">soporte@serviciosya.app</a></p>
      </div>
    </div>

    <!-- Footer -->
    <div style="background: #F9FAFB; padding: 16px 28px; border-top: 1px solid #E5E7EB; text-align: center;">
      <p style="color: #9CA3AF; font-size: 11px; margin: 0;">© 2026 ServiciosYa · República Dominicana · Ley 172-13</p>
    </div>
  </div>
</body>
</html>`;

    // Enviar vía Resend
    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `ServiciosYa <${FROM_EMAIL}>`,
        to: [profile.email],
        subject: `✅ Reserva confirmada — ${serviceName} · #SY-${shortId}`,
        html,
      }),
    });

    if (!resendRes.ok) {
      const err = await resendRes.text();
      console.error("Resend error:", err);
      return new Response(JSON.stringify({ error: "Email failed", detail: err }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true, bookingId, shortId }), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (e) {
    console.error("Function error:", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
