"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import {
  AdminCheckbox,
  AdminField,
  AdminSection,
  adminControlClassName,
  adminTextareaClassName,
} from "@/components/admin/admin-ui";
import {
  REFERRAL_PLACEHOLDERS,
  type NotificationSettingsValues,
} from "@/lib/admin/notifications";

import { saveNotificationSettings, type NotificationActionState } from "../actions";

function MessagePair({
  heading,
  titleName,
  bodyName,
  titleValue,
  bodyValue,
}: {
  heading: string;
  titleName: string;
  bodyName: string;
  titleValue: string;
  bodyValue: string;
}) {
  return (
    <div className="grid gap-4 border-t border-zinc-100 pt-4 md:grid-cols-2">
      <p className="text-sm font-medium text-zinc-900 md:col-span-2">{heading}</p>
      <AdminField label="Title" htmlFor={titleName}>
        <input
          id={titleName}
          name={titleName}
          defaultValue={titleValue}
          className={adminControlClassName}
        />
      </AdminField>
      <AdminField label="Message" htmlFor={bodyName}>
        <textarea
          id={bodyName}
          name={bodyName}
          defaultValue={bodyValue}
          className={adminTextareaClassName}
        />
      </AdminField>
    </div>
  );
}

export function NotificationSettingsForm({
  settings,
}: {
  settings: NotificationSettingsValues;
}) {
  const [state, action, pending] = useActionState<
    NotificationActionState,
    FormData
  >(saveNotificationSettings, null);

  return (
    <form action={action} className="flex flex-col gap-6">
      <AdminSection
        title="Birthday"
        description="Coupon defaults and the message sent on a member's birthday."
      >
        <div className="flex flex-col gap-4">
          <AdminCheckbox
            name="birthdayCouponEnabled"
            defaultChecked={settings.birthdayCouponEnabled}
            label="Birthday coupon enabled"
          />
          <div className="grid gap-4 md:grid-cols-3">
            <AdminField label="Birthday discount (%)" htmlFor="birthdayCouponDiscountPercent">
              <input
                id="birthdayCouponDiscountPercent"
                name="birthdayCouponDiscountPercent"
                type="number"
                min={0}
                max={100}
                required
                defaultValue={settings.birthdayCouponDiscountPercent}
                className={adminControlClassName}
              />
            </AdminField>
            <AdminField label="Birthday coupon validity (days)" htmlFor="birthdayCouponValidityDays">
              <input
                id="birthdayCouponValidityDays"
                name="birthdayCouponValidityDays"
                type="number"
                min={0}
                required
                defaultValue={settings.birthdayCouponValidityDays}
                className={adminControlClassName}
              />
            </AdminField>
            <AdminField label="Minimum order (£)" htmlFor="birthdayCouponMinOrderPounds">
              <input
                id="birthdayCouponMinOrderPounds"
                name="birthdayCouponMinOrderPounds"
                type="number"
                min={0}
                step="0.01"
                required
                defaultValue={(settings.birthdayCouponMinOrderCents / 100).toFixed(2)}
                className={adminControlClassName}
              />
            </AdminField>
          </div>
          <MessagePair
            heading="Birthday notification"
            titleName="birthdayNotificationTitle"
            bodyName="birthdayNotificationBody"
            titleValue={settings.birthdayNotificationTitle}
            bodyValue={settings.birthdayNotificationBody}
          />
          <MessagePair
            heading="Birthday coupon"
            titleName="birthdayCouponTitle"
            bodyName="birthdayCouponDescription"
            titleValue={settings.birthdayCouponTitle}
            bodyValue={settings.birthdayCouponDescription}
          />
        </div>
      </AdminSection>

      <AdminSection
        title="Challenge reminders"
        description="When reminders go out, and the five challenge messages."
      >
        <div className="flex flex-col gap-4">
          <AdminCheckbox
            name="challengeReminderEnabled"
            defaultChecked={settings.challengeReminderEnabled}
            label="Challenge reminders enabled"
          />
          <div className="grid gap-4 md:grid-cols-2">
            <AdminField
              label="Streak reminder hour"
              htmlFor="challengeStreakReminderHour"
              hint="24-hour clock, 0 to 23."
            >
              <input
                id="challengeStreakReminderHour"
                name="challengeStreakReminderHour"
                type="number"
                min={0}
                max={23}
                required
                defaultValue={settings.challengeStreakReminderHour}
                className={adminControlClassName}
              />
            </AdminField>
            <AdminField label="Inactive days threshold" htmlFor="challengeInactiveDaysThreshold">
              <input
                id="challengeInactiveDaysThreshold"
                name="challengeInactiveDaysThreshold"
                type="number"
                min={0}
                required
                defaultValue={settings.challengeInactiveDaysThreshold}
                className={adminControlClassName}
              />
            </AdminField>
          </div>
          <MessagePair
            heading="Streak at risk"
            titleName="challengeStreakAtRiskTitle"
            bodyName="challengeStreakAtRiskBody"
            titleValue={settings.challengeStreakAtRiskTitle}
            bodyValue={settings.challengeStreakAtRiskBody}
          />
          <MessagePair
            heading="Near completion"
            titleName="challengeNearCompletionTitle"
            bodyName="challengeNearCompletionBody"
            titleValue={settings.challengeNearCompletionTitle}
            bodyValue={settings.challengeNearCompletionBody}
          />
          <MessagePair
            heading="Inactive player"
            titleName="challengeInactiveTitle"
            bodyName="challengeInactiveBody"
            titleValue={settings.challengeInactiveTitle}
            bodyValue={settings.challengeInactiveBody}
          />
          <MessagePair
            heading="Streak broken"
            titleName="challengeStreakBrokenTitle"
            bodyName="challengeStreakBrokenBody"
            titleValue={settings.challengeStreakBrokenTitle}
            bodyValue={settings.challengeStreakBrokenBody}
          />
          <MessagePair
            heading="Ending soon"
            titleName="challengeEndingSoonTitle"
            bodyName="challengeEndingSoonBody"
            titleValue={settings.challengeEndingSoonTitle}
            bodyValue={settings.challengeEndingSoonBody}
          />
        </div>
      </AdminSection>

      <AdminSection
        title="Step challenge reminders"
        description="Messages for walking challenges."
      >
        <div className="flex flex-col gap-4">
          <MessagePair
            heading="Low activity"
            titleName="stepLowActivityTitle"
            bodyName="stepLowActivityBody"
            titleValue={settings.stepLowActivityTitle}
            bodyValue={settings.stepLowActivityBody}
          />
          <MessagePair
            heading="Near daily goal"
            titleName="stepNearDailyGoalTitle"
            bodyName="stepNearDailyGoalBody"
            titleValue={settings.stepNearDailyGoalTitle}
            bodyValue={settings.stepNearDailyGoalBody}
          />
          <MessagePair
            heading="Walk streak at risk"
            titleName="stepStreakAtRiskTitle"
            bodyName="stepStreakAtRiskBody"
            titleValue={settings.stepStreakAtRiskTitle}
            bodyValue={settings.stepStreakAtRiskBody}
          />
          <MessagePair
            heading="Sync reminder"
            titleName="stepSyncReminderTitle"
            bodyName="stepSyncReminderBody"
            titleValue={settings.stepSyncReminderTitle}
            bodyValue={settings.stepSyncReminderBody}
          />
        </div>
      </AdminSection>

      <AdminSection
        title="Referral notifications"
        description="Welcome, progress, and milestone messages."
      >
        <div className="flex flex-col gap-4">
          <AdminCheckbox
            name="referralNotificationsEnabled"
            defaultChecked={settings.referralNotificationsEnabled}
            label="Referral notifications enabled"
          />
          <p className="text-xs text-zinc-500">
            Placeholders:{" "}
            {REFERRAL_PLACEHOLDERS.map((item) => item.token).join(", ")}
          </p>
          <MessagePair
            heading="New member (used a code)"
            titleName="referralRefereeWelcomeTitle"
            bodyName="referralRefereeWelcomeBody"
            titleValue={settings.referralRefereeWelcomeTitle}
            bodyValue={settings.referralRefereeWelcomeBody}
          />
          <MessagePair
            heading="Referrer — successful invite"
            titleName="referralReferrerSuccessTitle"
            bodyName="referralReferrerSuccessBody"
            titleValue={settings.referralReferrerSuccessTitle}
            bodyValue={settings.referralReferrerSuccessBody}
          />
          <MessagePair
            heading="Referrer — progress nudge"
            titleName="referralProgressNudgeTitle"
            bodyName="referralProgressNudgeBody"
            titleValue={settings.referralProgressNudgeTitle}
            bodyValue={settings.referralProgressNudgeBody}
          />
          <MessagePair
            heading="Referrer — goal complete"
            titleName="referralMilestoneTitle"
            bodyName="referralMilestoneBody"
            titleValue={settings.referralMilestoneTitle}
            bodyValue={settings.referralMilestoneBody}
          />
        </div>
      </AdminSection>

      <AdminSection title="Order alerts" description="Which order updates members receive.">
        <div className="grid gap-3 md:grid-cols-3">
          <AdminCheckbox
            name="orderNotifyReady"
            defaultChecked={settings.orderNotifyReady}
            label="Notify when order is ready"
          />
          <AdminCheckbox
            name="orderNotifyCancelled"
            defaultChecked={settings.orderNotifyCancelled}
            label="Notify when order is cancelled"
          />
          <AdminCheckbox
            name="orderNotifyConfirmed"
            defaultChecked={settings.orderNotifyConfirmed}
            label="Notify when order is confirmed"
          />
        </div>
      </AdminSection>

      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" size="sm" className="rounded-lg" disabled={pending}>
          {pending ? "Saving…" : "Save"}
        </Button>
        {state?.error ? <p className="text-sm text-red-600">{state.error}</p> : null}
        {state?.success ? (
          <p className="text-sm text-emerald-700">{state.success}</p>
        ) : null}
      </div>
    </form>
  );
}
