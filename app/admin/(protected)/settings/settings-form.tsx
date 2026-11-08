"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import {
  AdminField,
  AdminSection,
  adminControlClassName,
} from "@/components/admin/admin-ui";

import { saveAppSetting, type SettingsActionState } from "./actions";

export type AppSettingRow = {
  key: string;
  valueInteger: number;
  valueText: string | null;
  description: string | null;
  updatedAt: string;
};

export function SettingsForm({ settings }: { settings: AppSettingRow[] }) {
  return (
    <div className="flex flex-col gap-4">
      {settings.map((setting) => (
        <SettingCard key={setting.key} setting={setting} />
      ))}
    </div>
  );
}

function SettingCard({ setting }: { setting: AppSettingRow }) {
  const [state, action, pending] = useActionState<
    SettingsActionState,
    FormData
  >(saveAppSetting, null);

  return (
    <AdminSection
      title={setting.key}
      description={setting.description ?? undefined}
    >
      <form action={action} className="flex flex-col gap-4">
        <input type="hidden" name="key" value={setting.key} />

        <div className="grid gap-4 md:grid-cols-2">
          <AdminField label="Integer value" htmlFor={`${setting.key}-int`}>
            <input
              id={`${setting.key}-int`}
              name="value_integer"
              type="number"
              min={0}
              defaultValue={setting.valueInteger}
              required
              className={adminControlClassName}
            />
          </AdminField>
          <AdminField label="Text value" htmlFor={`${setting.key}-text`}>
            <input
              id={`${setting.key}-text`}
              name="value_text"
              defaultValue={setting.valueText ?? ""}
              className={adminControlClassName}
            />
          </AdminField>
          <AdminField
            label="Description"
            htmlFor={`${setting.key}-desc`}
            className="md:col-span-2"
          >
            <input
              id={`${setting.key}-desc`}
              name="description"
              defaultValue={setting.description ?? ""}
              className={adminControlClassName}
            />
          </AdminField>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit" size="sm" disabled={pending} className="rounded-lg">
            {pending ? "Saving…" : "Save"}
          </Button>
          {state?.error ? (
            <p className="text-sm text-red-600">{state.error}</p>
          ) : null}
          {state?.success ? (
            <p className="text-sm text-emerald-700">{state.success}</p>
          ) : null}
        </div>
      </form>
    </AdminSection>
  );
}
