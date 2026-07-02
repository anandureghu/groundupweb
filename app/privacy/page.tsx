import type { Metadata } from "next";
import { LegalDocumentPage } from "@/components/legal/legal-document-page";
import { getLegalContent } from "@/lib/legal/get-legal-content";

const legal = getLegalContent();

export const metadata: Metadata = {
  title: `${legal.privacyPolicy.pageTitle} | ${legal.organization.brandName}`,
  description: legal.privacyPolicy.metaDescription,
};

export default function PrivacyPage() {
  return (
    <LegalDocumentPage
      document={legal.privacyPolicy}
      config={legal.websitePageConfig}
      organization={legal.organization}
    />
  );
}
