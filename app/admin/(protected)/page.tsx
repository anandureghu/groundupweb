import type { Metadata } from "next";

import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
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
      <div>
        <h1 className="text-2xl font-semibold">Overview</h1>
        <p className="text-sm text-muted-foreground">
          Account totals and signup growth over the last {GROWTH_WINDOW_DAYS}{" "}
          days.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {cards.map((card) => (
          <Card key={card.label}>
            <CardHeader>
              <CardDescription>{card.label}</CardDescription>
              <CardTitle className="text-3xl normal-case tracking-normal">
                {card.value}
              </CardTitle>
            </CardHeader>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Signup growth</CardTitle>
          <CardDescription>
            New customers vs. new staff per day, last {GROWTH_WINDOW_DAYS}{" "}
            days
          </CardDescription>
        </CardHeader>
        <CardContent>
          {series.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No signup data yet.
            </p>
          ) : (
            <OverviewGrowthChart data={series} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
