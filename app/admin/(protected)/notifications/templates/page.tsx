import type { Metadata } from "next";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import {
  AdminPageHeader,
  AdminTable,
  AdminTableHead,
  AdminTd,
  AdminTh,
} from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { audienceLabel, rowsOf } from "@/lib/admin/notifications";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { NotificationSectionNav } from "../section-nav";
import { DeleteTemplateButton } from "./delete-template-button";

export const metadata: Metadata = {
  title: "Notification templates",
};

type TemplateRpcRow = {
  id: string;
  name: string;
  title: string;
  audience_type: string;
  audience_segment: string | null;
  updated_at: string;
};

export default async function NotificationTemplatesPage() {
  await requireAdmin();
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("list_notification_templates");

  if (error) {
    console.error("list_notification_templates failed", error);
  }

  const templates = rowsOf<TemplateRpcRow>(data);

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Notification templates"
        description="Save broadcast copy to reuse and resend later."
        actions={
          <Button asChild size="sm" className="rounded-lg">
            <Link href="/admin/notifications/templates/new">New template</Link>
          </Button>
        }
      />
      <NotificationSectionNav />

      {error ? (
        <p className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error.message}
        </p>
      ) : null}

      {templates.length === 0 ? (
        <p className="rounded-xl border border-dashed border-zinc-300 bg-white px-4 py-8 text-center text-sm text-zinc-500">
          No templates yet. Create one or save from Send.
        </p>
      ) : (
        <AdminTable>
          <AdminTableHead>
            <tr>
              <AdminTh>Name</AdminTh>
              <AdminTh>Title</AdminTh>
              <AdminTh>Audience</AdminTh>
              <AdminTh>Updated</AdminTh>
              <AdminTh />
            </tr>
          </AdminTableHead>
          <tbody>
            {templates.map((template) => (
              <tr
                key={template.id}
                className="border-b border-zinc-100 last:border-b-0"
              >
                <AdminTd className="font-medium text-zinc-900">
                  {template.name}
                </AdminTd>
                <AdminTd>{template.title}</AdminTd>
                <AdminTd>
                  {audienceLabel(
                    template.audience_type,
                    template.audience_segment
                      ? { segment: template.audience_segment }
                      : {},
                  )}
                </AdminTd>
                <AdminTd className="text-zinc-500">
                  {new Date(template.updated_at).toLocaleString()}
                </AdminTd>
                <AdminTd>
                  <div className="flex items-center justify-end gap-3">
                    <Link
                      href={`/admin/notifications/templates/${template.id}`}
                      className="text-sm font-medium text-zinc-900 underline-offset-2 hover:underline"
                    >
                      Edit
                    </Link>
                    <DeleteTemplateButton id={template.id} name={template.name} />
                  </div>
                </AdminTd>
              </tr>
            ))}
          </tbody>
        </AdminTable>
      )}
    </div>
  );
}
