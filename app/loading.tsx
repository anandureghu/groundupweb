import { SiteHeader } from "@/components/site/site-header";

export default function Loading() {
  return (
    <div className="min-h-full bg-background">
      <SiteHeader />
      <main className="flex min-h-[calc(100vh-3.5rem)] items-center justify-center">
        <p className="text-sm tracking-wide text-muted-foreground uppercase">
          Loading
        </p>
      </main>
    </div>
  );
}
