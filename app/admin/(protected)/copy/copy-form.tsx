"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

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
    <div className="flex flex-col gap-6">
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
    <form
      action={action}
      className="flex flex-col gap-3 border border-border p-4"
    >
      <input type="hidden" name="key" value={entry.key} />
      <div className="flex flex-col gap-1">
        <p className="font-mono text-sm font-semibold">{entry.key}</p>
        {entry.description ? (
          <p className="text-xs text-muted-foreground">{entry.description}</p>
        ) : null}
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${entry.key}-title`}>Title</Label>
        <Input
          id={`${entry.key}-title`}
          name="title"
          defaultValue={entry.title}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${entry.key}-body`}>Body</Label>
        <textarea
          id={`${entry.key}-body`}
          name="body"
          defaultValue={entry.body}
          rows={4}
          className="border-input bg-background ring-offset-background placeholder:text-muted-foreground focus-visible:ring-ring flex min-h-[96px] w-full rounded-none border px-3 py-2 text-sm focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${entry.key}-desc`}>Description</Label>
        <Input
          id={`${entry.key}-desc`}
          name="description"
          defaultValue={entry.description ?? ""}
        />
      </div>

      <div className="flex items-center gap-3">
        <Button type="submit" size="sm" disabled={pending}>
          {pending ? "Saving…" : "Save"}
        </Button>
        {state?.error ? (
          <p className="text-sm text-destructive">{state.error}</p>
        ) : null}
        {state?.success ? (
          <p className="text-sm text-muted-foreground">{state.success}</p>
        ) : null}
      </div>
    </form>
  );
}

function NewCopyCard() {
  const [state, action, pending] = useActionState<
    SettingsActionState,
    FormData
  >(saveAppCopy, null);

  return (
    <form
      action={action}
      className="flex flex-col gap-3 border border-dashed border-border p-4"
    >
      <p className="text-sm font-semibold">Add copy entry</p>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="new-key">Key</Label>
        <Input id="new-key" name="key" placeholder="my_message_key" required />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="new-title">Title</Label>
        <Input id="new-title" name="title" />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="new-body">Body</Label>
        <textarea
          id="new-body"
          name="body"
          rows={3}
          className="border-input bg-background ring-offset-background placeholder:text-muted-foreground focus-visible:ring-ring flex min-h-[80px] w-full rounded-none border px-3 py-2 text-sm focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="new-desc">Description</Label>
        <Input id="new-desc" name="description" />
      </div>
      <div className="flex items-center gap-3">
        <Button type="submit" size="sm" disabled={pending}>
          {pending ? "Creating…" : "Create"}
        </Button>
        {state?.error ? (
          <p className="text-sm text-destructive">{state.error}</p>
        ) : null}
        {state?.success ? (
          <p className="text-sm text-muted-foreground">{state.success}</p>
        ) : null}
      </div>
    </form>
  );
}
