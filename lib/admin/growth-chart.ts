export type GrowthAnalyticsRow = {
  day: string;
  new_customers: number;
  new_staff: number;
};

export type GrowthChartPoint = {
  date: string;
  customers: number;
  staff: number;
};

export function toGrowthChartSeries(
  rows: GrowthAnalyticsRow[],
): GrowthChartPoint[] {
  return rows.map((row) => ({
    date: row.day,
    customers: row.new_customers,
    staff: row.new_staff,
  }));
}
