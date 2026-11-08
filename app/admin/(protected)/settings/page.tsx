import type { Metadata } from "next";

import {
  AdminPageHeader,
  AdminSection,
  AdminTable,
  AdminTableHead,
  AdminTd,
  AdminTh,
} from "@/components/admin/admin-ui";
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
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="App settings"
        description="Integer and text values used by the mobile app. Version gate keys: min_supported_app_version, new_version_available."
      />

      {noticeRows.length > 0 ? (
        <AdminSection
          title="Member notices"
          description="Recent notice broadcasts and delivery counts."
        >
          <AdminTable className="border-0 shadow-none">
            <AdminTableHead>
              <tr>
                <AdminTh>Copy key</AdminTh>
                <AdminTh>Active</AdminTh>
                <AdminTh>Recipients</AdminTh>
                <AdminTh>Unseen</AdminTh>
                <AdminTh>Created</AdminTh>
              </tr>
            </AdminTableHead>
            <tbody>
              {noticeRows.map((notice) => (
                <tr
                  key={notice.id}
                  className="border-b border-zinc-100 last:border-b-0"
                >
                  <AdminTd className="font-mono text-xs">
                    {notice.copy_key}
                  </AdminTd>
                  <AdminTd>{notice.active ? "Yes" : "No"}</AdminTd>
                  <AdminTd>{notice.recipient_count}</AdminTd>
                  <AdminTd>{notice.unseen_count}</AdminTd>
                  <AdminTd className="text-zinc-500">
                    {new Date(notice.created_at).toLocaleString()}
                  </AdminTd>
                </tr>
              ))}
            </tbody>
          </AdminTable>
        </AdminSection>
      ) : null}

      {settings.length === 0 ? (
        <p className="rounded-xl border border-dashed border-zinc-300 bg-white px-4 py-8 text-center text-sm text-zinc-500">
          No settings returned. Ensure migrations are applied.
        </p>
      ) : (
        <SettingsForm settings={settings} />
      )}
    </div>
  );
}
