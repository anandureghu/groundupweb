"use client";

import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { Button } from "@/components/ui/button";

const CODE_STORAGE_KEY = "groundup_pending_referral_code";
const CODE_PATTERN = /^GS-[A-Z0-9]{6}$/;

function normalizeCode(raw: string | null) {
  if (!raw) return "";
  return raw.trim().toUpperCase();
}

export function DownloadInviteClient() {
  const searchParams = useSearchParams();
  const [code, setCode] = useState("");

  useEffect(() => {
    const fromQuery = normalizeCode(searchParams.get("code"));
    if (fromQuery && CODE_PATTERN.test(fromQuery)) {
      setCode(fromQuery);
      try {
        localStorage.setItem(CODE_STORAGE_KEY, fromQuery);
        document.cookie = `${CODE_STORAGE_KEY}=${encodeURIComponent(fromQuery)}; path=/; max-age=${60 * 60 * 24 * 30}; samesite=lax`;
      } catch {
        // ignore storage failures
      }
      return;
    }

    try {
      const stored = normalizeCode(localStorage.getItem(CODE_STORAGE_KEY));
      if (stored && CODE_PATTERN.test(stored)) {
        setCode(stored);
      }
    } catch {
      // ignore
    }
  }, [searchParams]);

  const deepLink = useMemo(
    () =>
      code
        ? `groundup://refer?code=${encodeURIComponent(code)}`
        : "groundup://",
    [code],
  );

  return (
    <div className="flex w-full flex-col items-center gap-3">
      {code ? (
        <>
          <p className="text-sm text-muted-foreground">
            You&apos;re invited with staff code
          </p>
          <p className="text-lg font-semibold tracking-widest">{code}</p>
        </>
      ) : (
        <p className="text-sm text-muted-foreground">
          Early joiners: download the app, then sign up with your staff invite
          code.
        </p>
      )}
      <Button asChild className="w-full">
        <a href={deepLink}>Open app</a>
      </Button>
    </div>
  );
}
