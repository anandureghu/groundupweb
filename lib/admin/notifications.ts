export const AUDIENCE_OPTIONS = [
  { id: "all", label: "All customers" },
  { id: "inactive_7d", label: "Inactive 7+ days" },
  { id: "birthday_this_week", label: "Birthday this week" },
  { id: "has_unused_coupon", label: "Has unused coupon" },
] as const;

export type AudienceId = (typeof AUDIENCE_OPTIONS)[number]["id"];

export const BROADCAST_PLACEHOLDERS = [
  { token: "{first_name}", description: "Recipient first name" },
] as const;

export const REFERRAL_PLACEHOLDERS = [
  { token: "{first_name}", description: "Recipient first name" },
  { token: "{points}", description: "Points awarded for this event" },
  { token: "{count}", description: "Successful referral count" },
  { token: "{target}", description: "Referral program target" },
  { token: "{bonus}", description: "Milestone bonus points" },
] as const;

export const BROADCAST_STATUSES = [
  "draft",
  "scheduled",
  "sending",
  "sent",
  "cancelled",
] as const;

export type BroadcastStatus = (typeof BROADCAST_STATUSES)[number];

const STATUS_LABELS: Record<BroadcastStatus, string> = {
  draft: "Draft",
  scheduled: "Scheduled",
  sending: "Sending",
  sent: "Sent",
  cancelled: "Cancelled",
};

export type AudiencePayload = {
  audienceType: "all" | "segment";
  audienceFilter: Record<string, string>;
  audienceSegment: string | null;
};

export function isAudienceId(value: string): value is AudienceId {
  return AUDIENCE_OPTIONS.some((option) => option.id === value);
}

export function audiencePayload(audience: AudienceId): AudiencePayload {
  if (audience === "all") {
    return { audienceType: "all", audienceFilter: {}, audienceSegment: null };
  }

  return {
    audienceType: "segment",
    audienceFilter: { segment: audience },
    audienceSegment: audience,
  };
}

export function audienceLabel(
  audienceType: string,
  audienceFilter: Record<string, unknown> | null | undefined,
): string {
  if (audienceType === "all") {
    return "All customers";
  }

  const segment =
    typeof audienceFilter?.segment === "string" ? audienceFilter.segment : "";
  return (
    AUDIENCE_OPTIONS.find((option) => option.id === segment)?.label ??
    (segment || audienceType)
  );
}

export function selectionFromTemplate(
  audienceType: string,
  audienceSegment: string | null,
): AudienceId {
  if (
    audienceType === "segment" &&
    audienceSegment &&
    isAudienceId(audienceSegment)
  ) {
    return audienceSegment;
  }
  return "all";
}

export function broadcastStatusLabel(status: string): string {
  if ((BROADCAST_STATUSES as readonly string[]).includes(status)) {
    return STATUS_LABELS[status as BroadcastStatus];
  }
  return status;
}

export function canCancelBroadcast(status: string): boolean {
  return status === "draft" || status === "scheduled";
}

export function parseScheduleInput(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) {
    return null;
  }
  const date = new Date(trimmed);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date.toISOString();
}

export function poundsToCents(raw: string): number | null {
  const trimmed = raw.trim();
  if (!trimmed) {
    return null;
  }
  const value = Number(trimmed);
  if (!Number.isFinite(value) || value < 0) {
    return null;
  }
  return Math.round(value * 100);
}

export function parseNonNegativeInt(raw: string): number | null {
  const trimmed = raw.trim();
  if (!trimmed) {
    return null;
  }
  const value = Number(trimmed);
  if (!Number.isInteger(value) || value < 0) {
    return null;
  }
  return value;
}

export function parseHour(raw: string): number | null {
  const value = parseNonNegativeInt(raw);
  if (value === null || value > 23) {
    return null;
  }
  return value;
}

export function parsePercent(raw: string): number | null {
  const value = parseNonNegativeInt(raw);
  if (value === null || value > 100) {
    return null;
  }
  return value;
}

