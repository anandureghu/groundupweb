"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { requireAdmin } from "@/lib/admin/auth";
import { logAdminAction } from "@/lib/admin/audit-log";
import {
  audiencePayload,
  checked,
  field,
  isAudienceId,
  parseNotificationSettingsForm,
  parseProfileIds,
  parseScheduleInput,
  type NotificationSettingsFormInput,
} from "@/lib/admin/notifications";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export type NotificationActionState = {
  error?: string;
  success?: string;
  clearCompose?: boolean;
  previewCount?: number;
} | null;

const TEXT_FIELDS = [
  "birthdayNotificationTitle",
  "birthdayNotificationBody",
  "birthdayCouponTitle",
  "birthdayCouponDescription",
  "challengeStreakAtRiskTitle",
  "challengeStreakAtRiskBody",
  "challengeNearCompletionTitle",
  "challengeNearCompletionBody",
  "challengeInactiveTitle",
  "challengeInactiveBody",
  "challengeStreakBrokenTitle",
  "challengeStreakBrokenBody",
  "challengeEndingSoonTitle",
  "challengeEndingSoonBody",
  "stepLowActivityTitle",
  "stepLowActivityBody",
  "stepNearDailyGoalTitle",
  "stepNearDailyGoalBody",
  "stepStreakAtRiskTitle",
  "stepStreakAtRiskBody",
  "stepSyncReminderTitle",
  "stepSyncReminderBody",
  "referralRefereeWelcomeTitle",
  "referralRefereeWelcomeBody",
  "referralReferrerSuccessTitle",
  "referralReferrerSuccessBody",
  "referralProgressNudgeTitle",
  "referralProgressNudgeBody",
  "referralMilestoneTitle",
  "referralMilestoneBody",
] as const satisfies ReadonlyArray<keyof NotificationSettingsFormInput>;

function rpcError(error: { message: string } | null): string | null {
  return error ? error.message : null;
}

function revalidateNotifications() {
  revalidatePath("/admin/notifications");
  revalidatePath("/admin/notifications/templates");
  revalidatePath("/admin/notifications/settings");
}

export async function saveNotificationSettings(
  _prev: NotificationActionState,
  formData: FormData,
): Promise<NotificationActionState> {
  await requireAdmin();

  const input = {
    birthdayCouponEnabled: checked(formData, "birthdayCouponEnabled"),
    birthdayCouponDiscountPercent: field(formData, "birthdayCouponDiscountPercent"),
    birthdayCouponValidityDays: field(formData, "birthdayCouponValidityDays"),
    birthdayCouponMinOrderPounds: field(formData, "birthdayCouponMinOrderPounds"),
    challengeReminderEnabled: checked(formData, "challengeReminderEnabled"),
    challengeStreakReminderHour: field(formData, "challengeStreakReminderHour"),
    challengeInactiveDaysThreshold: field(formData, "challengeInactiveDaysThreshold"),
    orderNotifyReady: checked(formData, "orderNotifyReady"),
    orderNotifyCancelled: checked(formData, "orderNotifyCancelled"),
    orderNotifyConfirmed: checked(formData, "orderNotifyConfirmed"),
    referralNotificationsEnabled: checked(formData, "referralNotificationsEnabled"),
  } as NotificationSettingsFormInput;

  for (const name of TEXT_FIELDS) {
    input[name] = field(formData, name);
  }

  const parsed = parseNotificationSettingsForm(input);
  if (!parsed.ok) {
    return { error: parsed.error };
  }

  const supabase = await createServerSupabaseClient();

  for (const [key, value] of parsed.value.integers) {
    const { error } = await supabase.rpc("update_notification_setting", {
      p_key: key,
      p_value_integer: value,
    });
    const message = rpcError(error);
    if (message) {
      return { error: message };
    }
  }

  for (const [key, value] of parsed.value.texts) {
    const { error } = await supabase.rpc("update_notification_setting_text", {
      p_key: key,
      p_value_text: value,
    });
    const message = rpcError(error);
    if (message) {
      return { error: message };
    }
  }

  await logAdminAction(supabase, {
    action: "notification_settings.update",
    entityType: "notification_settings",
  });
  revalidatePath("/admin/notifications/settings");
  return { success: "Notification settings saved." };
}

