import { withSupabase } from "npm:@supabase/server";

const json = (body: unknown, status = 200) =>
  Response.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }

    const adminId = ctx.userClaims?.id;
    if (!adminId) return json({ error: "unauthorized" }, 401);

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    const flagId = String(body.flag_id ?? "").trim();
    const decision = String(body.decision ?? "").trim().toLowerCase();
    const reason = String(body.reason ?? "").trim();

    if (!uuidPattern.test(flagId)) {
      return json({ error: "invalid_flag_id" }, 400);
    }
    if (decision !== "approve" && decision !== "reject") {
      return json({ error: "invalid_decision" }, 400);
    }
    if (reason.length < 8 || reason.length > 500) {
      return json({ error: "invalid_review_reason" }, 400);
    }

    // Verify the actor with the trusted database record, never user-editable JWT metadata.
    const { data: profile, error: profileError } = await ctx.supabase
      .from("profiles")
      .select("id,role,status")
      .eq("id", adminId)
      .maybeSingle();

    if (profileError) return json({ error: "admin_profile_lookup_failed" }, 500);
    if (!profile || profile.role !== "admin" || profile.status !== "active") {
      return json({ error: "active_admin_required" }, 403);
    }

    // This RPC is executable only by service_role. It repeats the admin status/role
    // check and atomically writes the flag decision and audit log.
    const { data, error } = await ctx.supabaseAdmin.rpc("review_fraud_flag", {
      p_flag_id: flagId,
      p_admin_id: adminId,
      p_decision: decision,
      p_review_reason: reason,
    });

    if (error) {
      const message = error.message ?? "";
      if (message.includes("Fraud flag not found")) {
        return json({ error: "fraud_flag_not_found" }, 404);
      }
      if (message.includes("already received a final decision")) {
        return json({ error: "fraud_flag_already_reviewed" }, 409);
      }
      if (
        message.includes("active admin profile is required") ||
        message.includes("permission denied")
      ) {
        return json({ error: "active_admin_required" }, 403);
      }
      if (
        message.includes("Invalid") ||
        message.includes("must contain") ||
        message.includes("not reviewable")
      ) {
        return json({ error: "invalid_review_transition" }, 400);
      }
      return json({ error: "fraud_review_failed" }, 500);
    }

    return json({ result: data });
  }),
};
