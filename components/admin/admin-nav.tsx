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
  { href: "/admin/products", label: "Products" },
  { href: "/admin/challenges", label: "Challenges" },
  { href: "/admin/notifications", label: "Notifications" },
  { href: "/admin/settings", label: "Settings" },
  { href: "/admin/copy", label: "Copy" },
  { href: "/admin/audit-log", label: "Audit log" },
] as const;

export function AdminNav({ email }: { email: string }) {
  const pathname = usePathname();

  return (
    <nav className="sticky top-0 flex h-dvh w-60 shrink-0 flex-col justify-between overflow-y-auto border-r border-zinc-200 bg-white px-3 py-5">
      <div className="flex flex-col gap-5">
        <div className="px-2">
          <p className="text-xs font-semibold tracking-wider text-zinc-400 uppercase">
            Ground Up
          </p>
          <p className="text-sm font-semibold text-zinc-900">Admin</p>
        </div>

        <ul className="flex flex-col gap-0.5">
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
                    "block rounded-lg px-3 py-2 text-sm font-medium text-zinc-600 transition-colors hover:bg-zinc-100 hover:text-zinc-900",
                    isActive && "bg-zinc-900 text-white hover:bg-zinc-800 hover:text-white",
                  )}
                >
                  {link.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </div>

      <div className="flex flex-col gap-3 border-t border-zinc-200 px-1 pt-4">
        <span className="truncate px-2 text-xs text-zinc-500">{email}</span>
        <form action={signOutAdmin}>
          <Button
            type="submit"
            variant="outline"
            size="sm"
            className="w-full rounded-lg border-zinc-300"
          >
            Sign out
          </Button>
        </form>
      </div>
    </nav>
  );
}
