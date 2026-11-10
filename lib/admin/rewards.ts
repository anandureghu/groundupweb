export type RewardsOverviewRow = {
  total_outstanding_points: number;
  members_with_points: number;
  total_customers: number;
  total_points_awarded: number;
  total_points_redeemed: number;
  points_per_pound: number;
};

export type LeaderboardMember = {
  id: string;
  name: string;
  email: string;
  pointsBalance: number;
};

export function formatPoints(points: number): string {
  return points.toLocaleString("en-GB");
}

export function estimatedPoundsValue(
  points: number,
  pointsPerPound: number,
): string {
  if (pointsPerPound <= 0) {
    return "—";
  }
  const pounds = points / pointsPerPound;
  return pounds.toLocaleString("en-GB", {
    style: "currency",
    currency: "GBP",
    maximumFractionDigits: 0,
  });
}

export function parsePointsDelta(raw: string): number | null {
  const trimmed = raw.trim();
  if (!trimmed) {
    return null;
  }
  const value = Number(trimmed);
  if (!Number.isInteger(value) || value === 0) {
    return null;
  }
  return value;
}
