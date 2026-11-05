import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Unauthorized",
};

export default function AdminUnauthorizedPage() {
  return (
    <div className="flex min-h-screen w-full flex-col items-center justify-center gap-4 bg-background px-6 py-12 text-center">
      <h1 className="text-lg font-semibold text-foreground">
        You don&apos;t have admin access.
      </h1>
      <p className="text-sm text-muted-foreground">
        Sign in with a staff account that has admin access to continue.
      </p>
      <Link
        href="/admin/login"
        className="text-sm font-medium text-primary underline underline-offset-4 hover:no-underline"
      >
        Back to login
      </Link>
    </div>
  );
}
