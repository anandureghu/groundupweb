"use client";

import { useActionState, useEffect, useRef, useState } from "react";

import { Button } from "@/components/ui/button";
import {
  AdminField,
  AdminSection,
  adminControlClassName,
  adminSelectClassName,
  adminTextareaClassName,
} from "@/components/admin/admin-ui";
import {
  AUDIENCE_OPTIONS,
  BROADCAST_PLACEHOLDERS,
  selectionFromTemplate,
  type AudienceId,
} from "@/lib/admin/notifications";

import {
  previewBroadcastAudience,
  submitBroadcast,
  type NotificationActionState,
} from "./actions";

export type BroadcastTemplateOption = {
  id: string;
  name: string;
  title: string;
  body: string;
  audienceType: string;
  audienceSegment: string | null;
};

export function BroadcastComposer({
  templates,
}: {
  templates: BroadcastTemplateOption[];
}) {
  const [state, action, pending] = useActionState<
    NotificationActionState,
    FormData
  >(submitBroadcast, null);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState<AudienceId>("all");
  const [scheduledFor, setScheduledFor] = useState("");
  const [templateName, setTemplateName] = useState("");
  const [previewCount, setPreviewCount] = useState<number | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [previewing, setPreviewing] = useState(false);
  const focusedField = useRef<"title" | "body">("body");

  useEffect(() => {
    if (!state?.clearCompose) {
      return;
    }
    setTitle("");
    setBody("");
    setScheduledFor("");
    setTemplateName("");
    setPreviewCount(null);
  }, [state]);

  function insertPlaceholder(token: string) {
    if (focusedField.current === "title") {
      setTitle((current) => `${current}${token}`);
      return;
    }
    setBody((current) => `${current}${token}`);
  }

  function applyTemplate(id: string) {
    const template = templates.find((item) => item.id === id);
    if (!template) {
      return;
    }
    setTitle(template.title);
    setBody(template.body);
    setAudience(
      selectionFromTemplate(template.audienceType, template.audienceSegment),
    );
    setPreviewCount(null);
  }

  async function handlePreview() {
    setPreviewError(null);
    setPreviewing(true);
    const result = await previewBroadcastAudience(audience);
    setPreviewing(false);
    if (result?.error) {
      setPreviewCount(null);
      setPreviewError(result.error);
      return;
    }
    setPreviewCount(result?.previewCount ?? 0);
  }

  return (
    <AdminSection
      title="Compose notification"
      description="Message customers now or schedule for later. Preview counts people and does not send."
    >
      <form action={action} className="flex flex-col gap-4">
        <input type="hidden" name="audience" value={audience} />

        <div className="flex flex-wrap gap-2">
          <AdminField label="Use template" htmlFor="template-picker" className="min-w-56">
            <select
              id="template-picker"
              defaultValue=""
              onChange={(event) => applyTemplate(event.target.value)}
              className={adminSelectClassName}
            >
              <option value="" disabled>
                Choose a saved template
              </option>
              {templates.map((template) => (
                <option key={template.id} value={template.id}>
                  {template.name}
                </option>
              ))}
            </select>
          </AdminField>
        </div>

        <AdminField label="Title" htmlFor="broadcast-title">
          <input
            id="broadcast-title"
            name="title"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            onFocus={() => {
              focusedField.current = "title";
            }}
            className={adminControlClassName}
          />
        </AdminField>

        <AdminField label="Message" htmlFor="broadcast-body">
          <textarea
            id="broadcast-body"
            name="body"
            value={body}
            onChange={(event) => setBody(event.target.value)}
            onFocus={() => {
              focusedField.current = "body";
            }}
            className={adminTextareaClassName}
          />
        </AdminField>

        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs text-zinc-500">Placeholders</span>
          {BROADCAST_PLACEHOLDERS.map((placeholder) => (
            <button
              key={placeholder.token}
              type="button"
              onClick={() => insertPlaceholder(placeholder.token)}
              className="rounded-full border border-zinc-300 px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50"
              title={placeholder.description}
            >
              {placeholder.token}
            </button>
          ))}
        </div>

        <fieldset className="flex flex-col gap-2">
          <legend className="text-sm font-medium text-zinc-700">Audience</legend>
          <div className="flex flex-wrap gap-2">
            {AUDIENCE_OPTIONS.map((option) => {
              const selected = audience === option.id;
              return (
                <button
                  key={option.id}
                  type="button"
                  onClick={() => {
                    setAudience(option.id);
                    setPreviewCount(null);
                  }}
                  className={
                    selected
                      ? "rounded-full bg-zinc-900 px-3 py-1.5 text-sm font-medium text-white"
                      : "rounded-full border border-zinc-300 bg-white px-3 py-1.5 text-sm font-medium text-zinc-700 hover:bg-zinc-50"
                  }
                  aria-pressed={selected}
                >
                  {option.label}
                </button>
              );
            })}
          </div>
        </fieldset>

        <div className="flex flex-wrap items-end gap-3">
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="rounded-lg"
            disabled={previewing}
            onClick={() => {
              void handlePreview();
            }}
          >
            {previewing ? "Counting…" : "Preview recipients"}
          </Button>
          {previewCount !== null ? (
            <p className="text-sm text-zinc-700">
              Estimated recipients: <span className="font-semibold">{previewCount}</span>
            </p>
          ) : null}
          {previewError ? <p className="text-sm text-red-600">{previewError}</p> : null}
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <AdminField label="Schedule for" htmlFor="broadcast-schedule">
            <input
              id="broadcast-schedule"
              name="scheduledFor"
              type="datetime-local"
              value={scheduledFor}
              onChange={(event) => setScheduledFor(event.target.value)}
              className={adminControlClassName}
            />
          </AdminField>
          <AdminField
            label="Template name"
            htmlFor="broadcast-template-name"
            hint="Used only when you save this draft as a template."
          >
            <input
              id="broadcast-template-name"
              name="templateName"
              value={templateName}
              onChange={(event) => setTemplateName(event.target.value)}
              className={adminControlClassName}
            />
          </AdminField>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Button
            type="submit"
            name="intent"
            value="send"
            size="sm"
            className="rounded-lg"
            disabled={pending}
          >
            {pending ? "Working…" : "Send now"}
          </Button>
          <Button
            type="submit"
            name="intent"
            value="schedule"
            variant="outline"
            size="sm"
            className="rounded-lg"
            disabled={pending}
          >
            Schedule
          </Button>
          <Button
            type="submit"
            name="intent"
            value="save-template"
            variant="secondary"
            size="sm"
            className="rounded-lg"
            disabled={pending}
          >
            Save as template
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
