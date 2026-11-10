"use client";

import { useActionState, useMemo, useState } from "react";

import { adminControlClassName } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { formatPoints } from "@/lib/admin/rewards";

import { adjustMemberPoints, type RewardsActionState } from "./actions";

export type RewardsMember = {
  id: string;
  name: string;
  email: string;
  pointsBalance: number;
};

export function AdjustPointsForm({
  members,
  preselectedId,
}: {
  members: RewardsMember[];
  preselectedId?: string;
}) {
  const [state, action, pending] = useActionState<RewardsActionState, FormData>(
    adjustMemberPoints,
    null,
  );
  const [query, setQuery] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(preselectedId ?? null);
  const [handledState, setHandledState] = useState(state);

  if (state !== handledState) {
    setHandledState(state);
    if (state?.success) {
      setQuery("");
      setSelectedId(null);
    }
  }

  const selected = members.find((member) => member.id === selectedId) ?? null;

  const visible = useMemo(() => {
    const term = query.trim().toLowerCase();
    const matches = term
      ? members.filter(
          (member) =>
            member.name.toLowerCase().includes(term) ||
            member.email.toLowerCase().includes(term),
        )
      : members;
    return matches.slice(0, 20);
  }, [members, query]);

  return (
    <form action={action} className="flex flex-col gap-4">
      <input type="hidden" name="profileId" value={selectedId ?? ""} readOnly />

      {selected ? (
        <div className="flex items-center justify-between gap-3 rounded-lg border border-zinc-200 bg-zinc-50/70 px-3 py-2.5">
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-zinc-900">
              {selected.name || "Member"}
            </p>
            <p className="truncate text-xs text-zinc-500">{selected.email}</p>
          </div>
          <div className="flex shrink-0 items-center gap-3">
            <p className="text-sm text-zinc-700">
              {formatPoints(selected.pointsBalance)} pts
            </p>
            <button
              type="button"
              className="text-xs font-medium text-zinc-600 underline-offset-2 hover:underline"
              onClick={() => setSelectedId(null)}
            >
              Change
            </button>
          </div>
        </div>
      ) : (
        <div className="flex flex-col gap-2">
          <input
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search name or email"
            className={adminControlClassName}
            aria-label="Search members"
          />
          <div className="max-h-56 overflow-y-auto rounded-md border border-zinc-200 bg-white">
            {visible.length === 0 ? (
              <p className="px-3 py-4 text-sm text-zinc-500">No members match that search.</p>
            ) : (
              <ul>
                {visible.map((member) => (
                  <li key={member.id} className="border-b border-zinc-100 last:border-b-0">
                    <button
                      type="button"
                      onClick={() => setSelectedId(member.id)}
                      className="flex w-full items-center justify-between gap-3 px-3 py-2.5 text-left hover:bg-zinc-50"
                    >
                      <span className="min-w-0">
                        <span className="block truncate text-sm font-medium text-zinc-900">
                          {member.name || "Member"}
                        </span>
                        <span className="block truncate text-xs text-zinc-500">
                          {member.email}
                        </span>
                      </span>
                      <span className="shrink-0 text-xs text-zinc-500">
                        {formatPoints(member.pointsBalance)} pts
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-[160px_1fr]">
        <div className="flex flex-col gap-1.5">
          <label htmlFor="delta" className="text-sm font-medium text-zinc-700">
            Points
          </label>
          <input
            id="delta"
            name="delta"
            type="number"
            step="1"
            placeholder="e.g. 100 or -50"
            className={adminControlClassName}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <label htmlFor="reason" className="text-sm font-medium text-zinc-700">
            Reason
          </label>
          <input
            id="reason"
            name="reason"
            type="text"
            placeholder="Why are you adjusting this balance?"
            className={adminControlClassName}
          />
        </div>
      </div>

      {state?.error ? <p className="text-sm text-red-600">{state.error}</p> : null}
      {state?.success ? <p className="text-sm text-emerald-600">{state.success}</p> : null}

      <div>
        <Button type="submit" disabled={pending || !selectedId} className="rounded-lg">
          {pending ? "Saving…" : "Save adjustment"}
        </Button>
      </div>
    </form>
  );
}
