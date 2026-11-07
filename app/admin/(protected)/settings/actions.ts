"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin } from "@/lib/admin/auth";
import { logAdminAction } from "@/lib/admin/audit-log";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export type SettingsActionState = { error?: string; success?: string } | null;

export async function saveAppSetting(
  _prev: SettingsActionState,
  formData: FormData,
): Promise<SettingsActionState> {
  const admin = await requireAdmin();
  const key = String(formData.get("key") ?? "").trim();
  const valueIntegerRaw = String(formData.get("value_integer") ?? "").trim();
  const valueText = String(formData.get("value_text") ?? "");
  const descriptionRaw = formData.get("description");
  const description =
    descriptionRaw === null ? null : String(descriptionRaw);

  if (!key) {
    return { error: "Setting key is required." };
  }

  const valueInteger = Number(valueIntegerRaw);
  if (!Number.isInteger(valueInteger) || valueInteger < 0) {
    return { error: "Integer value must be a non-negative whole number." };
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("admin_upsert_app_setting", {
    p_key: key,
    p_value_integer: valueInteger,
    p_value_text: valueText,
    p_description: description,
  });

  if (error) {
    return { error: error.message };
  }

  await logAdminAction(supabase, {
    action: "app_settings.upsert",
    entityType: "app_settings",
    entityId: key,
    metadata: { valueInteger, valueText },
  });

  revalidatePath("/admin/settings");
  return { success: `Saved ${key}` };
}

export async function saveAppCopy(
  _prev: SettingsActionState,
  formData: FormData,
): Promise<SettingsActionState> {
  await requireAdmin();
  const key = String(formData.get("key") ?? "").trim();
  const title = String(formData.get("title") ?? "");
  const body = String(formData.get("body") ?? "");
  const descriptionRaw = formData.get("description");
  const description =
    descriptionRaw === null ? null : String(descriptionRaw);

  if (!key) {
    return { error: "Copy key is required." };
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("admin_upsert_app_copy", {
    p_key: key,
    p_title: title,
    p_body: body,
    p_description: description,
  });

  if (error) {
    return { error: error.message };
  }

  await logAdminAction(supabase, {
    action: "app_copy.upsert",
    entityType: "app_copy",
    entityId: key,
  });

  revalidatePath("/admin/copy");
  return { success: `Saved ${key}` };
}
