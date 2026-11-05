"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";

import { disableStaff, enableStaff } from "../actions";

export function StaffStatusAction({
  staffId,
  isActive,
}: {
  staffId: string;
  isActive: boolean;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function handleClick() {
    setError(null);

    startTransition(async () => {
      const result = isActive
        ? await disableStaff(staffId)
        : await enableStaff(staffId);

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
            ? "Disable staff member"
            : "Enable staff member"}
      </Button>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  );
}
