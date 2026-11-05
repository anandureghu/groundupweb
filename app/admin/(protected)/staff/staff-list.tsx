"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import { Input } from "@/components/ui/input";

export type AdminStaffRow = {
  id: string;
  firstName: string | null;
  lastName: string | null;
  email: string | null;
  staffRole: string | null;
  storeName: string | null;
  isActive: boolean;
};

export function StaffList({ staff }: { staff: AdminStaffRow[] }) {
  const [query, setQuery] = useState("");

  const filtered = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) {
      return staff;
    }

    return staff.filter((member) => {
      const name = `${member.firstName ?? ""} ${member.lastName ?? ""}`
        .trim()
        .toLowerCase();
      const email = (member.email ?? "").toLowerCase();
      return name.includes(term) || email.includes(term);
    });
  }, [staff, query]);

  return (
    <div className="flex flex-col gap-4">
      <Input
        type="search"
        placeholder="Search by name or email"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        className="max-w-sm"
        aria-label="Search staff"
      />

      <div className="overflow-x-auto border border-border">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-border bg-muted/40">
            <tr>
              <th className="px-4 py-3 font-semibold">Name</th>
              <th className="px-4 py-3 font-semibold">Email</th>
              <th className="px-4 py-3 font-semibold">Role</th>
              <th className="px-4 py-3 font-semibold">Store</th>
              <th className="px-4 py-3 font-semibold">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td
                  colSpan={5}
                  className="px-4 py-6 text-center text-muted-foreground"
                >
                  No staff found.
                </td>
              </tr>
            ) : (
              filtered.map((member) => {
                const name =
                  `${member.firstName ?? ""} ${member.lastName ?? ""}`.trim() ||
                  "—";

                return (
                  <tr
                    key={member.id}
                    className="border-b border-border last:border-b-0"
                  >
                    <td className="px-4 py-3">
                      <Link
                        href={`/admin/staff/${member.id}`}
                        className="font-medium text-primary hover:underline"
                      >
                        {name}
                      </Link>
                    </td>
                    <td className="px-4 py-3">{member.email ?? "—"}</td>
                    <td className="px-4 py-3 capitalize">
                      {member.staffRole ?? "—"}
                    </td>
                    <td className="px-4 py-3">{member.storeName ?? "—"}</td>
                    <td className="px-4 py-3">
                      {member.isActive ? "Active" : "Disabled"}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
