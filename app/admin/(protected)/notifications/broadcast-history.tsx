"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import {
  AdminSection,
  AdminTable,
  AdminTableHead,
  AdminTd,
  AdminTh,
} from "@/components/admin/admin-ui";
import {
  audienceLabel,
  broadcastStatusLabel,
  canCancelBroadcast,
} from "@/lib/admin/notifications";

import { cancelBroadcast, type NotificationActionState } from "./actions";

export type BroadcastHistoryRow = {
  id: string;
  title: string;
  audienceType: string;
  audienceFilter: Record<string, unknown>;
  status: string;
  recipientCount: number;
  scheduledFor: string | null;
  sentAt: string | null;
  createdAt: string;
};

function formatWhen(row: BroadcastHistoryRow): string {
  const stamp = row.sentAt ?? row.scheduledFor ?? row.createdAt;
  return new Date(stamp).toLocaleString();
}

function CancelBroadcastButton({ id }: { id: string }) {
  const [state, action, pending] = useActionState<
    NotificationActionState,
    FormData
  >(cancelBroadcast, null);

  return (
    <form action={action} className="flex flex-col items-end gap-1">
      <input type="hidden" name="id" value={id} />
      <Button
        type="submit"
        variant="outline"
        size="sm"
        className="rounded-lg"
        disabled={pending}
      >
        {pending ? "Cancelling…" : "Cancel scheduled"}
      </Button>
      {state?.error ? <p className="text-xs text-red-600">{state.error}</p> : null}
    </form>
  );
}

export function BroadcastHistory({ rows }: { rows: BroadcastHistoryRow[] }) {
  return (
    <AdminSection
      title="Broadcast history"
      description="Sent and scheduled messages. Cancel is available until a scheduled message starts sending."
    >
      {rows.length === 0 ? (
        <p className="text-sm text-zinc-500">No broadcasts yet.</p>
      ) : (
        <AdminTable className="border-0 shadow-none">
          <AdminTableHead>
            <tr>
              <AdminTh>Title</AdminTh>
              <AdminTh>Audience</AdminTh>
              <AdminTh>Status</AdminTh>
              <AdminTh>Recipients</AdminTh>
              <AdminTh>When</AdminTh>
              <AdminTh />
            </tr>
          </AdminTableHead>
          <tbody>
            {rows.map((row) => (
              <tr
                key={row.id}
                className="border-b border-zinc-100 last:border-b-0"
              >
                <AdminTd className="max-w-xs font-medium text-zinc-900">
                  {row.title}
                </AdminTd>
                <AdminTd>
                  {audienceLabel(row.audienceType, row.audienceFilter, row.recipientCount)}
                </AdminTd>
                <AdminTd>{broadcastStatusLabel(row.status)}</AdminTd>
                <AdminTd>{row.recipientCount}</AdminTd>
                <AdminTd className="text-zinc-500">{formatWhen(row)}</AdminTd>
                <AdminTd className="text-right">
                  {canCancelBroadcast(row.status) ? (
                    <CancelBroadcastButton id={row.id} />
                  ) : null}
                </AdminTd>
              </tr>
            ))}
          </tbody>
        </AdminTable>
      )}
    </AdminSection>
  );
}
