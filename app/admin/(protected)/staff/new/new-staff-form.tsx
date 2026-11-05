"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

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
      <div className="flex flex-col gap-4 border border-border p-6">
        <div>
          <h2 className="text-lg font-semibold">Staff member created</h2>
          <p className="text-sm text-muted-foreground">
            Share this temporary password with {created.email}. It will not
            be shown again.
          </p>
        </div>

        <div className="flex flex-col gap-2">
          <Label>Email</Label>
          <p className="text-sm">{created.email}</p>
        </div>

        <div className="flex flex-col gap-2">
          <Label>Temporary password</Label>
          <div className="flex items-center gap-2">
            <code className="border border-border bg-muted/40 px-3 py-2 text-sm">
              {created.temporaryPassword}
            </code>
            <Button type="button" variant="outline" size="sm" onClick={handleCopy}>
              {copied ? "Copied" : "Copy"}
            </Button>
          </div>
        </div>

        <div className="flex gap-3">
          <Button type="button" onClick={() => router.push("/admin/staff")}>
            Back to staff
          </Button>
          <Button
            type="button"
            variant="outline"
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
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="flex max-w-md flex-col gap-4 border border-border p-6"
    >
      <div className="flex flex-col gap-2">
        <Label htmlFor="name">Name</Label>
        <Input
          id="name"
          name="name"
          value={name}
          onChange={(event) => setName(event.target.value)}
          required
        />
      </div>

      <div className="flex flex-col gap-2">
        <Label htmlFor="email">Email</Label>
        <Input
          id="email"
          name="email"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          required
        />
      </div>

      <div className="flex flex-col gap-2">
        <Label htmlFor="role">Role</Label>
        <select
          id="role"
          name="role"
          value={role}
          onChange={(event) => setRole(event.target.value as "staff" | "admin")}
          className="h-10 w-full border border-border bg-transparent px-2 text-sm outline-none focus-visible:border-ring"
        >
          <option value="staff">Staff</option>
          <option value="admin">Admin</option>
        </select>
      </div>

      <div className="flex flex-col gap-2">
        <Label htmlFor="storeId">Store</Label>
        <select
          id="storeId"
          name="storeId"
          value={storeId}
          onChange={(event) => setStoreId(event.target.value)}
          required
          className="h-10 w-full border border-border bg-transparent px-2 text-sm outline-none focus-visible:border-ring"
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
      </div>

      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}

      <Button type="submit" disabled={pending || stores.length === 0}>
        {pending ? "Creating…" : "Create staff member"}
      </Button>
    </form>
  );
}
