import type { Metadata } from "next";
import Link from "next/link";

import { SiteHeader } from "@/components/site/site-header";
import { SupportFaq } from "@/components/support/support-faq";
import { SupportFormDialog } from "@/components/support/support-form-dialog";
import { Button } from "@/components/ui/button";
import { getLegalContent } from "@/lib/legal/get-legal-content";

const legal = getLegalContent();
const { organization } = legal;

export const metadata: Metadata = {
  title: `Support | ${organization.brandName}`,
  description: `Get help with ${organization.brandName} — FAQ and contact support.`,
};

export default function SupportPage() {
  return (
    <div className="min-h-full bg-background">
      <SiteHeader brandName={organization.brandName} />
      <main className="mx-auto w-full max-w-3xl px-6 py-12 md:py-16">
        <h1 className="mb-3 text-[40px] leading-tight font-semibold tracking-tight md:text-[48px]">
          Support
        </h1>
        <p className="mb-8 max-w-xl text-[15px] leading-relaxed text-muted-foreground">
          Find quick answers below, or raise a concern with our team if you need
          personal help with your membership, rewards, or the app.
        </p>

        <div className="mb-12 flex flex-wrap items-center gap-3">
          <SupportFormDialog triggerLabel="Raise a concern" />
          <Button asChild variant="outline">
            <a href={`mailto:${organization.supportEmail}`}>Email us directly</a>
          </Button>
        </div>

        <section aria-labelledby="support-faq-heading">
          <h2
            id="support-faq-heading"
            className="mb-2 text-sm font-semibold tracking-widest text-muted-foreground uppercase"
          >
            Frequently asked questions
          </h2>
          <p className="mb-6 text-[15px] leading-relaxed text-muted-foreground">
            Start here — most member questions are covered in a few taps.
          </p>
          <SupportFaq />
        </section>

        <section className="mt-12 border-t border-border pt-8">
          <h2 className="mb-2 text-[17px] font-semibold">Still need help?</h2>
          <p className="mb-5 max-w-xl text-[15px] leading-relaxed text-muted-foreground">
            Open the support form and we&apos;ll get back to you. For privacy
            questions, you can also write to{" "}
            <a
              href={`mailto:${organization.privacyEmail}`}
              className="text-[#0066cc] underline underline-offset-2 hover:opacity-80"
            >
              {organization.privacyEmail}
            </a>
            .
          </p>
          <SupportFormDialog
            triggerLabel="Contact support"
            triggerVariant="outline"
          />
        </section>

        <div className="mt-12 flex flex-wrap gap-3">
          <Button asChild variant="outline">
            <Link href="/">Back to home</Link>
          </Button>
          <Button asChild variant="link" className="uppercase">
            <Link href="/contact">Contact</Link>
          </Button>
          <Button asChild variant="link" className="uppercase">
            <Link href={legal.routes.privacyPolicy}>Privacy</Link>
          </Button>
          <Button asChild variant="link" className="uppercase">
            <Link href="/delete-account">Delete account</Link>
          </Button>
        </div>
      </main>
    </div>
  );
}
