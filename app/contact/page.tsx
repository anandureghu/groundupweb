import type { Metadata } from "next";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { SiteHeader } from "@/components/site/site-header";
import { getLegalContent } from "@/lib/legal/get-legal-content";

const legal = getLegalContent();
const { organization } = legal;

export const metadata: Metadata = {
  title: `Contact | ${organization.brandName}`,
  description: `Get in touch with ${organization.brandName}.`,
};

export default function ContactPage() {
  return (
    <div className="min-h-full bg-background">
      <SiteHeader brandName={organization.brandName} />
      <main className="mx-auto w-full max-w-3xl px-6 py-12 md:py-16">
        <h1 className="mb-3 text-[40px] leading-tight font-semibold tracking-tight md:text-[48px]">
          Contact
        </h1>
        <p className="mb-10 max-w-xl text-[15px] leading-relaxed text-muted-foreground">
          Have a question about {organization.brandName}? We&apos;d love to hear
          from you.
        </p>

        <div className="space-y-6 border-t border-border pt-8 text-[15px] leading-relaxed">
          <div>
            <h2 className="mb-1 font-semibold">General support</h2>
            <a
              href={`mailto:${organization.supportEmail}`}
              className="text-[#0066cc] underline underline-offset-2 hover:opacity-80"
            >
              {organization.supportEmail}
            </a>
          </div>

          <div>
            <h2 className="mb-1 font-semibold">Privacy enquiries</h2>
            <a
              href={`mailto:${organization.privacyEmail}`}
              className="text-[#0066cc] underline underline-offset-2 hover:opacity-80"
            >
              {organization.privacyEmail}
            </a>
          </div>

          <div>
            <h2 className="mb-1 font-semibold">Registered address</h2>
            <p className="text-muted-foreground">
              {organization.registeredAddress}
            </p>
          </div>

          <div>
            <h2 className="mb-1 font-semibold">Website</h2>
            <a
              href={organization.website}
              className="text-[#0066cc] underline underline-offset-2 hover:opacity-80"
            >
              {organization.website.replace(/^https?:\/\//, "")}
            </a>
          </div>
        </div>

        <div className="mt-12 flex flex-wrap gap-3">
          <Button asChild variant="outline">
            <Link href="/">Back to home</Link>
          </Button>
          <Button asChild variant="link" className="uppercase">
            <Link href={legal.routes.privacyPolicy}>Privacy</Link>
          </Button>
          <Button asChild variant="link" className="uppercase">
            <Link href={legal.routes.termsOfUse}>Terms</Link>
          </Button>
        </div>
      </main>
    </div>
  );
}
