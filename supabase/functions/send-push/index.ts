// ─────────────────────────────────────────────────────────────────────────────
// send-push Edge Function
//
// Flujo:
//   Flutter → send-push(type) → lee plantilla de DB → verifica cooldown
//           → envía via OneSignal REST API
//
// Secrets requeridos (supabase secrets set KEY=value):
//   ONESIGNAL_APP_ID
//   ONESIGNAL_REST_API_KEY
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const ONESIGNAL_APP_ID       = Deno.env.get('ONESIGNAL_APP_ID')       ?? '';
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? '';

serve(async (req) => {
  try {
    // ── Auth ───────────────────────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'No auth' }, 401);
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return json({ error: 'Unauthorized' }, 401);

    // ── Payload ────────────────────────────────────────────────────────────────
    const payload = await req.json() as {
      type: string;
      // Opcionales — si no vienen, se usan los de la plantilla en DB
      title?: string;
      body?:  string;
      data?:  Record<string, unknown>;
    };

    if (!payload.type) return json({ error: 'type requerido' }, 400);

    // ── Leer plantilla desde DB ────────────────────────────────────────────────
    const { data: template, error: tErr } = await supabase
      .from('push_notification_templates')
      .select('title, body, cooldown_hours, is_active, target_role')
      .eq('type', payload.type)
      .single();

    if (tErr || !template) {
      return json({ error: `Plantilla no encontrada: ${payload.type}` }, 404);
    }

    if (!template.is_active) {
      return json({ skipped: true, reason: 'template_inactive' }, 200);
    }

    // ── Verificar cooldown ─────────────────────────────────────────────────────
    const { data: canSend } = await supabase
      .rpc('can_send_push', { p_type: payload.type });

    if (canSend === false) {
      return json({ skipped: true, reason: 'rate_limited' }, 200);
    }

    // ── Validar OneSignal config ───────────────────────────────────────────────
    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
      return json({ error: 'OneSignal no configurado en secrets' }, 500);
    }

    // ── Enviar via OneSignal REST API ──────────────────────────────────────────
    const title  = payload.title ?? template.title;
    const body   = payload.body  ?? template.body;

    const osRes = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify({
        app_id:          ONESIGNAL_APP_ID,
        include_aliases: { external_id: [user.id] },
        target_channel:  'push',
        headings:        { en: title },
        contents:        { en: body },
        data:            payload.data ?? {},
      }),
    });

    if (!osRes.ok) {
      const errText = await osRes.text();
      return json({ error: errText }, 500);
    }

    // ── Registrar en log ───────────────────────────────────────────────────────
    await supabase.rpc('log_push_sent', { p_type: payload.type });

    return json({ success: true, type: payload.type });

  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});

// ── Helper ─────────────────────────────────────────────────────────────────────
function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