export type NotificationSettingsValues = {
  birthdayCouponEnabled: boolean;
  birthdayCouponDiscountPercent: number;
  birthdayCouponValidityDays: number;
  birthdayCouponMinOrderCents: number;
  challengeReminderEnabled: boolean;
  challengeStreakReminderHour: number;
  challengeInactiveDaysThreshold: number;
  orderNotifyReady: boolean;
  orderNotifyCancelled: boolean;
  orderNotifyConfirmed: boolean;
  referralNotificationsEnabled: boolean;
  birthdayNotificationTitle: string;
  birthdayNotificationBody: string;
  birthdayCouponTitle: string;
  birthdayCouponDescription: string;
  challengeStreakAtRiskTitle: string;
  challengeStreakAtRiskBody: string;
  challengeNearCompletionTitle: string;
  challengeNearCompletionBody: string;
  challengeInactiveTitle: string;
  challengeInactiveBody: string;
  challengeStreakBrokenTitle: string;
  challengeStreakBrokenBody: string;
  challengeEndingSoonTitle: string;
  challengeEndingSoonBody: string;
  stepLowActivityTitle: string;
  stepLowActivityBody: string;
  stepNearDailyGoalTitle: string;
  stepNearDailyGoalBody: string;
  stepStreakAtRiskTitle: string;
  stepStreakAtRiskBody: string;
  stepSyncReminderTitle: string;
  stepSyncReminderBody: string;
  referralRefereeWelcomeTitle: string;
  referralRefereeWelcomeBody: string;
  referralReferrerSuccessTitle: string;
  referralReferrerSuccessBody: string;
  referralProgressNudgeTitle: string;
  referralProgressNudgeBody: string;
  referralMilestoneTitle: string;
  referralMilestoneBody: string;
};

export type NotificationSettingsRow = {
  birthday_coupon_enabled: number;
  birthday_coupon_discount_percent: number;
  birthday_coupon_validity_days: number;
  birthday_coupon_min_order_cents: number;
  challenge_reminder_enabled: number;
  challenge_streak_reminder_hour: number;
  challenge_inactive_days_threshold: number;
  order_notify_ready: number;
  order_notify_cancelled: number;
  order_notify_confirmed: number;
  referral_notifications_enabled: number;
  birthday_notification_title: string | null;
  birthday_notification_body: string | null;
  birthday_coupon_title: string | null;
  birthday_coupon_description: string | null;
  challenge_streak_at_risk_title: string | null;
  challenge_streak_at_risk_body: string | null;
  challenge_near_completion_title: string | null;
  challenge_near_completion_body: string | null;
  challenge_inactive_title: string | null;
  challenge_inactive_body: string | null;
  challenge_streak_broken_title: string | null;
  challenge_streak_broken_body: string | null;
  challenge_ending_soon_title: string | null;
  challenge_ending_soon_body: string | null;
  step_low_activity_title: string | null;
  step_low_activity_body: string | null;
  step_near_daily_goal_title: string | null;
  step_near_daily_goal_body: string | null;
  step_streak_at_risk_title: string | null;
  step_streak_at_risk_body: string | null;
  step_sync_reminder_title: string | null;
  step_sync_reminder_body: string | null;
  referral_referee_welcome_title: string | null;
  referral_referee_welcome_body: string | null;
  referral_referrer_success_title: string | null;
  referral_referrer_success_body: string | null;
  referral_progress_nudge_title: string | null;
  referral_progress_nudge_body: string | null;
  referral_milestone_title: string | null;
  referral_milestone_body: string | null;
};

function text(value: string | null | undefined): string {
  return value ?? "";
}

