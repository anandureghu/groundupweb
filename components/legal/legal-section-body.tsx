import type { LegalSectionContent } from "@/lib/legal/types";
import { LegalQuickLink } from "./legal-quick-link";

interface LegalSectionContentProps {
  content: LegalSectionContent;
}

export function LegalSectionBody({ content }: LegalSectionContentProps) {
  return (
    <div className="space-y-4 pb-8 text-[15px] leading-relaxed text-foreground/80">
      {content.paragraphs?.map((paragraph) => (
        <p key={paragraph.slice(0, 48)}>{paragraph}</p>
      ))}

      {content.bullets && content.bullets.length > 0 && (
        <ul className="list-disc space-y-2 pl-5">
          {content.bullets.map((bullet) => (
            <li key={bullet.slice(0, 48)}>{bullet}</li>
          ))}
        </ul>
      )}

      {content.links && content.links.length > 0 && (
        <div className="space-y-2">
          {content.links.map((link) => (
            <p key={`${link.href}-${link.label}`}>
              <LegalQuickLink link={link} />
            </p>
          ))}
        </div>
      )}

      {content.subsections?.map((subsection) => (
        <div key={subsection.title} className="space-y-3">
          <h3 className="text-[15px] font-semibold text-foreground">
            {subsection.title}
          </h3>
          {subsection.paragraphs.map((paragraph) => (
            <p key={paragraph.slice(0, 48)}>{paragraph}</p>
          ))}
        </div>
      ))}

      {content.contact && (
        <div className="space-y-1">
          {content.contact.email && (
            <p>
              Email:{" "}
              <LegalQuickLink
                link={{
                  label: content.contact.email,
                  href: `mailto:${content.contact.email}`,
                  type: "email",
                }}
              />
            </p>
          )}
          {content.contact.supportEmail && (
            <p>
              Support:{" "}
              <LegalQuickLink
                link={{
                  label: content.contact.supportEmail,
                  href: `mailto:${content.contact.supportEmail}`,
                  type: "email",
                }}
              />
            </p>
          )}
          {content.contact.website && (
            <p>
              Website:{" "}
              <LegalQuickLink
                link={{
                  label: content.contact.website.replace(/^https?:\/\//, ""),
                  href: content.contact.website,
                  type: "external",
                }}
              />
            </p>
          )}
          {/* {content.contact.postalAddress && (
            <p>Postal address: {content.contact.postalAddress}</p>
          )} */}
        </div>
      )}
    </div>
  );
}
