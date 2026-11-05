"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import { Input } from "@/components/ui/input";

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
      <Input
        type="search"
        placeholder="Search by name or email"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        className="max-w-sm"
        aria-label="Search customers"
      />

      <div className="overflow-x-auto border border-border">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-border bg-muted/40">
            <tr>
              <th className="px-4 py-3 font-semibold">Name</th>
              <th className="px-4 py-3 font-semibold">Email</th>
              <th className="px-4 py-3 font-semibold">Points balance</th>
              <th className="px-4 py-3 font-semibold">Status</th>
              <th className="px-4 py-3 font-semibold">Joined</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td
                  colSpan={5}
                  className="px-4 py-6 text-center text-muted-foreground"
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
                    className="border-b border-border last:border-b-0"
                  >
                    <td className="px-4 py-3">
                      <Link
                        href={`/admin/customers/${customer.id}`}
                        className="font-medium text-primary hover:underline"
                      >
                        {name}
                      </Link>
                    </td>
                    <td className="px-4 py-3">{customer.email ?? "—"}</td>
                    <td className="px-4 py-3">{customer.pointsBalance}</td>
                    <td className="px-4 py-3">
                      {customer.isActive ? "Active" : "Disabled"}
                    </td>
                    <td className="px-4 py-3">
                      {new Date(customer.createdAt).toLocaleDateString()}
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
