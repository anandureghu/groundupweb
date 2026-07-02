import type { Metadata } from "next";
import { LegalDocumentPage } from "@/components/legal/legal-document-page";
import { getLegalContent } from "@/lib/legal/get-legal-content";

const legal = getLegalContent();

export const metadata: Metadata = {
  title: `${legal.termsOfUse.pageTitle} | ${legal.organization.brandName}`,
  description: legal.termsOfUse.metaDescription,
};

export default function TermsPage() {
  return (
    <LegalDocumentPage
      document={legal.termsOfUse}
      config={legal.websitePageConfig}
      organization={legal.organization}
    />
  );
}
