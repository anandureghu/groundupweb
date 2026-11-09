"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";

import { deleteNotificationTemplate, type NotificationActionState } from "../actions";

export function DeleteTemplateButton({
  id,
  name,
}: {
  id: string;
  name: string;
}) {
  const [state, action, pending] = useActionState<
    NotificationActionState,
    FormData
  >(deleteNotificationTemplate, null);

  return (
    <form
      action={action}
      onSubmit={(event) => {
        if (!window.confirm(`Delete this template?\n${name}`)) {
          event.preventDefault();
        }
      }}
    >
      <input type="hidden" name="id" value={id} />
      <Button
        type="submit"
        variant="destructive"
        size="sm"
        className="rounded-lg"
        disabled={pending}
      >
        {pending ? "Deleting…" : "Delete template"}
      </Button>
      {state?.error ? (
        <p className="mt-2 text-sm text-red-600">{state.error}</p>
      ) : null}
    </form>
  );
}
