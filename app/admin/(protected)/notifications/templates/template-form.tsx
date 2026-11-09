"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import {
  AdminField,
  AdminSection,
  adminControlClassName,
  adminTextareaClassName,
} from "@/components/admin/admin-ui";
import { AUDIENCE_OPTIONS, type AudienceId } from "@/lib/admin/notifications";

import { saveNotificationTemplate, type NotificationActionState } from "../actions";

export function TemplateForm({
  id,
  name,
  title,
  body,
  audience,
}: {
  id?: string;
  name?: string;
  title?: string;
  body?: string;
  audience?: AudienceId;
}) {
  const [state, action, pending] = useActionState<
    NotificationActionState,
    FormData
  >(saveNotificationTemplate, null);

  return (
    <AdminSection
      title={id ? "Edit template" : "New template"}
      description="Save broadcast copy to reuse and resend later."
    >
      <form action={action} className="flex flex-col gap-4">
        {id ? <input type="hidden" name="id" value={id} /> : null}

        <AdminField label="Template name" htmlFor="template-name">
          <input
            id="template-name"
            name="name"
            required
            defaultValue={name ?? ""}
            className={adminControlClassName}
          />
        </AdminField>
        <AdminField label="Title" htmlFor="template-title">
          <input
            id="template-title"
            name="title"
            required
            defaultValue={title ?? ""}
            className={adminControlClassName}
          />
        </AdminField>
        <AdminField label="Message" htmlFor="template-body">
          <textarea
            id="template-body"
            name="body"
            required
            defaultValue={body ?? ""}
            className={adminTextareaClassName}
          />
        </AdminField>

        <fieldset className="flex flex-col gap-2">
          <legend className="text-sm font-medium text-zinc-700">Audience</legend>
          <div className="flex flex-wrap gap-3">
            {AUDIENCE_OPTIONS.map((option) => (
              <label
                key={option.id}
                className="flex cursor-pointer items-center gap-2 rounded-lg border border-zinc-200 px-3 py-2 text-sm text-zinc-800"
              >
                <input
                  type="radio"
                  name="audience"
                  value={option.id}
                  defaultChecked={(audience ?? "all") === option.id}
                />
                {option.label}
              </label>
            ))}
          </div>
        </fieldset>

        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit" size="sm" className="rounded-lg" disabled={pending}>
            {pending ? "Saving…" : "Save"}
          </Button>
          {state?.error ? <p className="text-sm text-red-600">{state.error}</p> : null}
          {state?.success ? (
            <p className="text-sm text-emerald-700">{state.success}</p>
          ) : null}
        </div>
      </form>
    </AdminSection>
  );
}
