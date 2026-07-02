import Image from "next/image";
import Link from "next/link";

interface SiteHeaderProps {
  brandName?: string;
}

export function SiteHeader({ brandName = "Groundup Society" }: SiteHeaderProps) {
  return (
    <header className="sticky top-0 z-10 border-b border-border/60 bg-background/90 backdrop-blur-sm">
      <div className="mx-auto flex h-14 max-w-3xl items-center px-6">
        <Link href="/" className="inline-flex items-center" aria-label="Home">
          <Image
            src="/assets/logo/logo-dark.svg"
            alt={brandName}
            width={120}
            height={29}
            className="h-7 w-auto"
          />
        </Link>
      </div>
    </header>
  );
}
