import { describe, it, expect } from "vitest";
import { toGrowthChartSeries } from "./growth-chart";

describe("toGrowthChartSeries", () => {
  it("maps snake_case RPC rows to chart-ready series, preserving order", () => {
    expect(
      toGrowthChartSeries([
        { day: "2026-11-01", new_customers: 3, new_staff: 0 },
        { day: "2026-11-02", new_customers: 1, new_staff: 1 },
      ]),
    ).toEqual([
      { date: "2026-11-01", customers: 3, staff: 0 },
      { date: "2026-11-02", customers: 1, staff: 1 },
    ]);
  });
});
