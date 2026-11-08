import type { Metadata } from "next";
import Link from "next/link";

import { AdminPageHeader } from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Button } from "@/components/ui/button";

import { StaffList, type AdminStaffRow } from "./staff-list";

export const metadata: Metadata = {
  title: "Staff",
};

type ListStaffMembersRow = {
  id: string;
  first_name: string | null;
  last_name: string | null;
  email: string | null;
  staff_role: string | null;
  assigned_store_id: string | null;
  store_name: string | null;
  is_active: boolean | null;
  created_at: string;
};

export default async function AdminStaffPage() {
  await requireAdmin();

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("list_staff_members");

  if (error) {
    console.error("list_staff_members failed", error);
  }

  const staff: AdminStaffRow[] = (
    (data as ListStaffMembersRow[] | null) ?? []
  ).map((row) => ({
    id: row.id,
    firstName: row.first_name,
    lastName: row.last_name,
    email: row.email,
    staffRole: row.staff_role,
    storeName: row.store_name,
    isActive: row.is_active ?? true,
  }));

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Staff"
        description={`${staff.length} member${staff.length === 1 ? "" : "s"}`}
        actions={
          <Button asChild className="rounded-lg">
            <Link href="/admin/staff/new">New staff member</Link>
          </Button>
        }
      />

      <StaffList staff={staff} />
    </div>
  );
}
