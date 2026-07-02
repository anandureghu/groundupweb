import { ChevronDown } from "lucide-react";
import { SiteHeader } from "@/components/site/site-header";
import type {
  LegalDocument,
  LegalOrganization,
  WebsitePageConfig,
} from "@/lib/legal/types";
import { LegalQuickLink } from "./legal-quick-link";
import { LegalSectionBody } from "./legal-section-body";

interface LegalDocumentPageProps {
  document: LegalDocument;
  config: WebsitePageConfig;
  organization: LegalOrganization;
}

export function LegalDocumentPage({
  document,
  config,
  organization,
}: LegalDocumentPageProps) {
  const quickLinks = document.intro.quickLinks ?? [];

  return (
    <div className="min-h-full bg-background">
      <SiteHeader brandName={organization.brandName} />

      <main className="mx-auto w-full max-w-3xl px-6 py-12 md:py-16">
        <article>
          {config.showLegalInformationNotice && document.legalInformationNotice && (
            <p className="mb-3 text-[13px] font-medium tracking-wide text-muted-foreground uppercase">
              {document.legalInformationNotice}
            </p>
          )}

          <h1 className="mb-3 text-[40px] leading-tight font-semibold tracking-tight text-foreground md:text-[48px]">
            {document.pageTitle}
          </h1>

          {config.showLastUpdated && (
            <p className="mb-8 text-[15px] text-muted-foreground">
              Last updated {document.lastUpdatedDisplay}
            </p>
          )}

          {document.intro.paragraphs && document.intro.paragraphs.length > 0 && (
            <div className="mb-8 space-y-4 text-[15px] leading-relaxed text-foreground/80">
              {document.intro.paragraphs.map((paragraph) => (
                <p key={paragraph.slice(0, 48)}>{paragraph}</p>
              ))}
            </div>
          )}

          {config.showQuickLinks && quickLinks.length > 0 && (
            <ul className="mb-10 space-y-2">
              {quickLinks.map((link) => (
                <li key={`${link.href}-${link.label}`}>
                  <LegalQuickLink link={link} />
                </li>
              ))}
            </ul>
          )}

          {config.showTableOfContents &&
            document.intro.tableOfContents &&
            document.intro.tableOfContents.length > 0 && (
              <nav
                aria-label="Table of contents"
                className="mb-10 border-y border-border py-6"
              >
                <ul className="space-y-2">
                  {document.intro.tableOfContents.map((item) => (
                    <li
                      key={item}
                      className="text-[15px] text-foreground/80"
                    >
                      {item}
                    </li>
                  ))}
                </ul>
              </nav>
            )}

          <div className="border-t border-border">
            {document.sections.map((section) => (
              <details
                key={section.id}
                id={section.id}
                className="group border-b border-border"
                open={section.defaultExpanded}
              >
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 py-5 text-[17px] font-semibold text-foreground marker:content-none [&::-webkit-details-marker]:hidden">
                  <span>{section.title}</span>
                  <ChevronDown className="size-4 shrink-0 text-muted-foreground transition-transform duration-200 group-open:rotate-180" />
                </summary>
                <LegalSectionBody content={section.content} />
              </details>
            ))}
          </div>

          {document.copyrightNotice && (
            <p className="mt-10 text-[13px] text-muted-foreground">
              {document.copyrightNotice}
            </p>
          )}
        </article>
      </main>
    </div>
  );
}
