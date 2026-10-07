import { redirect } from "next/navigation";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function ShortReferralRedirectPage({ params }: PageProps) {
  const { code } = await params;
  const normalized = code?.trim().toUpperCase() ?? "";
  if (!normalized) {
    redirect("/download");
  }
  redirect(`/download?code=${encodeURIComponent(normalized)}`);
}
