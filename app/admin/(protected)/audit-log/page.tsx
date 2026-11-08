import type { Metadata } from "next";
import Link from "next/link";

import {
  AdminPageHeader,
  AdminTable,
  AdminTableHead,
  AdminTd,
  AdminTh,
} from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { nextAuditLogCursor } from "@/lib/admin/audit-log-pagination";

export const metadata: Metadata = {
  title: "Audit log",
};

const PAGE_SIZE = 50;

type ListAdminAuditLogRow = {
  id: string;
  actor_email: string;
  action: string;
  entity_type: string;
  entity_id: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
};

export default async function AdminAuditLogPage({
  searchParams,
}: {
  searchParams: Promise<{ before?: string }>;
}) {
  await requireAdmin();

  const { before } = await searchParams;

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("list_admin_audit_log", {
    p_limit: PAGE_SIZE,
    p_before: before ?? null,
  });

  if (error) {
    console.error("list_admin_audit_log failed", error);
  }

  const rows = (data as ListAdminAuditLogRow[] | null) ?? [];
  const nextCursor = nextAuditLogCursor(rows);

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Audit log"
        description={`${rows.length} entr${rows.length === 1 ? "y" : "ies"} on this page`}
      />

      <AdminTable>
        <AdminTableHead>
          <tr>
            <AdminTh>Timestamp</AdminTh>
            <AdminTh>Actor</AdminTh>
            <AdminTh>Action</AdminTh>
            <AdminTh>Entity</AdminTh>
            <AdminTh>Metadata</AdminTh>
          </tr>
        </AdminTableHead>
        <tbody>
          {rows.length === 0 ? (
            <tr>
              <td
                colSpan={5}
                className="px-4 py-8 text-center text-sm text-zinc-500"
              >
                No audit log entries found.
              </td>
            </tr>
          ) : (
            rows.map((row) => (
              <tr
                key={row.id}
                className="border-b border-zinc-100 last:border-b-0 align-top"
              >
                <AdminTd className="whitespace-nowrap">
                  {new Date(row.created_at).toLocaleString()}
                </AdminTd>
                <AdminTd>{row.actor_email}</AdminTd>
                <AdminTd>{row.action}</AdminTd>
                <AdminTd>
                  {row.entity_type}
                  {row.entity_id ? ` / ${row.entity_id}` : ""}
                </AdminTd>
                <AdminTd>
                  <details>
                    <summary className="cursor-pointer text-zinc-500">
                      View
                    </summary>
                    <pre className="mt-2 max-w-sm overflow-x-auto whitespace-pre-wrap text-xs text-zinc-700">
                      {JSON.stringify(row.metadata ?? {}, null, 2)}
                    </pre>
                  </details>
                </AdminTd>
              </tr>
            ))
          )}
        </tbody>
      </AdminTable>

      {nextCursor ? (
        <Link
          href={`/admin/audit-log?before=${encodeURIComponent(nextCursor)}`}
          className="text-sm font-medium text-zinc-900 underline-offset-2 hover:underline"
        >
          Load more
        </Link>
      ) : null}
    </div>
  );
}
