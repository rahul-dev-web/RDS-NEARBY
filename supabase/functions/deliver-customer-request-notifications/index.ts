import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

type FcmServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type QueuedNotification = {
  id: string;
  user_id: string;
  title: string;
  message: string;
  priority: "normal" | "high";
  type: string;
  related_entity_type: string | null;
  related_entity_id: string | null;
  delivery_attempts: number;
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function pemToBytes(pem: string): Uint8Array {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(body);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function getGoogleAccessToken(account: FcmServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: account.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = header + "." + claims;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  ));
  const assertion = unsigned + "." + base64Url(signature);
  const response = await fetch(account.token_uri ?? "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== "string") {
    throw new Error("Google OAuth token exchange failed: " + JSON.stringify(result).slice(0, 500));
  }
  return result.access_token as string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!supabaseUrl || !serviceRoleKey || authHeader !== `Bearer ${serviceRoleKey}`) {
    return json(401, { error: "service_role_authorization_required" });
  }

  const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountRaw) {
    return json(503, {
      error: "fcm_not_configured",
      message: "Add FCM_SERVICE_ACCOUNT_JSON to Supabase Edge Function secrets before enabling the scheduler. No notifications were claimed or changed.",
    });
  }

  let account: FcmServiceAccount;
  try {
    account = JSON.parse(serviceAccountRaw);
    if (!account.project_id || !account.client_email || !account.private_key) {
      throw new Error("Missing project_id, client_email, or private_key");
    }
  } catch (error) {
    return json(503, { error: "invalid_fcm_service_account_secret", message: String(error) });
  }

  let accessToken: string;
  try {
    accessToken = await getGoogleAccessToken(account);
  } catch (error) {
    return json(502, { error: "fcm_authentication_failed", message: String(error).slice(0, 700) });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: claimed, error: claimError } = await supabase.rpc(
    "claim_due_customer_request_notifications",
    { p_batch_size: 25 },
  );
  if (claimError) return json(500, { error: "notification_claim_failed", message: claimError.message });

  const summary = { claimed: (claimed ?? []).length, sent: 0, retried_or_failed: 0, suppressed: 0, no_active_device: 0 };
  for (const notification of (claimed ?? []) as QueuedNotification[]) {
    const { data: preference } = await supabase
      .from("notification_preferences")
      .select("customer_requests, urgent_requests")
      .eq("user_id", notification.user_id)
      .maybeSingle();

    if (preference && (preference.customer_requests === false ||
        (notification.priority === "high" && preference.urgent_requests === false))) {
      await supabase.rpc("finish_customer_request_notification", {
        p_notification_id: notification.id,
        p_success: false,
        p_error: "Push suppressed by recipient notification preferences",
        p_max_attempts: 1,
      });
      summary.suppressed++;
      continue;
    }

    const { data: devices, error: deviceError } = await supabase
      .from("device_tokens")
      .select("id, token")
      .eq("user_id", notification.user_id)
      .eq("is_active", true);

    if (deviceError || !devices?.length) {
      await supabase.rpc("finish_customer_request_notification", {
        p_notification_id: notification.id,
        p_success: false,
        p_error: deviceError?.message ?? "No active device tokens registered",
      });
      summary.no_active_device++;
      summary.retried_or_failed++;
      continue;
    }

    let delivered = false;
    const errors: string[] = [];
    for (const device of devices) {
      const deepLink = notification.related_entity_id
        ? `/merchant/requests/${notification.related_entity_id}`
        : "/merchant/requests";
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: { title: notification.title, body: notification.message },
              data: {
                notificationId: notification.id,
                notificationType: notification.type,
                requestId: notification.related_entity_id ?? "",
                deepLink,
              },
              android: notification.priority === "high"
                ? { priority: "HIGH", notification: { channel_id: "local_request", sound: "default" } }
                : { priority: "NORMAL" },
              apns: notification.priority === "high"
                ? { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } }
                : undefined,
            },
          }),
        },
      );

      const result = await response.json().catch(() => ({}));
      if (response.ok) {
        delivered = true;
      } else {
        const errorText = JSON.stringify(result).slice(0, 500);
        errors.push(`HTTP ${response.status}: ${errorText}`);
        const fcmErrorCode = result?.error?.details?.find?.((item: { errorCode?: string }) =>
          item.errorCode === "UNREGISTERED" || item.errorCode === "SENDER_ID_MISMATCH")?.errorCode;
        if (response.status === 404 || fcmErrorCode === "UNREGISTERED") {
          await supabase.from("device_tokens").update({ is_active: false }).eq("id", device.id);
        }
      }
    }

    const { error: finishError } = await supabase.rpc("finish_customer_request_notification", {
      p_notification_id: notification.id,
      p_success: delivered,
      p_error: delivered ? null : errors.join(" | ").slice(0, 1000) || "FCM send failed",
    });
    if (finishError) {
      summary.retried_or_failed++;
      continue;
    }
    if (delivered) summary.sent++;
    else summary.retried_or_failed++;
  }

  return json(200, { ok: true, ...summary, processed_at: new Date().toISOString() });
});
