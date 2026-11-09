import type { Metadata } from "next";

import { AdminPageHeader } from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import {
  notificationSettingsFromRow,
  rowsOf,
  type NotificationSettingsRow,
} from "@/lib/admin/notifications";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { NotificationSectionNav } from "../section-nav";
import { NotificationSettingsForm } from "./settings-form";

export const metadata: Metadata = {
  title: "Notification settings",
};

export default async function NotificationSettingsPage() {
  await requireAdmin();
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_notification_settings");

  if (error) {
    console.error("get_notification_settings failed", error);
  }

  const row = rowsOf<NotificationSettingsRow>(data)[0] ?? null;

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Notification settings"
        description="Birthday gifts, order alerts, challenge and referral messages."
      />
      <NotificationSectionNav />
      {error ? (
        <p className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error.message}
        </p>
      ) : null}
      {row ? (
        <NotificationSettingsForm settings={notificationSettingsFromRow(row)} />
      ) : (
        <p className="rounded-xl border border-dashed border-zinc-300 bg-white px-4 py-8 text-center text-sm text-zinc-500">
          Notification settings were not returned.
        </p>
      )}
    </div>
  );
}
