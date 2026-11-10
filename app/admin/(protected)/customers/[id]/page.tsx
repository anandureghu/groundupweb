import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import {
  AdminPageHeader,
  AdminSection,
  AdminStatusPill,
  AdminTable,
  AdminTableHead,
  AdminTd,
  AdminTh,
} from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { getCustomerEmailStatus } from "../actions";
import { CustomerEmailAction } from "./customer-email-action";
import { CustomerStatusAction } from "./customer-status-action";

export const metadata: Metadata = {
  title: "Customer detail",
};

type ProfileRow = {
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

type OrderRow = {
  id: string;
  order_number: string;
  store_name: string;
  status: string;
  total_cents: number;
  created_at: string;
};

type RewardTransactionRow = {
  id: string;
  type: string;
  points: number;
  balance_after: number;
  description: string;
  created_at: string;
};

function formatCurrency(cents: number): string {
  return (cents / 100).toLocaleString("en-GB", {
    style: "currency",
    currency: "GBP",
  });
}

export default async function AdminCustomerDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  await requireAdmin();

  const supabase = await createServerSupabaseClient();

  const [profileResult, ordersResult, rewardsResult, emailStatusResult] =
    await Promise.all([
      supabase
        .from("profiles")
        .select(
          "id, first_name, last_name, email, mobile_number, referral_code, points_balance, is_active, created_at",
        )
        .eq("id", id)
        .maybeSingle<ProfileRow>(),
      supabase.rpc("get_admin_customer_orders", { p_customer_id: id }),
      supabase.rpc("get_admin_customer_reward_transactions", {
        p_customer_id: id,
      }),
      getCustomerEmailStatus(id),
    ]);

  const { data: customer, error: profileError } = profileResult;

  if (profileError) {
    console.error("fetch customer profile failed", profileError);
  }
  if (ordersResult.error) {
    console.error("get_admin_customer_orders failed", ordersResult.error);
  }
  if (rewardsResult.error) {
    console.error(
      "get_admin_customer_reward_transactions failed",
      rewardsResult.error,
    );
  }

  if (!customer) {
    notFound();
  }

  const orders = (ordersResult.data as OrderRow[] | null) ?? [];
  const rewardTransactions =
    (rewardsResult.data as RewardTransactionRow[] | null) ?? [];

  const name =
    `${customer.first_name ?? ""} ${customer.last_name ?? ""}`.trim() || "—";

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        breadcrumb={{ href: "/admin/customers", label: "Customers" }}
        title={name}
        description={customer.email ?? undefined}
        actions={
          <>
            <AdminStatusPill
              active={customer.is_active ?? true}
              inactiveLabel="Disabled"
            />
            <CustomerStatusAction
              customerId={customer.id}
              isActive={customer.is_active ?? true}
            />
          </>
        }
      />

      <AdminSection title="Profile" description="Member account details">
        <div className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-3">
          <div>
            <p className="text-zinc-500">Mobile number</p>
            <p className="font-medium text-zinc-900">
              {customer.mobile_number ?? "—"}
            </p>
          </div>
          <div>
            <p className="text-zinc-500">Points balance</p>
            <p className="font-medium text-zinc-900">
              {customer.points_balance ?? 0}
            </p>
            <Link
              href={`/admin/rewards?member=${customer.id}`}
              className="text-xs font-medium text-zinc-600 underline-offset-2 hover:underline"
            >
              Adjust points
            </Link>
          </div>
          <div>
            <p className="text-zinc-500">Referral code</p>
            <p className="font-medium text-zinc-900">
              {customer.referral_code ?? "—"}
            </p>
          </div>
          <div>
            <p className="text-zinc-500">Joined</p>
            <p className="font-medium text-zinc-900">
              {new Date(customer.created_at).toLocaleDateString()}
            </p>
          </div>
          <div className="col-span-2 sm:col-span-3">
            <p className="mb-2 text-zinc-500">Email verification</p>
            {emailStatusResult.error ? (
              <p className="text-sm text-red-600">{emailStatusResult.error}</p>
            ) : (
              <CustomerEmailAction
                customerId={customer.id}
                emailConfirmed={emailStatusResult.data?.emailConfirmed ?? false}
                emailConfirmedAt={
                  emailStatusResult.data?.emailConfirmedAt ?? null
                }
              />
            )}
          </div>
        </div>
      </AdminSection>

      <AdminSection title="Order history" description="Most recent orders">
        {orders.length === 0 ? (
          <p className="text-sm text-zinc-500">No orders yet.</p>
        ) : (
          <AdminTable className="border-0 shadow-none">
            <AdminTableHead>
              <tr>
                <AdminTh>Order</AdminTh>
                <AdminTh>Store</AdminTh>
                <AdminTh>Status</AdminTh>
                <AdminTh>Total</AdminTh>
                <AdminTh>Date</AdminTh>
              </tr>
            </AdminTableHead>
            <tbody>
              {orders.map((order) => (
                <tr
                  key={order.id}
                  className="border-b border-zinc-100 last:border-b-0"
                >
                  <AdminTd>{order.order_number}</AdminTd>
                  <AdminTd>{order.store_name}</AdminTd>
                  <AdminTd className="capitalize">{order.status}</AdminTd>
                  <AdminTd>{formatCurrency(order.total_cents)}</AdminTd>
                  <AdminTd>
                    {new Date(order.created_at).toLocaleDateString()}
                  </AdminTd>
                </tr>
              ))}
            </tbody>
          </AdminTable>
        )}
      </AdminSection>

      <AdminSection
        title="Reward transactions"
        description="Points activity history"
      >
        {rewardTransactions.length === 0 ? (
          <p className="text-sm text-zinc-500">No reward transactions yet.</p>
        ) : (
          <AdminTable className="border-0 shadow-none">
            <AdminTableHead>
              <tr>
                <AdminTh>Type</AdminTh>
                <AdminTh>Points</AdminTh>
                <AdminTh>Balance after</AdminTh>
                <AdminTh>Description</AdminTh>
                <AdminTh>Date</AdminTh>
              </tr>
            </AdminTableHead>
            <tbody>
              {rewardTransactions.map((tx) => (
                <tr
                  key={tx.id}
                  className="border-b border-zinc-100 last:border-b-0"
                >
                  <AdminTd className="capitalize">{tx.type}</AdminTd>
                  <AdminTd>
                    {tx.points > 0 ? `+${tx.points}` : tx.points}
                  </AdminTd>
                  <AdminTd>{tx.balance_after}</AdminTd>
                  <AdminTd>{tx.description}</AdminTd>
                  <AdminTd>
                    {new Date(tx.created_at).toLocaleDateString()}
                  </AdminTd>
                </tr>
              ))}
            </tbody>
          </AdminTable>
        )}
      </AdminSection>
    </div>
  );
}
