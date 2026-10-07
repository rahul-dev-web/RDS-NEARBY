import { withSupabase } from "npm:@supabase/server";

const slugify = (value: string) =>
  value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 70);

const json = (body: unknown, status = 200) => Response.json(body, { status });

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    const userId = ctx.userClaims?.id;
    if (!userId) return json({ error: "unauthorized" }, 401);

    let body: Record<string, unknown>;
    try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }

    const name = String(body.name ?? "").trim();
    const categoryId = String(body.category_id ?? "").trim();
    const lat = Number(body.lat);
    const lng = Number(body.lng);
    const description = String(body.description ?? "").trim();
    const phone = String(body.phone ?? "").trim();
    const whatsapp = String(body.whatsapp ?? "").trim();
    const address = String(body.address ?? "").trim();
    const localityId = String(body.locality_id ?? "").trim();
    const openingHours = body.opening_hours ?? {};

    if (name.length < 2 || name.length > 120) return json({ error: "invalid_business_name" }, 400);
    if (!categoryId || !Number.isFinite(lat) || !Number.isFinite(lng)) return json({ error: "category_and_valid_location_required" }, 400);
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return json({ error: "invalid_location" }, 400);
    if (typeof openingHours !== "object" || openingHours === null || Array.isArray(openingHours)) return json({ error: "invalid_opening_hours" }, 400);

    const { data: profile, error: profileError } = await ctx.supabase
      .from("profiles").select("id, role, status").eq("id", userId).maybeSingle();
    if (profileError) return json({ error: "profile_lookup_failed" }, 500);
    if (!profile || profile.role !== "merchant" || profile.status !== "active") return json({ error: "merchant_role_required" }, 403);

    const { data: category, error: categoryError } = await ctx.supabase
      .from("categories").select("id").eq("id", categoryId).eq("status", "active").maybeSingle();
    if (categoryError) return json({ error: "category_lookup_failed" }, 500);
    if (!category) return json({ error: "invalid_category" }, 400);

    const base = slugify(name) || "shop";
    let slug = base;
    for (let i = 0; i < 10; i++) {
      const { data: existing } = await ctx.supabaseAdmin.from("businesses").select("id").eq("slug", slug).maybeSingle();
      if (!existing) break;
      slug = base + "-" + crypto.randomUUID().slice(0, 8);
    }

    const { data: business, error: insertError } = await ctx.supabaseAdmin
      .from("businesses")
      .insert({
        owner_id: userId, name, slug, category_id: categoryId,
        description: description || null, phone: phone || null, whatsapp: whatsapp || null,
        lat, lng, address: address || null, locality_id: localityId || null,
        opening_hours: openingHours, is_open: false, accepting_requests: false,
        status: "pending", verification_status: "pending",
      })
      .select("id, name, slug, category_id, status, verification_status")
      .single();

    if (insertError) return json({ error: "business_create_failed" }, 500);

    const { data: referralToken, error: tokenError } = await ctx.supabaseAdmin
      .from("merchant_referral_tokens")
      .insert({ business_id: business.id })
      .select("token, is_active")
      .single();

    if (tokenError) {
      await ctx.supabaseAdmin.from("businesses").delete().eq("id", business.id);
      return json({ error: "referral_token_create_failed" }, 500);
    }

    await ctx.supabaseAdmin.from("audit_logs").insert({
      actor_id: userId, action: "business_created", entity_type: "business",
      entity_id: business.id,
      metadata: {
        status: "pending",
        verification_status: "pending",
        referral_token_created: true,
      },
    });

    return json({ business, referral: referralToken });
  }),
};
