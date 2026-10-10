export interface SupportFaqItem {
  id: string;
  question: string;
  answer: string;
}

export const SUPPORT_FAQ: SupportFaqItem[] = [
  {
    id: "what-is-groundup",
    question: "What is Groundup Society?",
    answer:
      "Groundup Society is the official membership app for Groundup cafes. Create a free member account to unlock rewards, offers, and a smoother in-store experience.",
  },
  {
    id: "how-to-join",
    question: "How do I join?",
    answer:
      "Download the Groundup Society app from the App Store or Google Play, create your account, verify your email, and complete your profile. Early joiners with a staff invite can start from the Download page.",
  },
  {
    id: "rewards",
    question: "How do rewards and points work?",
    answer:
      "Earn points and unlock member rewards through eligible visits and offers in the app. Available rewards and offer details appear in your member account once you are signed in.",
  },
  {
    id: "account-help",
    question: "I cannot sign in or verify my email",
    answer:
      "Check your spam folder for the verification email, confirm you are using the same address you registered with, and try resetting your password from the app. If you still need help, raise a support request below.",
  },
  {
    id: "delete-account",
    question: "How do I delete my account?",
    answer:
      "You can request permanent account deletion from our Delete Account page. You will need the email and password for the account you want removed.",
  },
  {
    id: "privacy",
    question: "Where can I read the privacy policy?",
    answer:
      "Our Privacy Policy explains what data we collect and how we use it. You can open it anytime from the Privacy link in the site footer or on this page.",
  },
  {
    id: "stores",
    question: "How do I find a Groundup cafe?",
    answer:
      "Open the app after signing in to browse nearby stores and directions. If a location looks wrong or is missing, tell us through the support form.",
  },
];

export const SUPPORT_TOPICS = [
  { value: "general", label: "General question" },
  { value: "account", label: "Account & sign-in" },
  { value: "rewards", label: "Rewards & offers" },
  { value: "stores", label: "Stores & visits" },
  { value: "app", label: "App issue / bug" },
  { value: "privacy", label: "Privacy concern" },
  { value: "other", label: "Something else" },
] as const;

export type SupportTopic = (typeof SUPPORT_TOPICS)[number]["value"];
