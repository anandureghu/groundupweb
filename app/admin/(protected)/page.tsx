import type { Metadata } from "next";

import {
  AdminPageHeader,
  AdminSection,
} from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  toGrowthChartSeries,
  type GrowthAnalyticsRow,
} from "@/lib/admin/growth-chart";

import { OverviewGrowthChart } from "./overview-growth-chart";

export const metadata: Metadata = {
  title: "Overview",
};

const GROWTH_WINDOW_DAYS = 30;

type OnboardingAnalytics = {
  totalCustomers: number;
  totalStaff: number;
  totalAdmins: number;
  totalStaffOnboarded: number;
  staffOnboardings: unknown[];
};

export default async function AdminOverviewPage() {
  await requireAdmin();

  const supabase = await createServerSupabaseClient();

  const [onboardingResult, growthResult] = await Promise.all([
    supabase.rpc("get_admin_onboarding_analytics"),
    supabase.rpc("get_admin_growth_analytics", {
      p_days: GROWTH_WINDOW_DAYS,
    }),
  ]);

  if (onboardingResult.error) {
    console.error(
      "get_admin_onboarding_analytics failed",
      onboardingResult.error,
    );
  }
  if (growthResult.error) {
    console.error("get_admin_growth_analytics failed", growthResult.error);
  }

  const totals = (onboardingResult.data as OnboardingAnalytics | null) ?? {
    totalCustomers: 0,
    totalStaff: 0,
    totalAdmins: 0,
    totalStaffOnboarded: 0,
    staffOnboardings: [],
  };

  const growthRows = (growthResult.data as GrowthAnalyticsRow[] | null) ?? [];
  const series = toGrowthChartSeries(growthRows);

  const cards = [
    { label: "Customers", value: totals.totalCustomers },
    { label: "Staff", value: totals.totalStaff },
    { label: "Admins", value: totals.totalAdmins },
    { label: "Staff onboarded", value: totals.totalStaffOnboarded },
  ];

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Overview"
        description={`Account totals and signup growth over the last ${GROWTH_WINDOW_DAYS} days.`}
      />

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {cards.map((card) => (
          <div
            key={card.label}
            className="rounded-xl border border-zinc-200 bg-white px-5 py-4 shadow-sm"
          >
            <p className="text-sm text-zinc-500">{card.label}</p>
            <p className="mt-1 text-3xl font-semibold tracking-tight text-zinc-900">
              {card.value}
            </p>
          </div>
        ))}
      </div>

      <AdminSection
        title="Signup growth"
        description={`New customers vs. new staff per day, last ${GROWTH_WINDOW_DAYS} days.`}
      >
        {series.length === 0 ? (
          <p className="text-sm text-zinc-500">No signup data yet.</p>
        ) : (
          <OverviewGrowthChart data={series} />
        )}
      </AdminSection>
    </div>
  );
}
