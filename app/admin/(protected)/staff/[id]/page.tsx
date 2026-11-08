import type { Metadata } from "next";
import { notFound } from "next/navigation";

import {
  AdminPageHeader,
  AdminSection,
  AdminStatusPill,
} from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

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
      <AdminPageHeader
        breadcrumb={{ href: "/admin/staff", label: "Staff" }}
        title={name}
        description={staffMember.email ?? undefined}
        actions={
          <>
            <AdminStatusPill
              active={staffMember.is_active ?? true}
              inactiveLabel="Disabled"
            />
            <StaffStatusAction
              staffId={staffMember.id}
              isActive={staffMember.is_active ?? true}
            />
          </>
        }
      />

      <AdminSection title="Profile" description="Staff account details">
        <div className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-3">
          <div>
            <p className="text-zinc-500">Role</p>
            <p className="font-medium capitalize text-zinc-900">
              {staffMember.staff_role ?? "—"}
            </p>
          </div>
          <div>
            <p className="text-zinc-500">Assigned store</p>
            <p className="font-medium text-zinc-900">{storeName ?? "—"}</p>
          </div>
          <div>
            <p className="text-zinc-500">Mobile number</p>
            <p className="font-medium text-zinc-900">
              {staffMember.mobile_number ?? "—"}
            </p>
          </div>
          <div>
            <p className="text-zinc-500">Joined</p>
            <p className="font-medium text-zinc-900">
              {new Date(staffMember.created_at).toLocaleDateString()}
            </p>
          </div>
        </div>
      </AdminSection>
    </div>
  );
}
