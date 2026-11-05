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
  return (cents / 100).toLocaleString("en-US", {
    style: "currency",
    currency: "USD",
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

  const [profileResult, ordersResult, rewardsResult] = await Promise.all([
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
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">{name}</h1>
          <p className="text-sm text-muted-foreground">{customer.email}</p>
        </div>
        <CustomerStatusAction
          customerId={customer.id}
          isActive={customer.is_active ?? true}
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Profile</CardTitle>
          <CardDescription>Member account details</CardDescription>
        </CardHeader>
        <CardContent className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-3">
          <div>
            <p className="text-muted-foreground">Mobile number</p>
            <p>{customer.mobile_number ?? "—"}</p>
          </div>
          <div>
            <p className="text-muted-foreground">Points balance</p>
            <p>{customer.points_balance ?? 0}</p>
          </div>
          <div>
            <p className="text-muted-foreground">Status</p>
            <p>{customer.is_active ? "Active" : "Disabled"}</p>
          </div>
          <div>
            <p className="text-muted-foreground">Referral code</p>
            <p>{customer.referral_code ?? "—"}</p>
          </div>
          <div>
            <p className="text-muted-foreground">Joined</p>
            <p>{new Date(customer.created_at).toLocaleDateString()}</p>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Order history</CardTitle>
          <CardDescription>Most recent orders</CardDescription>
        </CardHeader>
        <CardContent>
          {orders.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No orders yet.
            </p>
          ) : (
            <div className="overflow-x-auto border border-border">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-border bg-muted/40">
                  <tr>
                    <th className="px-4 py-3 font-semibold">Order</th>
                    <th className="px-4 py-3 font-semibold">Store</th>
                    <th className="px-4 py-3 font-semibold">Status</th>
                    <th className="px-4 py-3 font-semibold">Total</th>
                    <th className="px-4 py-3 font-semibold">Date</th>
                  </tr>
                </thead>
                <tbody>
                  {orders.map((order) => (
                    <tr
                      key={order.id}
                      className="border-b border-border last:border-b-0"
                    >
                      <td className="px-4 py-3">{order.order_number}</td>
                      <td className="px-4 py-3">{order.store_name}</td>
                      <td className="px-4 py-3 capitalize">
                        {order.status}
                      </td>
                      <td className="px-4 py-3">
                        {formatCurrency(order.total_cents)}
                      </td>
                      <td className="px-4 py-3">
                        {new Date(order.created_at).toLocaleDateString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Reward transactions</CardTitle>
          <CardDescription>Points activity history</CardDescription>
        </CardHeader>
        <CardContent>
          {rewardTransactions.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No reward transactions yet.
            </p>
          ) : (
            <div className="overflow-x-auto border border-border">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-border bg-muted/40">
                  <tr>
                    <th className="px-4 py-3 font-semibold">Type</th>
                    <th className="px-4 py-3 font-semibold">Points</th>
                    <th className="px-4 py-3 font-semibold">
                      Balance after
                    </th>
                    <th className="px-4 py-3 font-semibold">Description</th>
                    <th className="px-4 py-3 font-semibold">Date</th>
                  </tr>
                </thead>
                <tbody>
                  {rewardTransactions.map((tx) => (
                    <tr
                      key={tx.id}
                      className="border-b border-border last:border-b-0"
                    >
                      <td className="px-4 py-3 capitalize">{tx.type}</td>
                      <td className="px-4 py-3">
                        {tx.points > 0 ? `+${tx.points}` : tx.points}
                      </td>
                      <td className="px-4 py-3">{tx.balance_after}</td>
                      <td className="px-4 py-3">{tx.description}</td>
                      <td className="px-4 py-3">
                        {new Date(tx.created_at).toLocaleDateString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
