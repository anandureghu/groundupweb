"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";

import { confirmCustomerEmail } from "../actions";

export function CustomerEmailAction({
  customerId,
  emailConfirmed,
  emailConfirmedAt,
}: {
  customerId: string;
  emailConfirmed: boolean;
  emailConfirmedAt: string | null;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function handleConfirm() {
    setError(null);

    startTransition(async () => {
      const result = await confirmCustomerEmail(customerId);
      if (result?.error) {
        setError(result.error);
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="flex flex-col items-start gap-2">
      <div className="flex flex-wrap items-center gap-3">
        <span
          className={
            emailConfirmed
              ? "inline-flex rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-medium text-emerald-800"
              : "inline-flex rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-900"
          }
        >
          {emailConfirmed ? "Email verified" : "Email not verified"}
        </span>
        {emailConfirmed && emailConfirmedAt ? (
          <span className="text-xs text-muted-foreground">
            Confirmed {new Date(emailConfirmedAt).toLocaleString()}
          </span>
        ) : null}
        {!emailConfirmed ? (
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={handleConfirm}
            disabled={pending}
          >
            {pending ? "Working…" : "Mark email verified"}
          </Button>
        ) : null}
      </div>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  );
}
