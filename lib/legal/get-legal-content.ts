import legalContent from "@/content/legal.json";
import type { LegalContent } from "./types";

export function getLegalContent(): LegalContent {
  return legalContent as LegalContent;
}
