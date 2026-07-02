import type { Metadata } from "next";
import { Quicksand } from "next/font/google";
import { ThemeScript } from "./components/theme-script";
import "./globals.css";
import { cn } from "@/lib/utils";

const quicksand = Quicksand({
  variable: "--font-sans",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Ground Up",
  description: "Ground Up",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={cn("h-full antialiased font-sans", quicksand.variable)}
    >
      <head>
        <ThemeScript />
      </head>
      <body className="min-h-full flex flex-col bg-background">{children}</body>
    </html>
  );
}
