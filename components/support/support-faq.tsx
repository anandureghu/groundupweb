import { ChevronDown } from "lucide-react";

import { SUPPORT_FAQ } from "@/content/support-faq";

export function SupportFaq() {
  return (
    <div className="border-t border-border">
      {SUPPORT_FAQ.map((item, index) => (
        <details
          key={item.id}
          id={item.id}
          className="group border-b border-border"
          open={index === 0}
        >
          <summary className="flex cursor-pointer list-none items-center justify-between gap-4 py-5 text-[17px] font-semibold text-foreground marker:content-none [&::-webkit-details-marker]:hidden">
            <span>{item.question}</span>
            <ChevronDown className="size-4 shrink-0 text-muted-foreground transition-transform duration-200 group-open:rotate-180" />
          </summary>
          <p className="pb-5 text-[15px] leading-relaxed text-muted-foreground">
            {item.answer}
          </p>
        </details>
      ))}
    </div>
  );
}
