import { withSupabase } from "npm:@supabase/server";

const json = (body: unknown, status = 200) =>
  Response.json(body, { status });

const allowedEvents = new Set([
  "SEARCH",
  "SHOP_VIEW",
  "OFFER_VIEW",
  "OFFER_CLAIM",
  "REQUEST",
  "SAVE",
  "CONTACT",
  "WHATSAPP",
]);

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    const userId = ctx.userClaims?.id;
    if (!userId) return json({ error: "unauthorized" }, 401);

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    const referralId = String(body.referral_id ?? "").trim();
    const eventType = String(body.event_type ?? "").trim().toUpperCase();
    if (!referralId || !allowedEvents.has(eventType)) {
      return json({ error: "invalid_activity" }, 400);
    }

    const { data: referral, error: lookupError } = await ctx.supabaseAdmin
      .from("referrals")
      .select("id,status,referred_user_id,expires_at")
      .eq("id", referralId)
      .eq("referred_user_id", userId)
      .maybeSingle();

    if (lookupError) return json({ error: "referral_lookup_failed" }, 500);
    if (!referral) return json({ error: "referral_not_found" }, 404);

    if (referral.status !== "PENDING") {
      return json({ status: referral.status, qualified: referral.status === "QUALIFIED" });
    }

    if (new Date(referral.expires_at).getTime() < Date.now()) {
      await ctx.supabaseAdmin
        .from("referrals")
        .update({ status: "EXPIRED" })
        .eq("id", referral.id)
        .eq("status", "PENDING");

      await ctx.supabaseAdmin.from("referral_events").insert({
        referral_id: referral.id,
        event_type: "EXPIRED",
      });
      return json({ status: "EXPIRED", qualified: false });
    }

    await ctx.supabaseAdmin.from("referral_events").insert({
      referral_id: referral.id,
      event_type: "MEANINGFUL_ACTIVITY",
      metadata: { activity_type: eventType },
    });

    const idempotencyKey = `referral:${referral.id}:reward`;
    const { data: result, error: qualifyError } = await ctx.supabaseAdmin
      .rpc("qualify_referral", {
        p_referral_id: referral.id,
        p_idempotency_key: idempotencyKey,
      });

    if (qualifyError) return json({ error: "qualification_failed" }, 500);

    return json({ ...result, activity: eventType });
  }),
};