function readTemplateFields(formData: FormData):
  | { error: string }
  | {
      id: string | null;
      name: string;
      title: string;
      body: string;
      audience: ReturnType<typeof audiencePayload>;
    } {
  const name = field(formData, "name").trim();
  const title = field(formData, "title").trim();
  const body = field(formData, "body").trim();
  const audienceId = field(formData, "audience").trim();

  if (!name || !title || !body) {
    return { error: "Name, title, and message are required." };
  }
  if (!isAudienceId(audienceId)) {
    return { error: "Choose a valid audience." };
  }

  const id = field(formData, "id").trim();
  return {
    id: id || null,
    name,
    title,
    body,
    audience: audiencePayload(audienceId),
  };
}

export async function saveNotificationTemplate(
  _prev: NotificationActionState,
  formData: FormData,
): Promise<NotificationActionState> {
  await requireAdmin();
  const template = readTemplateFields(formData);
  if ("error" in template) {
    return { error: template.error };
  }

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("upsert_notification_template", {
    p_id: template.id,
    p_name: template.name,
    p_title: template.title,
    p_body: template.body,
    p_audience_type: template.audience.audienceType,
    p_audience_segment: template.audience.audienceSegment,
  });
  const message = rpcError(error);
  if (message) {
    return { error: message };
  }

  const saved = (Array.isArray(data) ? data[0] : data) as { id?: string } | null;
  await logAdminAction(supabase, {
    action: template.id ? "notification_template.update" : "notification_template.create",
    entityType: "notification_template",
    entityId: saved?.id ?? template.id ?? undefined,
    metadata: { name: template.name },
  });
  revalidateNotifications();

  if (!template.id) {
    redirect("/admin/notifications/templates");
  }

  return { success: "Template saved." };
}

