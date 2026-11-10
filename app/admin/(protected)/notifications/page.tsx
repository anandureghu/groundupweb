import type { Metadata } from "next";

import { AdminPageHeader } from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { rowsOf } from "@/lib/admin/notifications";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { BroadcastComposer, type BroadcastTemplateOption } from "./broadcast-composer";
import type { NotificationMember } from "./member-picker";
import { BroadcastHistory, type BroadcastHistoryRow } from "./broadcast-history";
import { NotificationSectionNav } from "./section-nav";

export const metadata: Metadata = {
  title: "Notifications",
};

type BroadcastRpcRow = {
  id: string;
  title: string;
  audience_type: string;
  audience_filter: Record<string, unknown> | null;
  status: string;
  recipient_count: number;
  scheduled_for: string | null;
  sent_at: string | null;
  created_at: string;
};

type TemplateRpcRow = {
  id: string;
  name: string;
  title: string;
  body: string;
  audience_type: string;
  audience_segment: string | null;
};

export default async function AdminNotificationsPage() {
  await requireAdmin();
  const supabase = await createServerSupabaseClient();
  const [
    { data: broadcasts, error: broadcastsError },
    { data: templates, error: templatesError },
    { data: customers, error: customersError },
  ] = await Promise.all([
    supabase.rpc("list_admin_broadcasts"),
    supabase.rpc("list_notification_templates"),
    supabase.rpc("list_customers"),
  ]);

  if (broadcastsError) {
    console.error("list_admin_broadcasts failed", broadcastsError);
  }
  if (templatesError) {
    console.error("list_notification_templates failed", templatesError);
  }
  if (customersError) {
    console.error("list_customers failed", customersError);
  }

  const members: NotificationMember[] = rowsOf<{
    id: string;
    first_name: string | null;
    last_name: string | null;
    email: string | null;
    is_active: boolean | null;
  }>(customers)
    .filter((row) => row.is_active !== false)
    .map((row) => ({
      id: row.id,
      name: `${row.first_name ?? ""} ${row.last_name ?? ""}`.trim(),
      email: row.email ?? "",
    }));

  const history: BroadcastHistoryRow[] = rowsOf<BroadcastRpcRow>(broadcasts).map((row) => ({
    id: row.id,
    title: row.title,
    audienceType: row.audience_type,
    audienceFilter: row.audience_filter ?? {},
    status: row.status,
    recipientCount: row.recipient_count,
    scheduledFor: row.scheduled_for,
    sentAt: row.sent_at,
    createdAt: row.created_at,
  }));

  const templateOptions: BroadcastTemplateOption[] = rowsOf<TemplateRpcRow>(templates).map((row) => ({
    id: row.id,
    name: row.name,
    title: row.title,
    body: row.body,
    audienceType: row.audience_type,
    audienceSegment: row.audience_segment,
  }));

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Send notification"
        description="Message everyone, a group, or specific members."
      />
      <NotificationSectionNav />
      {broadcastsError || templatesError || customersError ? (
        <p className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {broadcastsError?.message ?? templatesError?.message ?? customersError?.message}
        </p>
      ) : null}
      <BroadcastComposer templates={templateOptions} members={members} />
      <BroadcastHistory rows={history} />
    </div>
  );
}
