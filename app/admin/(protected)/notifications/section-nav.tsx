"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@/lib/utils";

const LINKS = [
  { href: "/admin/notifications", label: "Send", exact: true },
  { href: "/admin/notifications/templates", label: "Templates", exact: false },
  { href: "/admin/notifications/settings", label: "Settings", exact: false },
] as const;

export function NotificationSectionNav() {
  const pathname = usePathname();

  return (
    <div className="flex flex-wrap gap-2">
      {LINKS.map((link) => {
        const active = link.exact
          ? pathname === link.href
          : pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            className={cn(
              "rounded-full border border-zinc-300 bg-white px-3 py-1.5 text-sm font-medium text-zinc-700 hover:bg-zinc-50",
              active && "border-zinc-900 bg-zinc-900 text-white hover:bg-zinc-800",
            )}
          >
            {link.label}
          </Link>
        );
      })}
    </div>
  );
}
