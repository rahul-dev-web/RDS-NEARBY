import { withSupabase } from "npm:@supabase/server";

const json = (body: unknown, status = 200) => Response.json(body, { status });
const allowedIdempotencyKey = /^[A-Za-z0-9:_-]{8,128}$/;

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

    const campaignType = String(body.campaign_type ?? "").trim().toUpperCase();
    const businessId = String(body.business_id ?? "").trim();
    const offerId = String(body.offer_id ?? "").trim();
    const idempotencyKey = String(body.idempotency_key ?? "").trim();

    if (!["BOOST_SHOP", "PROMOTE_OFFER"].includes(campaignType)) {
      return json({ error: "unsupported_campaign_type" }, 400);
    }

    if (
      !businessId ||
      !idempotencyKey ||
      !allowedIdempotencyKey.test(idempotencyKey) ||
      (campaignType === "PROMOTE_OFFER" && !offerId)
    ) {
      return json({ error: "invalid_campaign_request" }, 400);
    }

    const { data: profile, error: profileError } = await ctx.supabase
      .from("profiles")
      .select("id,role,status")
      .eq("id", userId)
      .maybeSingle();

    if (profileError) return json({ error: "profile_lookup_failed" }, 500);
    if (!profile || profile.role !== "merchant" || profile.status !== "active") {
      return json({ error: "merchant_role_required" }, 403);
    }

    const { data: business, error: businessError } = await ctx.supabase
      .from("businesses")
      .select("id,owner_id,status,verification_status")
      .eq("id", businessId)
      .maybeSingle();

    if (businessError) return json({ error: "business_lookup_failed" }, 500);
    if (!business || business.owner_id !== userId) {
      return json({ error: "business_not_owned" }, 403);
    }
    if (business.status !== "active" || business.verification_status !== "verified") {
      return json({ error: "business_not_eligible" }, 409);
    }

    if (campaignType === "PROMOTE_OFFER") {
      const { data, error } = await ctx.supabaseAdmin.rpc(
        "create_promote_offer_campaign",
        {
          p_merchant_id: businessId,
          p_offer_id: offerId,
          p_idempotency_key: idempotencyKey,
        },
      );

      if (error) {
        const message = error.message ?? "";
        if (message.includes("insufficient_marketing_credits")) {
          return json({ error: "insufficient_marketing_credits" }, 409);
        }
        if (message.includes("offer_not_owned")) {
          return json({ error: "offer_not_owned" }, 403);
        }
        if (message.includes("offer_not_active")) {
          return json({ error: "offer_not_active" }, 409);
        }
        if (message.includes("business_not_eligible")) {
          return json({ error: "business_not_eligible" }, 409);
        }
        if (message.includes("business_not_found")) {
          return json({ error: "business_not_found" }, 404);
        }
        return json({ error: "campaign_create_failed" }, 500);
      }

      return json(data);
    }

    const { data, error } = await ctx.supabaseAdmin.rpc(
      "create_boost_shop_campaign",
      {
        p_merchant_id: businessId,
        p_idempotency_key: idempotencyKey,
      },
    );

    if (error) {
      const message = error.message ?? "";
      if (message.includes("insufficient_marketing_credits")) {
        return json({ error: "insufficient_marketing_credits" }, 409);
      }
      if (message.includes("business_not_eligible")) {
        return json({ error: "business_not_eligible" }, 409);
      }
      if (message.includes("business_not_found")) {
        return json({ error: "business_not_found" }, 404);
      }
      return json({ error: "campaign_create_failed" }, 500);
    }

    return json(data);
  }),
};
