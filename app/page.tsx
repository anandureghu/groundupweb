import Image from "next/image";
import { ThemeToggle } from "./components/theme-toggle";

export default function Home() {
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
    </main>
  );
}
