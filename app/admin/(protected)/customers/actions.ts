"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { logAdminAction } from "@/lib/admin/audit-log";
import { assertNotSelf } from "@/lib/admin/self-action-guard";
import { callAdminEdgeFunction } from "@/lib/admin/edge-functions";

export type CustomerActionState = { error: string } | null;

async function setCustomerActive(
  userId: string,
  action: "disable" | "enable",
): Promise<CustomerActionState> {
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
      "admin-customers",
      { action, userId },
      session.access_token,
    );
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : "Request failed.",
    };
  }

  await logAdminAction(supabase, {
    action: action === "disable" ? "customer.disable" : "customer.enable",
    entityType: "customer",
    entityId: userId,
  });

  revalidatePath("/admin/customers");
  revalidatePath(`/admin/customers/${userId}`);

  return null;
}

export async function disableCustomer(
  userId: string,
): Promise<CustomerActionState> {
  return setCustomerActive(userId, "disable");
}

export async function enableCustomer(
  userId: string,
): Promise<CustomerActionState> {
  return setCustomerActive(userId, "enable");
}

export type CustomerEmailStatus = {
  emailConfirmed: boolean;
  emailConfirmedAt: string | null;
  email: string | null;
};

export async function getCustomerEmailStatus(
  userId: string,
): Promise<{ data: CustomerEmailStatus | null; error: string | null }> {
  const admin = await requireAdmin();
  void admin;

  const supabase = await createServerSupabaseClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session?.access_token) {
    return { data: null, error: "Your session has expired. Please sign in again." };
  }

  try {
    const result = await callAdminEdgeFunction<{
      emailConfirmed?: boolean;
      emailConfirmedAt?: string | null;
      email?: string | null;
    }>("admin-customers", { action: "get", userId }, session.access_token);

    return {
      data: {
        emailConfirmed: Boolean(result.emailConfirmed),
        emailConfirmedAt: result.emailConfirmedAt ?? null,
        email: result.email ?? null,
      },
      error: null,
    };
  } catch (error) {
    return {
      data: null,
      error: error instanceof Error ? error.message : "Request failed.",
    };
  }
}

export async function confirmCustomerEmail(
  userId: string,
): Promise<CustomerActionState> {
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
      "admin-customers",
      { action: "confirm_email", userId },
      session.access_token,
    );
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : "Request failed.",
    };
  }

  await logAdminAction(supabase, {
    action: "customer.confirm_email",
    entityType: "customer",
    entityId: userId,
  });

  revalidatePath("/admin/customers");
  revalidatePath(`/admin/customers/${userId}`);

  return null;
}
