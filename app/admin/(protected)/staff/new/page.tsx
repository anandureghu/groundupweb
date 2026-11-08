import type { Metadata } from "next";

import { AdminPageHeader } from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { NewStaffForm } from "./new-staff-form";

export const metadata: Metadata = {
  title: "New staff member",
};

type StoreRow = {
  id: string;
  name: string;
};

export default async function NewStaffPage() {
  await requireAdmin();

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("stores")
    .select("id, name")
    .eq("is_active", true);

  if (error) {
    console.error("fetch active stores failed", error);
  }

  const stores = (data as StoreRow[] | null) ?? [];

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        breadcrumb={{ href: "/admin/staff", label: "Staff" }}
        title="New staff member"
        description="Create an account for a staff member or admin."
      />

      <NewStaffForm stores={stores} />
    </div>
  );
}
