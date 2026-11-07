import type { Metadata } from "next";

import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { SettingsForm, type AppSettingRow } from "./settings-form";

export const metadata: Metadata = {
  title: "Settings",
};

type ListAppSettingsRow = {
  key: string;
  value_integer: number;
  value_text: string | null;
  description: string | null;
  updated_at: string;
};

type ListMemberNoticeRow = {
  id: string;
  copy_key: string;
  active: boolean;
  created_at: string;
  recipient_count: number;
  unseen_count: number;
};

export default async function AdminSettingsPage() {
  await requireAdmin();
  const supabase = await createServerSupabaseClient();

  const [{ data, error }, { data: notices, error: noticesError }] =
    await Promise.all([
      supabase.rpc("admin_list_app_settings"),
      supabase.rpc("admin_list_member_notices"),
    ]);

  if (error) {
    console.error("admin_list_app_settings failed", error);
  }
  if (noticesError) {
    console.error("admin_list_member_notices failed", noticesError);
  }

  const settings: AppSettingRow[] = (
    (data as ListAppSettingsRow[] | null) ?? []
  ).map((row) => ({
    key: row.key,
    valueInteger: row.value_integer,
    valueText: row.value_text,
    description: row.description,
    updatedAt: row.updated_at,
  }));

  const noticeRows = (notices as ListMemberNoticeRow[] | null) ?? [];

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-2xl font-semibold">App settings</h1>
        <p className="text-sm text-muted-foreground">
          Integer and text values used by the mobile app. Version gate keys:{" "}
          <span className="font-mono">min_supported_app_version</span>,{" "}
          <span className="font-mono">new_version_available</span>.
        </p>
      </div>

      {noticeRows.length > 0 ? (
        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold">Member notices</h2>
          <div className="overflow-x-auto border border-border">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-border bg-muted/40">
                <tr>
                  <th className="px-4 py-3 font-semibold">Copy key</th>
                  <th className="px-4 py-3 font-semibold">Active</th>
                  <th className="px-4 py-3 font-semibold">Recipients</th>
                  <th className="px-4 py-3 font-semibold">Unseen</th>
                  <th className="px-4 py-3 font-semibold">Created</th>
                </tr>
              </thead>
              <tbody>
                {noticeRows.map((notice) => (
                  <tr key={notice.id} className="border-b border-border">
                    <td className="px-4 py-3 font-mono text-xs">
                      {notice.copy_key}
                    </td>
                    <td className="px-4 py-3">
                      {notice.active ? "Yes" : "No"}
                    </td>
                    <td className="px-4 py-3">{notice.recipient_count}</td>
                    <td className="px-4 py-3">{notice.unseen_count}</td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(notice.created_at).toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}

      {settings.length === 0 ? (
        <p className="text-sm text-muted-foreground">
          No settings returned. Ensure migrations are applied.
        </p>
      ) : (
        <SettingsForm settings={settings} />
      )}
    </div>
  );
}
