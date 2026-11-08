"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import {
  AdminStatusPill,
  AdminTable,
  AdminTableHead,
  AdminTd,
  AdminTh,
  adminControlClassName,
} from "@/components/admin/admin-ui";

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
      <input
        type="search"
        placeholder="Search by name or email"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        className={`${adminControlClassName} max-w-sm`}
        aria-label="Search staff"
      />

      <AdminTable>
        <AdminTableHead>
          <tr>
            <AdminTh>Name</AdminTh>
            <AdminTh>Email</AdminTh>
            <AdminTh>Role</AdminTh>
            <AdminTh>Store</AdminTh>
            <AdminTh>Status</AdminTh>
          </tr>
        </AdminTableHead>
        <tbody>
          {filtered.length === 0 ? (
            <tr>
              <td
                colSpan={5}
                className="px-4 py-8 text-center text-sm text-zinc-500"
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
                  className="border-b border-zinc-100 last:border-b-0 hover:bg-zinc-50/80"
                >
                  <AdminTd>
                    <Link
                      href={`/admin/staff/${member.id}`}
                      className="font-medium text-zinc-900 underline-offset-2 hover:underline"
                    >
                      {name}
                    </Link>
                  </AdminTd>
                  <AdminTd>{member.email ?? "—"}</AdminTd>
                  <AdminTd className="capitalize">
                    {member.staffRole ?? "—"}
                  </AdminTd>
                  <AdminTd>{member.storeName ?? "—"}</AdminTd>
                  <AdminTd>
                    <AdminStatusPill
                      active={member.isActive}
                      inactiveLabel="Disabled"
                    />
                  </AdminTd>
                </tr>
              );
            })
          )}
        </tbody>
      </AdminTable>
    </div>
  );
}
