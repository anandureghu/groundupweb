import type { Metadata } from "next";

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
      <div>
        <h1 className="text-2xl font-semibold">New staff member</h1>
        <p className="text-sm text-muted-foreground">
          Create an account for a staff member or admin.
        </p>
      </div>

      <NewStaffForm stores={stores} />
    </div>
  );
}
