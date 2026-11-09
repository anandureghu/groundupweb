import { describe, expect, it } from "vitest";

import {
  audienceLabel,
  audiencePayload,
  canCancelBroadcast,
  parseHour,
  parseNotificationSettingsForm,
  parseScheduleInput,
  poundsToCents,
  selectionFromTemplate,
} from "./notifications";

const blankTexts = {
  birthdayNotificationTitle: "  Happy birthday  ",
  birthdayNotificationBody: "",
  birthdayCouponTitle: "",
  birthdayCouponDescription: "",
  challengeStreakAtRiskTitle: "",
  challengeStreakAtRiskBody: "",
  challengeNearCompletionTitle: "",
  challengeNearCompletionBody: "",
  challengeInactiveTitle: "",
  challengeInactiveBody: "",
  challengeStreakBrokenTitle: "",
  challengeStreakBrokenBody: "",
  challengeEndingSoonTitle: "",
  challengeEndingSoonBody: "",
  stepLowActivityTitle: "",
  stepLowActivityBody: "",
  stepNearDailyGoalTitle: "",
  stepNearDailyGoalBody: "",
  stepStreakAtRiskTitle: "",
  stepStreakAtRiskBody: "",
  stepSyncReminderTitle: "",
  stepSyncReminderBody: "",
  referralRefereeWelcomeTitle: "",
  referralRefereeWelcomeBody: "",
  referralReferrerSuccessTitle: "",
  referralReferrerSuccessBody: "",
  referralProgressNudgeTitle: "",
  referralProgressNudgeBody: "",
  referralMilestoneTitle: "",
  referralMilestoneBody: "",
};

describe("audiencePayload", () => {
  it("sends every customer when the audience is all", () => {
    expect(audiencePayload("all")).toEqual({
      audienceType: "all",
      audienceFilter: {},
      audienceSegment: null,
    });
  });

  it("stores a segment filter for a named audience", () => {
    expect(audiencePayload("inactive_7d")).toEqual({
      audienceType: "segment",
      audienceFilter: { segment: "inactive_7d" },
      audienceSegment: "inactive_7d",
    });
  });
});

describe("audience labels", () => {
  it("labels stored broadcasts and templates", () => {
    expect(audienceLabel("all", {})).toBe("All customers");
    expect(audienceLabel("segment", { segment: "birthday_this_week" })).toBe(
      "Birthday this week",
    );
    expect(selectionFromTemplate("segment", "has_unused_coupon")).toBe(
      "has_unused_coupon",
    );
    expect(selectionFromTemplate("all", null)).toBe("all");
  });
});

describe("broadcast helpers", () => {
  it("allows cancel only before a broadcast has started", () => {
    expect(canCancelBroadcast("scheduled")).toBe(true);
    expect(canCancelBroadcast("draft")).toBe(true);
    expect(canCancelBroadcast("sent")).toBe(false);
  });

  it("parses a schedule into an ISO timestamp", () => {
    expect(parseScheduleInput("")).toBeNull();
    expect(parseScheduleInput("not-a-date")).toBeNull();
    expect(parseScheduleInput("2026-11-09T14:30")).toMatch(/2026-11-09T/);
  });
});

describe("parseNotificationSettingsForm", () => {
  it("converts pounds to cents and flags to integers", () => {
    const parsed = parseNotificationSettingsForm({
      ...blankTexts,
      birthdayCouponEnabled: true,
      birthdayCouponDiscountPercent: "15",
      birthdayCouponValidityDays: "14",
      birthdayCouponMinOrderPounds: "4.50",
      challengeReminderEnabled: false,
      challengeStreakReminderHour: "20",
      challengeInactiveDaysThreshold: "3",
      orderNotifyReady: true,
      orderNotifyCancelled: false,
      orderNotifyConfirmed: false,
      referralNotificationsEnabled: true,
    });

    expect(parsed.ok).toBe(true);
    if (!parsed.ok) return;
    expect(parsed.value.integers).toEqual(
      expect.arrayContaining([
        ["birthday_coupon_enabled", 1],
        ["birthday_coupon_min_order_cents", 450],
        ["challenge_reminder_enabled", 0],
        ["referral_notifications_enabled", 1],
      ]),
    );
    expect(parsed.value.texts).toEqual(
      expect.arrayContaining([["birthday_notification_title", "Happy birthday"]]),
    );
  });

  it("rejects an hour outside 0 to 23", () => {
    const parsed = parseNotificationSettingsForm({
      ...blankTexts,
      birthdayCouponEnabled: true,
      birthdayCouponDiscountPercent: "10",
      birthdayCouponValidityDays: "1",
      birthdayCouponMinOrderPounds: "0",
      challengeReminderEnabled: true,
      challengeStreakReminderHour: "24",
      challengeInactiveDaysThreshold: "1",
      orderNotifyReady: true,
      orderNotifyCancelled: true,
      orderNotifyConfirmed: false,
      referralNotificationsEnabled: true,
    });
    expect(parsed).toEqual({
      ok: false,
      error: "Streak reminder hour must be a whole number from 0 to 23.",
    });
  });
});

describe("money and hour parsers", () => {
  it("rounds pounds to cents", () => {
    expect(poundsToCents("1.005")).toBe(100);
    expect(poundsToCents("-1")).toBeNull();
  });

  it("accepts hours through 23", () => {
    expect(parseHour("0")).toBe(0);
    expect(parseHour("23")).toBe(23);
    expect(parseHour("24")).toBeNull();
  });
});
