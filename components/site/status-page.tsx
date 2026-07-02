import type { ReactNode } from "react";
import { SiteHeader } from "./site-header";

interface StatusPageProps {
  code?: string;
  title: string;
  description: string;
  children?: ReactNode;
  actions?: ReactNode;
}

export function StatusPage({
  code,
  title,
  description,
  children,
  actions,
}: StatusPageProps) {
  return (
    <div className="min-h-full bg-background">
      <SiteHeader />
      <main className="mx-auto flex min-h-[calc(100vh-3.5rem)] max-w-3xl flex-col items-center justify-center px-6 py-16 text-center">
        {code && (
          <p className="mb-2 text-sm font-semibold tracking-widest text-muted-foreground uppercase">
            {code}
          </p>
        )}
        <h1 className="mb-4 text-3xl font-semibold tracking-tight md:text-4xl">
          {title}
        </h1>
        <p className="mb-8 max-w-md text-[15px] leading-relaxed text-muted-foreground">
          {description}
        </p>
        {children}
        {actions && (
          <div className="flex flex-wrap items-center justify-center gap-3">
            {actions}
          </div>
        )}
      </main>
    </div>
  );
}
