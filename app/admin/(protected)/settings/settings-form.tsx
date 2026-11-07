"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

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
    <div className="flex flex-col gap-6">
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
    <form
      action={action}
      className="flex flex-col gap-3 border border-border p-4"
    >
      <input type="hidden" name="key" value={setting.key} />
      <div className="flex flex-col gap-1">
        <p className="font-mono text-sm font-semibold">{setting.key}</p>
        {setting.description ? (
          <p className="text-xs text-muted-foreground">{setting.description}</p>
        ) : null}
      </div>

      <div className="grid gap-3 md:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${setting.key}-int`}>Integer value</Label>
          <Input
            id={`${setting.key}-int`}
            name="value_integer"
            type="number"
            min={0}
            defaultValue={setting.valueInteger}
            required
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${setting.key}-text`}>Text value</Label>
          <Input
            id={`${setting.key}-text`}
            name="value_text"
            defaultValue={setting.valueText ?? ""}
          />
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${setting.key}-desc`}>Description</Label>
        <Input
          id={`${setting.key}-desc`}
          name="description"
          defaultValue={setting.description ?? ""}
        />
      </div>

      <div className="flex items-center gap-3">
        <Button type="submit" size="sm" disabled={pending}>
          {pending ? "Saving…" : "Save"}
        </Button>
        {state?.error ? (
          <p className="text-sm text-destructive">{state.error}</p>
        ) : null}
        {state?.success ? (
          <p className="text-sm text-muted-foreground">{state.success}</p>
        ) : null}
      </div>
    </form>
  );
}