export async function deleteNotificationTemplate(
  _prev: NotificationActionState,
  formData: FormData,
): Promise<NotificationActionState> {
  await requireAdmin();
  const id = field(formData, "id").trim();
  if (!id) {
    return { error: "Template is missing." };
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("delete_notification_template", {
    p_id: id,
  });
  const message = rpcError(error);
  if (message) {
    return { error: message };
  }

  await logAdminAction(supabase, {
    action: "notification_template.delete",
    entityType: "notification_template",
    entityId: id,
  });
  revalidateNotifications();
  redirect("/admin/notifications/templates");
}

async function customerIds(
  supabase: Awaited<ReturnType<typeof createServerSupabaseClient>>,
): Promise<Set<string>> {
  const { data, error } = await supabase.rpc("list_customers");
  if (error) {
    throw new Error(error.message);
  }
  const rows = (data as { id?: string }[] | null) ?? [];
  return new Set(rows.map((row) => String(row.id ?? "").toLowerCase()).filter(Boolean));
}

export async function previewBroadcastAudience(input: {
  audienceId: string;
  profileIds?: string[];
}): Promise<NotificationActionState> {
  await requireAdmin();
  if (!isAudienceId(input.audienceId)) {
    return { error: "Choose a valid audience." };
  }

  const audience = audiencePayload(input.audienceId);
  const supabase = await createServerSupabaseClient();
  let selected: string[] = [];

  if (audience.audienceType === "selected") {
    try {
      const allowed = await customerIds(supabase);
      selected = parseProfileIds(input.profileIds ?? []).filter((id) => allowed.has(id));
    } catch (error) {
      return { error: error instanceof Error ? error.message : "Could not load members." };
    }
    if (selected.length === 0) {
      return { error: "Choose at least one member." };
    }
  }

  const { data, error } = await supabase.rpc("preview_admin_broadcast_audience", {
    p_audience_type: audience.audienceType,
    p_audience_filter: audience.audienceFilter,
    p_selected_profile_ids: selected,
  });
  const message = rpcError(error);
  if (message) {
    return { error: message };
  }

  return { previewCount: typeof data === "number" ? data : Number(data ?? 0) };
}

export async function submitBroadcast(
  _prev: NotificationActionState,
  formData: FormData,
): Promise<NotificationActionState> {
  await requireAdmin();
  const intent = field(formData, "intent");
  const title = field(formData, "title").trim();
  const body = field(formData, "body").trim();
  const audienceId = field(formData, "audience").trim();

  if (!title || !body) {
    return { error: "Title and message are required." };
  }
  if (!isAudienceId(audienceId)) {
    return { error: "Choose a valid audience." };
  }

  const audience = audiencePayload(audienceId);
  const supabase = await createServerSupabaseClient();
  let selected: string[] = [];

  if (audience.audienceType === "selected") {
    try {
      const allowed = await customerIds(supabase);
      selected = parseProfileIds(formData.getAll("profileId").map(String)).filter((id) =>
        allowed.has(id),
      );
    } catch (error) {
      return { error: error instanceof Error ? error.message : "Could not load members." };
    }
    if (selected.length === 0) {
      return { error: "Choose at least one member." };
    }
  }

  if (intent === "save-template") {
    if (audience.audienceType === "selected") {
      return { error: "Templates keep a reusable audience. Selected members are for this send only." };
    }
    const name = field(formData, "templateName").trim();
    if (!name) {
      return { error: "Name, title, and message are required." };
    }

    const { data, error } = await supabase.rpc("upsert_notification_template", {
      p_id: null,
      p_name: name,
      p_title: title,
      p_body: body,
      p_audience_type: audience.audienceType,
      p_audience_segment: audience.audienceSegment,
    });
    const message = rpcError(error);
    if (message) {
      return { error: message };
    }

    const saved = (Array.isArray(data) ? data[0] : data) as { id?: string } | null;
    await logAdminAction(supabase, {
      action: "notification_template.create",
      entityType: "notification_template",
      entityId: saved?.id,
      metadata: { name },
    });
    revalidateNotifications();
    return { success: "Saved as a reusable template." };
  }

  const sendNow = intent === "send";
  if (!sendNow && intent !== "schedule") {
    return { error: "Choose send now or schedule." };
  }

  const scheduledFor = sendNow
    ? null
    : parseScheduleInput(field(formData, "scheduledFor"));
  if (!sendNow && !scheduledFor) {
    return { error: "Choose a schedule time or send now." };
  }

  const { data, error } = await supabase.rpc("create_admin_broadcast", {
    p_title: title,
    p_body: body,
    p_audience_type: audience.audienceType,
    p_audience_filter: audience.audienceFilter,
    p_selected_profile_ids: selected,
    p_scheduled_for: scheduledFor,
    p_data: {},
    p_send_now: sendNow,
  });
  const message = rpcError(error);
  if (message) {
    return { error: message };
  }

  await logAdminAction(supabase, {
    action: "broadcast.create",
    entityType: "broadcast",
    entityId: typeof data === "string" ? data : undefined,
    metadata: { sendNow, audience: audienceId, recipients: selected.length || undefined },
  });
  revalidatePath("/admin/notifications");
  return {
    success: sendNow ? "Notification sent." : "Notification scheduled.",
    clearCompose: true,
  };
}

export async function cancelBroadcast(
  _prev: NotificationActionState,
  formData: FormData,
): Promise<NotificationActionState> {
  await requireAdmin();
  const id = field(formData, "id").trim();
  if (!id) {
    return { error: "Broadcast is missing." };
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("cancel_admin_broadcast", {
    p_broadcast_id: id,
  });
  const message = rpcError(error);
  if (message) {
    return { error: message };
  }

  await logAdminAction(supabase, {
    action: "broadcast.cancel",
    entityType: "broadcast",
    entityId: id,
  });
  revalidatePath("/admin/notifications");
  return { success: "Scheduled notification cancelled." };
}
