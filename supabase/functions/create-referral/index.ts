import { withSupabase } from "npm:@supabase/server";

const json = (body: unknown, status = 200) =>
  Response.json(body, { status });

const allowedToken = /^[A-Za-z0-9_-]{8,64}$/;

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

    const token = String(body.token ?? "").trim();
    if (!allowedToken.test(token)) return json({ error: "invalid_referral_token" }, 400);

    const { data: existing, error: existingError } = await ctx.supabaseAdmin
      .from("referrals")
      .select("id,status,referrer_type,referrer_user_id,referrer_business_id")
      .eq("referred_user_id", userId)
      .maybeSingle();

    if (existingError) return json({ error: "referral_lookup_failed" }, 500);
    if (existing) return json({ referral: existing, created: false });

    const { data: merchantToken, error: merchantError } = await ctx.supabaseAdmin
      .from("merchant_referral_tokens")
      .select("business_id,is_active")
      .eq("token", token)
      .eq("is_active", true)
      .maybeSingle();

    if (merchantError) return json({ error: "token_lookup_failed" }, 500);

    if (merchantToken) {
      const { data: business, error: businessError } = await ctx.supabaseAdmin
        .from("businesses")
        .select("id,owner_id,status,verification_status")
        .eq("id", merchantToken.business_id)
        .maybeSingle();

      if (businessError) return json({ error: "business_lookup_failed" }, 500);
      if (!business || business.status !== "active" || business.verification_status !== "verified") {
        return json({ error: "business_not_eligible" }, 409);
      }
      if (business.owner_id === userId) return json({ error: "self_referral_not_allowed" }, 409);

      const { data: referral, error: insertError } = await ctx.supabaseAdmin
        .from("referrals")
        .insert({
          referrer_type: "merchant",
          referrer_business_id: business.id,
          referred_user_id: userId,
          referral_token: token,
        })
        .select("id,status,expires_at,referrer_type,referrer_business_id")
        .single();

      if (insertError) {
        if (insertError.code === "23505") {
          const { data: concurrent } = await ctx.supabaseAdmin
            .from("referrals")
            .select("id,status,expires_at,referrer_type,referrer_business_id")
            .eq("referred_user_id", userId)
            .maybeSingle();
          return json({ referral: concurrent, created: false });
        }
        return json({ error: "referral_create_failed" }, 500);
      }

      await ctx.supabaseAdmin.from("referral_events").insert({
        referral_id: referral.id,
        event_type: "QR_SCANNED",
        metadata: { source: "merchant_qr" },
      });

      return json({ referral, created: true });
    }

    const { data: customerToken, error: customerError } = await ctx.supabaseAdmin
      .from("customer_referral_tokens")
      .select("user_id,is_active")
      .eq("token", token)
      .eq("is_active", true)
      .maybeSingle();

    if (customerError) return json({ error: "token_lookup_failed" }, 500);
    if (!customerToken) return json({ error: "referral_not_found" }, 404);
    if (customerToken.user_id === userId) return json({ error: "self_referral_not_allowed" }, 409);

    const { data: referrerProfile, error: profileError } = await ctx.supabaseAdmin
      .from("profiles")
      .select("id,status")
      .eq("id", customerToken.user_id)
      .maybeSingle();

    if (profileError) return json({ error: "referrer_lookup_failed" }, 500);
    if (!referrerProfile || referrerProfile.status !== "active") {
      return json({ error: "referrer_not_eligible" }, 409);
    }

    const { data: referral, error: insertError } = await ctx.supabaseAdmin
      .from("referrals")
      .insert({
        referrer_type: "customer",
        referrer_user_id: customerToken.user_id,
        referred_user_id: userId,
        referral_token: token,
      })
      .select("id,status,expires_at,referrer_type,referrer_user_id")
      .single();

    if (insertError) {
      if (insertError.code === "23505") {
        const { data: concurrent } = await ctx.supabaseAdmin
          .from("referrals")
          .select("id,status,expires_at,referrer_type,referrer_user_id")
          .eq("referred_user_id", userId)
          .maybeSingle();
        return json({ referral: concurrent, created: false });
      }
      return json({ error: "referral_create_failed" }, 500);
    }

    await ctx.supabaseAdmin.from("referral_events").insert({
      referral_id: referral.id,
      event_type: "QR_SCANNED",
      metadata: { source: "customer_referral" },
    });

    return json({ referral, created: true });
  }),
};
