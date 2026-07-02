import Image from "next/image";
import { ThemeToggle } from "./components/theme-toggle";
import { Button } from "@/components/ui/button";
import Link from "next/link";

export default function Home() {
  const footerLinks = [
    {
      label: "Privacy",
      href: "/privacy",
    },
    {
      label: "Terms",
      href: "/terms",
    },
    {
      label: "Contact",
      href: "/contact",
    },
  ];
  return (
    <main className="relative flex min-h-full flex-1 items-center justify-center bg-background">
      <ThemeToggle />
      <Image
        src="/assets/logo/logo-dark.svg"
        alt="Ground Up"
        width={691}
        height={167}
        priority
        className="h-auto w-[min(80vw,320px)] dark:hidden"
      />
      <Image
        src="/assets/logo/logo-light.svg"
        alt=""
        width={691}
        height={167}
        priority
        aria-hidden
        className="hidden h-auto w-[min(80vw,320px)] dark:block"
      />
      <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-2">
        {footerLinks.map((link) => (
          <Link href={link.href} key={link.label}>
            <Button variant="link" className="uppercase">
              {link.label}
            </Button>
          </Link>
        ))}
      </div>
    </main>
  );
}
