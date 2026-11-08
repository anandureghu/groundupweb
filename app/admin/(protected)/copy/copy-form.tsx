"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import {
  AdminField,
  AdminSection,
  adminControlClassName,
  adminTextareaClassName,
} from "@/components/admin/admin-ui";

import {
  saveAppCopy,
  type SettingsActionState,
} from "../settings/actions";

export type AppCopyRow = {
  key: string;
  title: string;
  body: string;
  description: string | null;
  updatedAt: string;
};

export function CopyForm({ entries }: { entries: AppCopyRow[] }) {
  return (
    <div className="flex flex-col gap-4">
      {entries.map((entry) => (
        <CopyCard key={entry.key} entry={entry} />
      ))}
      <NewCopyCard />
    </div>
  );
}

function CopyCard({ entry }: { entry: AppCopyRow }) {
  const [state, action, pending] = useActionState<
    SettingsActionState,
    FormData
  >(saveAppCopy, null);

  return (
    <AdminSection
      title={entry.key}
      description={entry.description ?? undefined}
    >
      <form action={action} className="flex flex-col gap-4">
        <input type="hidden" name="key" value={entry.key} />

        <AdminField label="Title" htmlFor={`${entry.key}-title`}>
          <input
            id={`${entry.key}-title`}
            name="title"
            defaultValue={entry.title}
            className={adminControlClassName}
          />
        </AdminField>

        <AdminField label="Body" htmlFor={`${entry.key}-body`}>
          <textarea
            id={`${entry.key}-body`}
            name="body"
            defaultValue={entry.body}
            rows={4}
            className={adminTextareaClassName}
          />
        </AdminField>

        <AdminField label="Description" htmlFor={`${entry.key}-desc`}>
          <input
            id={`${entry.key}-desc`}
            name="description"
            defaultValue={entry.description ?? ""}
            className={adminControlClassName}
          />
        </AdminField>

        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit" size="sm" disabled={pending} className="rounded-lg">
            {pending ? "Saving…" : "Save"}
          </Button>
          {state?.error ? (
            <p className="text-sm text-red-600">{state.error}</p>
          ) : null}
          {state?.success ? (
            <p className="text-sm text-emerald-700">{state.success}</p>
          ) : null}
        </div>
      </form>
    </AdminSection>
  );
}

function NewCopyCard() {
  const [state, action, pending] = useActionState<
    SettingsActionState,
    FormData
  >(saveAppCopy, null);

  return (
    <AdminSection
      title="Add copy entry"
      description="Create a new in-app message key."
    >
      <form action={action} className="flex flex-col gap-4">
        <AdminField label="Key" htmlFor="new-key">
          <input
            id="new-key"
            name="key"
            placeholder="my_message_key"
            required
            className={adminControlClassName}
          />
        </AdminField>
        <AdminField label="Title" htmlFor="new-title">
          <input id="new-title" name="title" className={adminControlClassName} />
        </AdminField>
        <AdminField label="Body" htmlFor="new-body">
          <textarea
            id="new-body"
            name="body"
            rows={3}
            className={adminTextareaClassName}
          />
        </AdminField>
        <AdminField label="Description" htmlFor="new-desc">
          <input
            id="new-desc"
            name="description"
            className={adminControlClassName}
          />
        </AdminField>
        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit" size="sm" disabled={pending} className="rounded-lg">
            {pending ? "Creating…" : "Create"}
          </Button>
          {state?.error ? (
            <p className="text-sm text-red-600">{state.error}</p>
          ) : null}
          {state?.success ? (
            <p className="text-sm text-emerald-700">{state.success}</p>
          ) : null}
        </div>
      </form>
    </AdminSection>
  );
}
