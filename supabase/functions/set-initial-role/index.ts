import { withSupabase } from "npm:@supabase/server";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return Response.json({ error: "method_not_allowed" }, { status: 405 });
    let body: { role?: string };
    try { body = await req.json(); } catch { return Response.json({ error: "invalid_json" }, { status: 400 }); }
    if (body.role !== "customer" && body.role !== "merchant") return Response.json({ error: "invalid_role" }, { status: 400 });
    const userId = ctx.userClaims?.id;
    if (!userId) return Response.json({ error: "unauthorized" }, { status: 401 });
    const { data: profile, error } = await ctx.supabase.from("profiles").select("id,role,status").eq("id",userId).maybeSingle();
    if (error) return Response.json({ error: "profile_lookup_failed" }, { status: 500 });
    if (!profile) return Response.json({ error: "profile_not_ready" }, { status: 409 });
    if (profile.status !== "active") return Response.json({ error: "profile_not_active" }, { status: 403 });
    if (profile.role !== "customer") return Response.json({ error: "role_already_set" }, { status: 409 });
    if (body.role === "customer") return Response.json({ role: "customer" });
    const { error: updateError } = await ctx.supabaseAdmin.from("profiles").update({role:"merchant"}).eq("id",userId).eq("role","customer");
    if (updateError) return Response.json({ error: "role_update_failed" }, { status: 500 });
    return Response.json({ role: "merchant" });
  }),
};
