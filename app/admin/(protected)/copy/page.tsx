import type { Metadata } from "next";

import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { CopyForm, type AppCopyRow } from "./copy-form";

export const metadata: Metadata = {
  title: "Copy",
};

type ListAppCopyRow = {
  key: string;
  title: string;
  body: string;
  description: string | null;
  updated_at: string;
};

export default async function AdminCopyPage() {
  await requireAdmin();
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("admin_list_app_copy");

  if (error) {
    console.error("admin_list_app_copy failed", error);
  }

  const entries: AppCopyRow[] = ((data as ListAppCopyRow[] | null) ?? []).map(
    (row) => ({
      key: row.key,
      title: row.title,
      body: row.body,
      description: row.description,
      updatedAt: row.updated_at,
    }),
  );

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">App copy</h1>
        <p className="text-sm text-muted-foreground">
          Editable titles and bodies for in-app messages (notices, version gate,
          and future prompts).
        </p>
      </div>

      <CopyForm entries={entries} />
    </div>
  );
}
