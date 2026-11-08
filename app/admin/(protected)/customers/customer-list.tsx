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

export type AdminCustomerRow = {
  id: string;
  firstName: string | null;
  lastName: string | null;
  email: string | null;
  pointsBalance: number;
  isActive: boolean;
  createdAt: string;
};

export function CustomerList({
  customers,
}: {
  customers: AdminCustomerRow[];
}) {
  const [query, setQuery] = useState("");

  const filtered = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) {
      return customers;
    }

    return customers.filter((customer) => {
      const name = `${customer.firstName ?? ""} ${customer.lastName ?? ""}`
        .trim()
        .toLowerCase();
      const email = (customer.email ?? "").toLowerCase();
      return name.includes(term) || email.includes(term);
    });
  }, [customers, query]);

  return (
    <div className="flex flex-col gap-4">
      <input
        type="search"
        placeholder="Search by name or email"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        className={`${adminControlClassName} max-w-sm`}
        aria-label="Search customers"
      />

      <AdminTable>
        <AdminTableHead>
          <tr>
            <AdminTh>Name</AdminTh>
            <AdminTh>Email</AdminTh>
            <AdminTh>Points</AdminTh>
            <AdminTh>Status</AdminTh>
            <AdminTh>Joined</AdminTh>
          </tr>
        </AdminTableHead>
        <tbody>
          {filtered.length === 0 ? (
            <tr>
              <td
                colSpan={5}
                className="px-4 py-8 text-center text-sm text-zinc-500"
              >
                No customers found.
              </td>
            </tr>
          ) : (
            filtered.map((customer) => {
              const name =
                `${customer.firstName ?? ""} ${customer.lastName ?? ""}`.trim() ||
                "—";

              return (
                <tr
                  key={customer.id}
                  className="border-b border-zinc-100 last:border-b-0 hover:bg-zinc-50/80"
                >
                  <AdminTd>
                    <Link
                      href={`/admin/customers/${customer.id}`}
                      className="font-medium text-zinc-900 underline-offset-2 hover:underline"
                    >
                      {name}
                    </Link>
                  </AdminTd>
                  <AdminTd>{customer.email ?? "—"}</AdminTd>
                  <AdminTd>{customer.pointsBalance}</AdminTd>
                  <AdminTd>
                    <AdminStatusPill
                      active={customer.isActive}
                      inactiveLabel="Disabled"
                    />
                  </AdminTd>
                  <AdminTd>
                    {new Date(customer.createdAt).toLocaleDateString()}
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
