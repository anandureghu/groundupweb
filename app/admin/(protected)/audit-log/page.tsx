import type { Metadata } from "next";
import Link from "next/link";

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
      <div>
        <h1 className="text-2xl font-semibold">Audit log</h1>
        <p className="text-sm text-muted-foreground">
          {rows.length} entr{rows.length === 1 ? "y" : "ies"}
        </p>
      </div>

      <div className="overflow-x-auto border border-border">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-border bg-muted/40">
            <tr>
              <th className="px-4 py-3 font-semibold">Timestamp</th>
              <th className="px-4 py-3 font-semibold">Actor</th>
              <th className="px-4 py-3 font-semibold">Action</th>
              <th className="px-4 py-3 font-semibold">Entity</th>
              <th className="px-4 py-3 font-semibold">Metadata</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr>
                <td
                  colSpan={5}
                  className="px-4 py-6 text-center text-muted-foreground"
                >
                  No audit log entries found.
                </td>
              </tr>
            ) : (
              rows.map((row) => (
                <tr
                  key={row.id}
                  className="border-b border-border last:border-b-0 align-top"
                >
                  <td className="whitespace-nowrap px-4 py-3">
                    {new Date(row.created_at).toLocaleString()}
                  </td>
                  <td className="px-4 py-3">{row.actor_email}</td>
                  <td className="px-4 py-3">{row.action}</td>
                  <td className="px-4 py-3">
                    {row.entity_type}
                    {row.entity_id ? ` / ${row.entity_id}` : ""}
                  </td>
                  <td className="px-4 py-3">
                    <details>
                      <summary className="cursor-pointer text-muted-foreground">
                        View
                      </summary>
                      <pre className="mt-2 max-w-sm overflow-x-auto whitespace-pre-wrap text-xs">
                        {JSON.stringify(row.metadata ?? {}, null, 2)}
                      </pre>
                    </details>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {nextCursor ? (
        <Link
          href={`/admin/audit-log?before=${encodeURIComponent(nextCursor)}`}
          className="text-sm font-medium text-primary hover:underline"
        >
          Load more
        </Link>
      ) : null}
    </div>
  );
}
