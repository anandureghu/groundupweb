export type LegalLinkType = "page" | "email" | "download" | "external";

export interface LegalLink {
  label: string;
  href: string;
  type: LegalLinkType | string;
}

export interface LegalContact {
  email?: string;
  supportEmail?: string;
  website?: string;
  postalAddress?: string;
}

export interface LegalSubsection {
  title: string;
  paragraphs: string[];
}

export interface LegalSectionContent {
  paragraphs?: string[];
  bullets?: string[];
  links?: LegalLink[];
  subsections?: LegalSubsection[];
  contact?: LegalContact;
}

export interface LegalSection {
  id: string;
  title: string;
  defaultExpanded?: boolean;
  content: LegalSectionContent;
}

export interface LegalIntro {
  paragraphs?: string[];
  quickLinks?: LegalLink[];
  tableOfContents?: string[];
}

export interface LegalDocument {
  pageTitle: string;
  documentTitle: string;
  legalInformationNotice?: string;
  version: string;
  lastUpdated: string;
  lastUpdatedDisplay: string;
  updatedBy?: string;
  metaDescription: string;
  copyrightNotice?: string;
  intro: LegalIntro;
  sections: LegalSection[];
}

export interface LegalOrganization {
  legalName: string;
  brandName: string;
  website: string;
  supportEmail: string;
  privacyEmail: string;
  countryOfOperation: string;
  registeredAddress: string;
  appName: string;
  iosBundleId: string;
  androidPackageName: string;
}

export interface WebsitePageConfig {
  layout: string;
  styleReference?: string;
  showTableOfContents: boolean;
  showLastUpdated: boolean;
  showQuickLinks: boolean;
  showDownloadPdf: boolean;
  showLegalInformationNotice: boolean;
  sectionDividerStyle: string;
  defaultExpandedCount?: number;
  typography?: {
    pageTitleSize?: string;
    sectionTitleWeight?: string;
    bodyLineHeight?: string;
  };
  theme?: {
    primaryBrand?: string;
    accentColor?: string;
    backgroundColor?: string;
    textColor?: string;
  };
}

export interface LegalContent {
  version: string;
  lastUpdated: string;
  lastUpdatedDisplay: string;
  organization: LegalOrganization;
  routes: {
    privacyPolicy: string;
    termsOfUse: string;
  };
  termsOfUse: LegalDocument;
  privacyPolicy: LegalDocument;
  websitePageConfig: WebsitePageConfig;
  disclaimer?: string;
}