export function notificationSettingsFromRow(
  row: NotificationSettingsRow,
): NotificationSettingsValues {
  return {
    birthdayCouponEnabled: row.birthday_coupon_enabled === 1,
    birthdayCouponDiscountPercent: row.birthday_coupon_discount_percent,
    birthdayCouponValidityDays: row.birthday_coupon_validity_days,
    birthdayCouponMinOrderCents: row.birthday_coupon_min_order_cents,
    challengeReminderEnabled: row.challenge_reminder_enabled === 1,
    challengeStreakReminderHour: row.challenge_streak_reminder_hour,
    challengeInactiveDaysThreshold: row.challenge_inactive_days_threshold,
    orderNotifyReady: row.order_notify_ready === 1,
    orderNotifyCancelled: row.order_notify_cancelled === 1,
    orderNotifyConfirmed: row.order_notify_confirmed === 1,
    referralNotificationsEnabled: row.referral_notifications_enabled === 1,
    birthdayNotificationTitle: text(row.birthday_notification_title),
    birthdayNotificationBody: text(row.birthday_notification_body),
    birthdayCouponTitle: text(row.birthday_coupon_title),
    birthdayCouponDescription: text(row.birthday_coupon_description),
    challengeStreakAtRiskTitle: text(row.challenge_streak_at_risk_title),
    challengeStreakAtRiskBody: text(row.challenge_streak_at_risk_body),
    challengeNearCompletionTitle: text(row.challenge_near_completion_title),
    challengeNearCompletionBody: text(row.challenge_near_completion_body),
    challengeInactiveTitle: text(row.challenge_inactive_title),
    challengeInactiveBody: text(row.challenge_inactive_body),
    challengeStreakBrokenTitle: text(row.challenge_streak_broken_title),
    challengeStreakBrokenBody: text(row.challenge_streak_broken_body),
    challengeEndingSoonTitle: text(row.challenge_ending_soon_title),
    challengeEndingSoonBody: text(row.challenge_ending_soon_body),
    stepLowActivityTitle: text(row.step_low_activity_title),
    stepLowActivityBody: text(row.step_low_activity_body),
    stepNearDailyGoalTitle: text(row.step_near_daily_goal_title),
    stepNearDailyGoalBody: text(row.step_near_daily_goal_body),
    stepStreakAtRiskTitle: text(row.step_streak_at_risk_title),
    stepStreakAtRiskBody: text(row.step_streak_at_risk_body),
    stepSyncReminderTitle: text(row.step_sync_reminder_title),
    stepSyncReminderBody: text(row.step_sync_reminder_body),
    referralRefereeWelcomeTitle: text(row.referral_referee_welcome_title),
    referralRefereeWelcomeBody: text(row.referral_referee_welcome_body),
    referralReferrerSuccessTitle: text(row.referral_referrer_success_title),
    referralReferrerSuccessBody: text(row.referral_referrer_success_body),
    referralProgressNudgeTitle: text(row.referral_progress_nudge_title),
    referralProgressNudgeBody: text(row.referral_progress_nudge_body),
    referralMilestoneTitle: text(row.referral_milestone_title),
    referralMilestoneBody: text(row.referral_milestone_body),
  };
}

export type ParsedNotificationSettings = {
  integers: Array<[string, number]>;
  texts: Array<[string, string]>;
};

export type NotificationSettingsFormInput = {
  birthdayCouponEnabled: boolean;
  birthdayCouponDiscountPercent: string;
  birthdayCouponValidityDays: string;
  birthdayCouponMinOrderPounds: string;
  challengeReminderEnabled: boolean;
  challengeStreakReminderHour: string;
  challengeInactiveDaysThreshold: string;
  orderNotifyReady: boolean;
  orderNotifyCancelled: boolean;
  orderNotifyConfirmed: boolean;
  referralNotificationsEnabled: boolean;
  birthdayNotificationTitle: string;
  birthdayNotificationBody: string;
  birthdayCouponTitle: string;
  birthdayCouponDescription: string;
  challengeStreakAtRiskTitle: string;
  challengeStreakAtRiskBody: string;
  challengeNearCompletionTitle: string;
  challengeNearCompletionBody: string;
  challengeInactiveTitle: string;
  challengeInactiveBody: string;
  challengeStreakBrokenTitle: string;
  challengeStreakBrokenBody: string;
  challengeEndingSoonTitle: string;
  challengeEndingSoonBody: string;
  stepLowActivityTitle: string;
  stepLowActivityBody: string;
  stepNearDailyGoalTitle: string;
  stepNearDailyGoalBody: string;
  stepStreakAtRiskTitle: string;
  stepStreakAtRiskBody: string;
  stepSyncReminderTitle: string;
  stepSyncReminderBody: string;
  referralRefereeWelcomeTitle: string;
  referralRefereeWelcomeBody: string;
  referralReferrerSuccessTitle: string;
  referralReferrerSuccessBody: string;
  referralProgressNudgeTitle: string;
  referralProgressNudgeBody: string;
  referralMilestoneTitle: string;
  referralMilestoneBody: string;
};

