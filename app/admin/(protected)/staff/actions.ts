"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { logAdminAction } from "@/lib/admin/audit-log";
import { assertNotSelf } from "@/lib/admin/self-action-guard";
import { callAdminEdgeFunction } from "@/lib/admin/edge-functions";

export type StaffActionState = { error: string } | null;

export type CreateStaffInput = {
  name: string;
  email: string;
  role: "staff" | "admin";
  storeId: string;
};

export type CreateStaffResult =
  | { error: string }
  | { email: string; temporaryPassword: string };

type CreateStaffEdgeResponse = {
  userId: string;
  temporaryPassword: string;
};

export async function createStaff(
  input: CreateStaffInput,
): Promise<CreateStaffResult> {
  await requireAdmin();

  const supabase = await createServerSupabaseClient();

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session?.access_token) {
    return { error: "Your session has expired. Please sign in again." };
  }

  let result: CreateStaffEdgeResponse;

  try {
    result = await callAdminEdgeFunction<CreateStaffEdgeResponse>(
      "admin-staff",
      { action: "create", ...input },
      session.access_token,
    );
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : "Request failed.",
    };
  }

  await logAdminAction(supabase, {
    action: "staff.create",
    entityType: "staff",
    entityId: result.userId,
    metadata: { email: input.email, role: input.role },
  });

  revalidatePath("/admin/staff");

  return { email: input.email, temporaryPassword: result.temporaryPassword };
}

async function setStaffActive(
  userId: string,
  action: "disable" | "enable",
): Promise<StaffActionState> {
  const admin = await requireAdmin();

  try {
    assertNotSelf(userId, admin.userId);
  } catch (error) {
    return {
      error:
        error instanceof Error
          ? error.message
          : "You can't do this to your own account.",
    };
  }

  const supabase = await createServerSupabaseClient();

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session?.access_token) {
    return { error: "Your session has expired. Please sign in again." };
  }

  try {
    await callAdminEdgeFunction(
      "admin-staff",
      { action, userId },
      session.access_token,
    );
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : "Request failed.",
    };
  }

  await logAdminAction(supabase, {
    action: action === "disable" ? "staff.disable" : "staff.enable",
    entityType: "staff",
    entityId: userId,
  });

  revalidatePath("/admin/staff");
  revalidatePath(`/admin/staff/${userId}`);

  return null;
}

export async function disableStaff(userId: string): Promise<StaffActionState> {
  return setStaffActive(userId, "disable");
}

export async function enableStaff(userId: string): Promise<StaffActionState> {
  return setStaffActive(userId, "enable");
}
