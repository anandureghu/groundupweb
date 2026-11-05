import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

import { StaffStatusAction } from "./staff-status-action";

export const metadata: Metadata = {
  title: "Staff detail",
};

type ProfileRow = {
  id: string;
  first_name: string | null;
  last_name: string | null;
  email: string | null;
  mobile_number: string | null;
  staff_role: string | null;
  assigned_store_id: string | null;
  is_active: boolean | null;
  created_at: string;
};

type StoreRow = {
  id: string;
  name: string;
};

export default async function AdminStaffDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  await requireAdmin();

  const supabase = await createServerSupabaseClient();

  const { data: staffMember, error: profileError } = await supabase
    .from("profiles")
    .select(
      "id, first_name, last_name, email, mobile_number, staff_role, assigned_store_id, is_active, created_at",
    )
    .eq("id", id)
    .not("staff_role", "is", null)
    .maybeSingle<ProfileRow>();

  if (profileError) {
    console.error("fetch staff profile failed", profileError);
  }

  if (!staffMember) {
    notFound();
  }

  let storeName: string | null = null;

  if (staffMember.assigned_store_id) {
    const { data: store, error: storeError } = await supabase
      .from("stores")
      .select("id, name")
      .eq("id", staffMember.assigned_store_id)
      .maybeSingle<StoreRow>();

    if (storeError) {
      console.error("fetch assigned store failed", storeError);
    }

    storeName = store?.name ?? null;
  }

  const name =
    `${staffMember.first_name ?? ""} ${staffMember.last_name ?? ""}`.trim() ||
    "—";

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">{name}</h1>
          <p className="text-sm text-muted-foreground">
            {staffMember.email}
          </p>
        </div>
        <StaffStatusAction
          staffId={staffMember.id}
          isActive={staffMember.is_active ?? true}
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Profile</CardTitle>
          <CardDescription>Staff account details</CardDescription>
        </CardHeader>
        <CardContent className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-3">
          <div>
            <p className="text-muted-foreground">Role</p>
            <p className="capitalize">{staffMember.staff_role ?? "—"}</p>
          </div>
          <div>
            <p className="text-muted-foreground">Assigned store</p>
            <p>{storeName ?? "—"}</p>
          </div>
          <div>
            <p className="text-muted-foreground">Status</p>
            <p>{staffMember.is_active ? "Active" : "Disabled"}</p>
          </div>
          <div>
            <p className="text-muted-foreground">Mobile number</p>
            <p>{staffMember.mobile_number ?? "—"}</p>
          </div>
          <div>
            <p className="text-muted-foreground">Joined</p>
            <p>{new Date(staffMember.created_at).toLocaleDateString()}</p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