export function parseNotificationSettingsForm(
  input: NotificationSettingsFormInput,
): { ok: true; value: ParsedNotificationSettings } | { ok: false; error: string } {
  const discount = parsePercent(String(input.birthdayCouponDiscountPercent));
  if (discount === null) {
    return { ok: false, error: "Birthday discount must be a whole number from 0 to 100." };
  }

  const validity = parseNonNegativeInt(String(input.birthdayCouponValidityDays));
  if (validity === null) {
    return { ok: false, error: "Birthday coupon validity must be a non-negative whole number of days." };
  }

  const minOrderCents = poundsToCents(input.birthdayCouponMinOrderPounds);
  if (minOrderCents === null) {
    return { ok: false, error: "Minimum order must be a non-negative amount." };
  }

  const hour = parseHour(String(input.challengeStreakReminderHour));
  if (hour === null) {
    return { ok: false, error: "Streak reminder hour must be a whole number from 0 to 23." };
  }

  const inactiveDays = parseNonNegativeInt(String(input.challengeInactiveDaysThreshold));
  if (inactiveDays === null) {
    return { ok: false, error: "Inactive days must be a non-negative whole number." };
  }

  const flag = (enabled: boolean) => (enabled ? 1 : 0);

  return {
    ok: true,
    value: {
      integers: [
        ["birthday_coupon_enabled", flag(input.birthdayCouponEnabled)],
        ["birthday_coupon_discount_percent", discount],
        ["birthday_coupon_validity_days", validity],
        ["birthday_coupon_min_order_cents", minOrderCents],
        ["challenge_reminder_enabled", flag(input.challengeReminderEnabled)],
        ["challenge_streak_reminder_hour", hour],
        ["challenge_inactive_days_threshold", inactiveDays],
        ["order_notify_ready", flag(input.orderNotifyReady)],
        ["order_notify_cancelled", flag(input.orderNotifyCancelled)],
        ["order_notify_confirmed", flag(input.orderNotifyConfirmed)],
        ["referral_notifications_enabled", flag(input.referralNotificationsEnabled)],
      ],
      texts: [
        ["birthday_notification_title", input.birthdayNotificationTitle.trim()],
        ["birthday_notification_body", input.birthdayNotificationBody.trim()],
        ["birthday_coupon_title", input.birthdayCouponTitle.trim()],
        ["birthday_coupon_description", input.birthdayCouponDescription.trim()],
        ["challenge_streak_at_risk_title", input.challengeStreakAtRiskTitle.trim()],
        ["challenge_streak_at_risk_body", input.challengeStreakAtRiskBody.trim()],
        ["challenge_near_completion_title", input.challengeNearCompletionTitle.trim()],
        ["challenge_near_completion_body", input.challengeNearCompletionBody.trim()],
        ["challenge_inactive_title", input.challengeInactiveTitle.trim()],
        ["challenge_inactive_body", input.challengeInactiveBody.trim()],
        ["challenge_streak_broken_title", input.challengeStreakBrokenTitle.trim()],
        ["challenge_streak_broken_body", input.challengeStreakBrokenBody.trim()],
        ["challenge_ending_soon_title", input.challengeEndingSoonTitle.trim()],
        ["challenge_ending_soon_body", input.challengeEndingSoonBody.trim()],
        ["step_low_activity_title", input.stepLowActivityTitle.trim()],
        ["step_low_activity_body", input.stepLowActivityBody.trim()],
        ["step_near_daily_goal_title", input.stepNearDailyGoalTitle.trim()],
        ["step_near_daily_goal_body", input.stepNearDailyGoalBody.trim()],
        ["step_streak_at_risk_title", input.stepStreakAtRiskTitle.trim()],
        ["step_streak_at_risk_body", input.stepStreakAtRiskBody.trim()],
        ["step_sync_reminder_title", input.stepSyncReminderTitle.trim()],
        ["step_sync_reminder_body", input.stepSyncReminderBody.trim()],
        ["referral_referee_welcome_title", input.referralRefereeWelcomeTitle.trim()],
        ["referral_referee_welcome_body", input.referralRefereeWelcomeBody.trim()],
        ["referral_referrer_success_title", input.referralReferrerSuccessTitle.trim()],
        ["referral_referrer_success_body", input.referralReferrerSuccessBody.trim()],
        ["referral_progress_nudge_title", input.referralProgressNudgeTitle.trim()],
        ["referral_progress_nudge_body", input.referralProgressNudgeBody.trim()],
        ["referral_milestone_title", input.referralMilestoneTitle.trim()],
        ["referral_milestone_body", input.referralMilestoneBody.trim()],
      ],
    },
  };
}

export function checked(formData: FormData, name: string): boolean {
  return formData.get(name) === "on";
}

export function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? "");
}

export function rowsOf<T>(data: T | T[] | null | undefined): T[] {
  if (!data) {
    return [];
  }
  return Array.isArray(data) ? data : [data];
}
