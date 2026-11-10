"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin } from "@/lib/admin/auth";
import { logAdminAction } from "@/lib/admin/audit-log";
import { field, parseProfileIds } from "@/lib/admin/notifications";
import { parsePointsDelta } from "@/lib/admin/rewards";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export type RewardsActionState = {
  error?: string;
  success?: string;
} | null;

export async function adjustMemberPoints(
  _prev: RewardsActionState,
  formData: FormData,
): Promise<RewardsActionState> {
  await requireAdmin();

  const [profileId] = parseProfileIds([field(formData, "profileId")]);
  if (!profileId) {
    return { error: "Choose a member." };
  }

  const delta = parsePointsDelta(field(formData, "delta"));
  if (delta === null) {
    return { error: "Enter a non-zero whole number of points (use a minus sign to remove points)." };
  }

  const reason = field(formData, "reason").trim();
  if (!reason) {
    return { error: "Enter a reason for this adjustment." };
  }

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("admin_adjust_member_points", {
    p_profile_id: profileId,
    p_delta: delta,
    p_reason: reason,
  });

  if (error) {
    return { error: error.message };
  }

  const newBalance = typeof data === "number" ? data : Number(data);

  await logAdminAction(supabase, {
    action: "rewards.adjust",
    entityType: "profile",
    entityId: profileId,
    metadata: { delta, reason, newBalance },
  });

  revalidatePath("/admin/rewards");
  revalidatePath(`/admin/customers/${profileId}`);

  return { success: `Saved. New balance: ${newBalance.toLocaleString("en-GB")} points.` };
}
