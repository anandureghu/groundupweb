import type { Metadata } from "next";
import Link from "next/link";

import {
  AdminPageHeader,
  AdminSection,
  AdminTable,
  AdminTableHead,
  AdminTd,
  AdminTh,
} from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { rowsOf } from "@/lib/admin/notifications";
import {
  estimatedPoundsValue,
  formatPoints,
  type RewardsOverviewRow,
} from "@/lib/admin/rewards";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { AdjustPointsForm, type RewardsMember } from "./adjust-points-form";

export const metadata: Metadata = {
  title: "Rewards",
};

type CustomerRow = {
  id: string;
  first_name: string | null;
  last_name: string | null;
  email: string | null;
  points_balance: number | null;
};

type AdjustmentRow = {
  id: string;
  profile_id: string;
  first_name: string | null;
  last_name: string | null;
  email: string | null;
  actor_email: string | null;
  points: number;
  balance_after: number;
  description: string;
  created_at: string;
};

function memberName(first: string | null, last: string | null): string {
  return `${first ?? ""} ${last ?? ""}`.trim();
}

export default async function AdminRewardsPage({
  searchParams,
}: {
  searchParams: Promise<{ member?: string }>;
}) {
  await requireAdmin();
  const { member } = await searchParams;
  const supabase = await createServerSupabaseClient();

  const [
    { data: overviewData, error: overviewError },
    { data: customersData, error: customersError },
    { data: adjustmentsData, error: adjustmentsError },
  ] = await Promise.all([
    supabase.rpc("admin_rewards_overview"),
    supabase.rpc("list_customers"),
    supabase.rpc("admin_list_reward_adjustments", { p_limit: 20 }),
  ]);

  if (overviewError) {
    console.error("admin_rewards_overview failed", overviewError);
  }
  if (customersError) {
    console.error("list_customers failed", customersError);
  }
  if (adjustmentsError) {
    console.error("admin_list_reward_adjustments failed", adjustmentsError);
  }

  const overview = rowsOf<RewardsOverviewRow>(overviewData)[0] ?? null;
  const customers = rowsOf<CustomerRow>(customersData);
  const adjustments = rowsOf<AdjustmentRow>(adjustmentsData);

  const members: RewardsMember[] = customers.map((row) => ({
    id: row.id,
    name: memberName(row.first_name, row.last_name),
    email: row.email ?? "",
    pointsBalance: row.points_balance ?? 0,
  }));

  const leaderboard = [...members]
    .sort((a, b) => b.pointsBalance - a.pointsBalance)
    .slice(0, 20);

  const error = overviewError ?? customersError ?? adjustmentsError;

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Rewards"
        description="Program totals, the points leaderboard, and manual balance adjustments."
      />

      {error ? (
        <p className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error.message}
        </p>
      ) : null}

      {overview ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard
            label="Points outstanding"
            value={formatPoints(overview.total_outstanding_points)}
            hint={`${estimatedPoundsValue(
              overview.total_outstanding_points,
              overview.points_per_pound,
            )} at the current earn rate`}
          />
          <StatCard
            label="Members holding points"
            value={`${overview.members_with_points.toLocaleString("en-GB")} / ${overview.total_customers.toLocaleString("en-GB")}`}
            hint="Members with a balance above zero"
          />
          <StatCard
            label="Lifetime points awarded"
            value={formatPoints(overview.total_points_awarded)}
            hint="Purchases, referrals, challenges, and adjustments"
          />
          <StatCard
            label="Lifetime points redeemed"
            value={formatPoints(overview.total_points_redeemed)}
            hint="Spent on rewards at the counter"
          />
        </div>
      ) : null}

      <AdminSection
        title="Adjust a member's balance"
        description="Search for a member, then add or remove points with a reason. This is logged to the audit trail."
      >
        <AdjustPointsForm members={members} preselectedId={member} />
      </AdminSection>

      <AdminSection title="Leaderboard" description="Members with the most points right now">
        {leaderboard.length === 0 ? (
          <p className="text-sm text-zinc-500">No members yet.</p>
        ) : (
          <AdminTable className="border-0 shadow-none">
            <AdminTableHead>
              <tr>
                <AdminTh>Rank</AdminTh>
                <AdminTh>Member</AdminTh>
                <AdminTh>Points</AdminTh>
              </tr>
            </AdminTableHead>
            <tbody>
              {leaderboard.map((leader, index) => (
                <tr key={leader.id} className="border-b border-zinc-100 last:border-b-0">
                  <AdminTd>{index + 1}</AdminTd>
                  <AdminTd>
                    <Link
                      href={`/admin/customers/${leader.id}`}
                      className="font-medium text-zinc-900 underline-offset-2 hover:underline"
                    >
                      {leader.name || "Member"}
                    </Link>
                    <p className="text-xs text-zinc-500">{leader.email}</p>
                  </AdminTd>
                  <AdminTd>{formatPoints(leader.pointsBalance)}</AdminTd>
                </tr>
              ))}
            </tbody>
          </AdminTable>
        )}
      </AdminSection>

      <AdminSection
        title="Recent manual adjustments"
        description="The last 20 adjustments made from this page"
      >
        {adjustments.length === 0 ? (
          <p className="text-sm text-zinc-500">No manual adjustments yet.</p>
        ) : (
          <AdminTable className="border-0 shadow-none">
            <AdminTableHead>
              <tr>
                <AdminTh>Member</AdminTh>
                <AdminTh>Points</AdminTh>
                <AdminTh>Balance after</AdminTh>
                <AdminTh>Reason</AdminTh>
                <AdminTh>By</AdminTh>
                <AdminTh>Date</AdminTh>
              </tr>
            </AdminTableHead>
            <tbody>
              {adjustments.map((row) => (
                <tr key={row.id} className="border-b border-zinc-100 last:border-b-0">
                  <AdminTd>
                    <Link
                      href={`/admin/customers/${row.profile_id}`}
                      className="font-medium text-zinc-900 underline-offset-2 hover:underline"
                    >
                      {memberName(row.first_name, row.last_name) || "Member"}
                    </Link>
                    <p className="text-xs text-zinc-500">{row.email}</p>
                  </AdminTd>
                  <AdminTd>{row.points > 0 ? `+${row.points}` : row.points}</AdminTd>
                  <AdminTd>{formatPoints(row.balance_after)}</AdminTd>
                  <AdminTd>{row.description}</AdminTd>
                  <AdminTd className="text-zinc-500">{row.actor_email ?? "—"}</AdminTd>
                  <AdminTd>{new Date(row.created_at).toLocaleDateString()}</AdminTd>
                </tr>
              ))}
            </tbody>
          </AdminTable>
        )}
      </AdminSection>
    </div>
  );
}

function StatCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
      <p className="text-sm text-zinc-500">{label}</p>
      <p className="mt-1 text-2xl font-semibold text-zinc-900">{value}</p>
      {hint ? <p className="mt-1 text-xs text-zinc-500">{hint}</p> : null}
    </div>
  );
}
