"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";

import { disableCustomer, enableCustomer } from "../actions";

export function CustomerStatusAction({
  customerId,
  isActive,
}: {
  customerId: string;
  isActive: boolean;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function handleClick() {
    setError(null);

    startTransition(async () => {
      const result = isActive
        ? await disableCustomer(customerId)
        : await enableCustomer(customerId);

      if (result?.error) {
        setError(result.error);
        return;
      }

      router.refresh();
    });
  }

  return (
    <div className="flex flex-col items-start gap-2">
      <Button
        type="button"
        variant={isActive ? "destructive" : "default"}
        onClick={handleClick}
        disabled={pending}
      >
        {pending
          ? "Working…"
          : isActive
            ? "Disable customer"
            : "Enable customer"}
      </Button>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  );
}
