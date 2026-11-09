import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { AdminPageHeader } from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { isAudienceId, rowsOf, selectionFromTemplate } from "@/lib/admin/notifications";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { NotificationSectionNav } from "../../section-nav";
import { DeleteTemplateButton } from "../delete-template-button";
import { TemplateForm } from "../template-form";

export const metadata: Metadata = {
  title: "Edit notification template",
};

type TemplateRpcRow = {
  id: string;
  name: string;
  title: string;
  body: string;
  audience_type: string;
  audience_segment: string | null;
};

export default async function EditNotificationTemplatePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireAdmin();
  const { id } = await params;
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("list_notification_templates");

  if (error) {
    console.error("list_notification_templates failed", error);
  }

  const template = rowsOf<TemplateRpcRow>(data).find((row) => row.id === id);
  if (!template) {
    notFound();
  }

  const audience = selectionFromTemplate(
    template.audience_type,
    template.audience_segment && isAudienceId(template.audience_segment)
      ? template.audience_segment
      : null,
  );

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title={template.name}
        description="Update this template or delete it."
        breadcrumb={{ href: "/admin/notifications/templates", label: "Templates" }}
        actions={<DeleteTemplateButton id={template.id} name={template.name} />}
      />
      <NotificationSectionNav />
      <TemplateForm
        id={template.id}
        name={template.name}
        title={template.title}
        body={template.body}
        audience={audience}
      />
    </div>
  );
}
