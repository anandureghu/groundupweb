import type { Metadata } from "next";

import { AdminPageHeader } from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { CustomerList, type AdminCustomerRow } from "./customer-list";

export const metadata: Metadata = {
  title: "Customers",
};

type ListCustomersRow = {
  id: string;
  first_name: string | null;
  last_name: string | null;
  email: string | null;
  mobile_number: string | null;
  referral_code: string | null;
  points_balance: number | null;
  is_active: boolean | null;
  created_at: string;
};

export default async function AdminCustomersPage() {
  await requireAdmin();

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("list_customers");

  if (error) {
    console.error("list_customers failed", error);
  }

  const customers: AdminCustomerRow[] = (
    (data as ListCustomersRow[] | null) ?? []
  ).map((row) => ({
    id: row.id,
    firstName: row.first_name,
    lastName: row.last_name,
    email: row.email,
    pointsBalance: row.points_balance ?? 0,
    isActive: row.is_active ?? true,
    createdAt: row.created_at,
  }));

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Customers"
        description={`${customers.length} member${customers.length === 1 ? "" : "s"}`}
      />

      <CustomerList customers={customers} />
    </div>
  );
}
