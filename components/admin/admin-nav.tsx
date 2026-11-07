"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { signOutAdmin } from "@/app/admin/sign-out-action";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const NAV_LINKS = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/customers", label: "Customers" },
  { href: "/admin/staff", label: "Staff" },
  { href: "/admin/settings", label: "Settings" },
  { href: "/admin/copy", label: "Copy" },
  { href: "/admin/audit-log", label: "Audit log" },
] as const;

export function AdminNav({ email }: { email: string }) {
  const pathname = usePathname();

  return (
    <nav className="flex h-full w-60 shrink-0 flex-col justify-between border-r border-sidebar-border bg-sidebar px-4 py-6">
      <div className="flex flex-col gap-6">
        <span className="px-2 text-sm font-semibold tracking-wider text-sidebar-foreground uppercase">
          Admin
        </span>

        <ul className="flex flex-col gap-1">
          {NAV_LINKS.map((link) => {
            const isActive =
              link.href === "/admin"
                ? pathname === "/admin"
                : pathname.startsWith(link.href);

            return (
              <li key={link.href}>
                <Link
                  href={link.href}
                  className={cn(
                    "block rounded-none px-2 py-2 text-sm font-medium text-sidebar-foreground/70 transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
                    isActive &&
                      "bg-sidebar-accent text-sidebar-accent-foreground",
                  )}
                >
                  {link.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </div>

      <div className="flex flex-col gap-3 border-t border-sidebar-border pt-4">
        <span className="truncate px-2 text-xs text-muted-foreground">
          {email}
        </span>
        <form action={signOutAdmin}>
          <Button type="submit" variant="outline" size="sm" className="w-full">
            Sign out
          </Button>
        </form>
      </div>
    </nav>
  );
}
