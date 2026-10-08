import { withSupabase } from "npm:@supabase/server";

const json = (body: unknown, status = 200) =>
  Response.json(body, { status });

const allowedToken = /^[A-Za-z0-9_-]{8,64}$/;

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

    const userId = ctx.userClaims?.id;
    if (!userId) return json({ error: "unauthorized" }, 401);

    const { data: existing, error: existingError } = await ctx.supabaseAdmin
      .from("customer_referral_tokens")
      .select("id,token,is_active")
      .eq("user_id", userId)
      .maybeSingle();

    if (existingError) return json({ error: "token_lookup_failed" }, 500);
    if (existing) return json({ token: existing.token, is_active: existing.is_active, created: false });

    const token = crypto.randomUUID().replaceAll("-", "").slice(0, 16);
    if (!allowedToken.test(token)) return json({ error: "token_generation_failed" }, 500);

    const { data: created, error: createError } = await ctx.supabaseAdmin
      .from("customer_referral_tokens")
      .insert({ user_id: userId, token })
      .select("id,token,is_active")
      .single();

    if (createError) {
      if (createError.code === "23505") {
        const { data: concurrent } = await ctx.supabaseAdmin
          .from("customer_referral_tokens")
          .select("id,token,is_active")
          .eq("user_id", userId)
          .maybeSingle();

        return concurrent
          ? json({ token: concurrent.token, is_active: concurrent.is_active, created: false })
          : json({ error: "token_create_failed" }, 500);
      }
      return json({ error: "token_create_failed" }, 500);
    }

    return json({ token: created.token, is_active: created.is_active, created: true });
  }),
};
