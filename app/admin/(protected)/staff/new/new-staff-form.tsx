"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import {
  AdminField,
  AdminSection,
  adminControlClassName,
  adminSelectClassName,
} from "@/components/admin/admin-ui";

import { createStaff } from "../actions";

type StoreOption = { id: string; name: string };

export function NewStaffForm({ stores }: { stores: StoreOption[] }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [created, setCreated] = useState<{
    email: string;
    temporaryPassword: string;
  } | null>(null);
  const [copied, setCopied] = useState(false);

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<"staff" | "admin">("staff");
  const [storeId, setStoreId] = useState(stores[0]?.id ?? "");

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    startTransition(async () => {
      const result = await createStaff({ name, email, role, storeId });

      if ("error" in result) {
        setError(result.error);
        return;
      }

      setCreated(result);
      router.refresh();
    });
  }

  async function handleCopy() {
    if (!created) {
      return;
    }

    try {
      await navigator.clipboard.writeText(created.temporaryPassword);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }

  if (created) {
    return (
      <AdminSection
        title="Staff member created"
        description={`Share this temporary password with ${created.email}. It will not be shown again.`}
      >
        <div className="flex flex-col gap-4">
          <div>
            <p className="text-sm text-zinc-500">Email</p>
            <p className="font-medium text-zinc-900">{created.email}</p>
          </div>

          <div>
            <p className="mb-2 text-sm text-zinc-500">Temporary password</p>
            <div className="flex flex-wrap items-center gap-2">
              <code className="rounded-md border border-zinc-200 bg-zinc-50 px-3 py-2 text-sm">
                {created.temporaryPassword}
              </code>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={handleCopy}
                className="rounded-lg border-zinc-300"
              >
                {copied ? "Copied" : "Copy"}
              </Button>
            </div>
          </div>

          <div className="flex flex-wrap gap-3">
            <Button
              type="button"
              onClick={() => router.push("/admin/staff")}
              className="rounded-lg"
            >
              Back to staff
            </Button>
            <Button
              type="button"
              variant="outline"
              className="rounded-lg border-zinc-300"
              onClick={() => {
                setCreated(null);
                setCopied(false);
                setName("");
                setEmail("");
                setRole("staff");
                setStoreId(stores[0]?.id ?? "");
              }}
            >
              Create another
            </Button>
          </div>
        </div>
      </AdminSection>
    );
  }

  return (
    <AdminSection
      title="Account details"
      description="They’ll sign in with email and the temporary password you share."
    >
      <form onSubmit={handleSubmit} className="flex max-w-xl flex-col gap-4">
        <AdminField label="Name" htmlFor="name">
          <input
            id="name"
            name="name"
            value={name}
            onChange={(event) => setName(event.target.value)}
            required
            className={adminControlClassName}
          />
        </AdminField>

        <AdminField label="Email" htmlFor="email">
          <input
            id="email"
            name="email"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
            className={adminControlClassName}
          />
        </AdminField>

        <div className="grid gap-4 sm:grid-cols-2">
          <AdminField label="Role" htmlFor="role">
            <select
              id="role"
              name="role"
              value={role}
              onChange={(event) =>
                setRole(event.target.value as "staff" | "admin")
              }
              className={adminSelectClassName}
            >
              <option value="staff">Staff</option>
              <option value="admin">Admin</option>
            </select>
          </AdminField>

          <AdminField label="Store" htmlFor="storeId">
            <select
              id="storeId"
              name="storeId"
              value={storeId}
              onChange={(event) => setStoreId(event.target.value)}
              required
              className={adminSelectClassName}
            >
              {stores.length === 0 ? (
                <option value="">No active stores</option>
              ) : (
                stores.map((store) => (
                  <option key={store.id} value={store.id}>
                    {store.name}
                  </option>
                ))
              )}
            </select>
          </AdminField>
        </div>

        {error ? (
          <p role="alert" className="text-sm text-red-600">
            {error}
          </p>
        ) : null}

        <Button
          type="submit"
          disabled={pending || stores.length === 0}
          className="w-fit rounded-lg"
        >
          {pending ? "Creating…" : "Create staff member"}
        </Button>
      </form>
    </AdminSection>
  );
}
