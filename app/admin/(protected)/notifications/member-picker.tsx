"use client";

import { useMemo, useState } from "react";

import { adminControlClassName } from "@/components/admin/admin-ui";

export type NotificationMember = {
  id: string;
  name: string;
  email: string;
};

export function MemberPicker({
  members,
  selectedIds,
  onChange,
}: {
  members: NotificationMember[];
  selectedIds: string[];
  onChange: (ids: string[]) => void;
}) {
  const [query, setQuery] = useState("");
  const selected = useMemo(() => new Set(selectedIds), [selectedIds]);

  const visible = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) {
      return members;
    }
    return members.filter((member) => {
      return (
        member.name.toLowerCase().includes(term) ||
        member.email.toLowerCase().includes(term)
      );
    });
  }, [members, query]);

  function toggle(id: string) {
    if (selected.has(id)) {
      onChange(selectedIds.filter((current) => current !== id));
      return;
    }
    onChange([...selectedIds, id]);
  }

  return (
    <div className="flex flex-col gap-3 rounded-lg border border-zinc-200 bg-zinc-50/70 p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm text-zinc-700">
          <span className="font-semibold text-zinc-900">{selectedIds.length}</span> selected
        </p>
        <div className="flex gap-2">
          <button
            type="button"
            className="text-xs font-medium text-zinc-700 underline-offset-2 hover:underline"
            onClick={() => {
              const merged = new Set(selectedIds);
              for (const member of visible) {
                merged.add(member.id);
              }
              onChange([...merged]);
            }}
          >
            Select shown
          </button>
          <button
            type="button"
            className="text-xs font-medium text-zinc-700 underline-offset-2 hover:underline"
            onClick={() => onChange([])}
          >
            Clear
          </button>
        </div>
      </div>

      <input
        type="search"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="Search name or email"
        className={adminControlClassName}
        aria-label="Search members"
      />

      <div className="max-h-64 overflow-y-auto rounded-md border border-zinc-200 bg-white">
        {visible.length === 0 ? (
          <p className="px-3 py-4 text-sm text-zinc-500">No members match that search.</p>
        ) : (
          <ul>
            {visible.map((member) => (
              <li key={member.id} className="border-b border-zinc-100 last:border-b-0">
                <label className="flex cursor-pointer items-start gap-3 px-3 py-2.5 hover:bg-zinc-50">
                  <input
                    type="checkbox"
                    name="profileId"
                    value={member.id}
                    checked={selected.has(member.id)}
                    onChange={() => toggle(member.id)}
                    className="mt-0.5 size-4 rounded border-zinc-300 text-zinc-900 focus:ring-zinc-400"
                  />
                  <span className="min-w-0">
                    <span className="block text-sm font-medium text-zinc-900">
                      {member.name || "Member"}
                    </span>
                    <span className="block truncate text-xs text-zinc-500">{member.email}</span>
                  </span>
                </label>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
