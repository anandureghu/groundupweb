import type { Metadata } from "next";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { StatusPage } from "@/components/site/status-page";

export const metadata: Metadata = {
  title: "Page not found | Groundup Society",
  description: "The page you are looking for could not be found.",
};

export default function NotFound() {
  return (
    <StatusPage
      code="404"
      title="Page not found"
      description="The page you are looking for does not exist or may have been moved."
      actions={
        <>
          <Button asChild>
            <Link href="/">Back to home</Link>
          </Button>
          <Button asChild variant="outline">
            <Link href="/contact">Contact us</Link>
          </Button>
        </>
      }
    />
  );
}
