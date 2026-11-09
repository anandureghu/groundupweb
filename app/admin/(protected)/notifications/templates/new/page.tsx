import type { Metadata } from "next";

import { AdminPageHeader } from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";

import { NotificationSectionNav } from "../../section-nav";
import { TemplateForm } from "../template-form";

export const metadata: Metadata = {
  title: "New notification template",
};

export default async function NewNotificationTemplatePage() {
  await requireAdmin();

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="New template"
        description="Name, title, message, and who it is for."
        breadcrumb={{ href: "/admin/notifications/templates", label: "Templates" }}
      />
      <NotificationSectionNav />
      <TemplateForm />
    </div>
  );
}
