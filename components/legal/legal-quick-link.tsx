import Link from "next/link";
import type { LegalLink } from "@/lib/legal/types";
import { cn } from "@/lib/utils";

interface LegalQuickLinkProps {
  link: LegalLink;
  className?: string;
}

export function LegalQuickLink({ link, className }: LegalQuickLinkProps) {
  const linkClassName = cn(
    "text-[15px] text-[#0066cc] underline underline-offset-2 hover:opacity-80 dark:text-[#2997ff]",
    className,
  );

  if (link.type === "page") {
    return (
      <Link href={link.href} className={linkClassName}>
        {link.label}
      </Link>
    );
  }

  if (link.type === "download") {
    return (
      <a href={link.href} className={linkClassName} download>
        {link.label}
      </a>
    );
  }

  return (
    <a href={link.href} className={linkClassName}>
      {link.label}
    </a>
  );
}
