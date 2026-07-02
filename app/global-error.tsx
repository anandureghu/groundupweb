"use client";

import { useEffect } from "react";
import Link from "next/link";
import "./globals.css";
import { Button } from "@/components/ui/button";
import { StatusPage } from "@/components/site/status-page";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <html lang="en">
      <body className="min-h-full bg-background font-sans text-foreground antialiased">
        <StatusPage
          code="Error"
          title="Something went wrong"
          description="A critical error occurred. Please try again, or return to the home page."
          actions={
            <>
              <Button onClick={reset}>Try again</Button>
              <Button asChild variant="outline">
                <Link href="/">Back to home</Link>
              </Button>
            </>
          }
        />
      </body>
    </html>
  );
}
