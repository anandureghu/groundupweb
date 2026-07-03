import type { Metadata } from "next";
import Link from "next/link";
import { DeleteAccountForm } from "@/components/account/delete-account-form";
import { Button } from "@/components/ui/button";
import { SiteHeader } from "@/components/site/site-header";
import { getLegalContent } from "@/lib/legal/get-legal-content";

const legal = getLegalContent();
const { organization } = legal;

export const metadata: Metadata = {
  title: `Delete Account | ${organization.brandName}`,
  description: `Permanently delete your ${organization.brandName} account.`,
  robots: { index: false, follow: false },
};

interface DeleteAccountPageProps {
  searchParams: Promise<{ email?: string }>;
}

export default async function DeleteAccountPage({
  searchParams,
}: DeleteAccountPageProps) {
  const { email } = await searchParams;

  return (
    <div className="min-h-full bg-background">
      <SiteHeader brandName={organization.brandName} />
      <main className="mx-auto w-full max-w-xl px-6 py-12 md:py-16">
        <h1 className="mb-3 text-[32px] leading-tight font-semibold tracking-tight md:text-[40px]">
          Delete account
        </h1>
        <p className="mb-8 text-[15px] leading-relaxed text-muted-foreground">
          This will permanently remove your account and all associated personal
          data, including your rewards points and coupons. Order records may be
          retained for legal and operational requirements. This action cannot be
          undone.
        </p>

        <DeleteAccountForm initialEmail={email?.trim() ?? ""} />

        <div className="mt-10">
          <Button asChild variant="link" className="px-0">
            <Link href="/">Cancel and return home</Link>
          </Button>
        </div>
      </main>
    </div>
  );
}
