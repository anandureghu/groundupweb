import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";

import { resolveAdminGateResult } from "./gate";

export async function requireAdmin(): Promise<{
  userId: string;
  email: string;
}> {
  const supabase = await createServerSupabaseClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const session = user ? { userId: user.id } : null;

  let profile: { staffRole: string | null; email: string | null } | null =
    null;

  if (user) {
    const { data } = await supabase
      .from("profiles")
      .select("staff_role, email")
      .eq("id", user.id)
      .maybeSingle();

    profile = data
      ? { staffRole: data.staff_role, email: data.email }
      : null;
  }

  const result = resolveAdminGateResult(
    session,
    profile ? { staffRole: profile.staffRole } : null,
  );

  if (result === "login") {
    redirect("/admin/login");
  }

  if (result === "unauthorized") {
    redirect("/admin/unauthorized");
  }

  return {
    userId: user!.id,
    email: profile?.email ?? user!.email ?? "",
  };
}
