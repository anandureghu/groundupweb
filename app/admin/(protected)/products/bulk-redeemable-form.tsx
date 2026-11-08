"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import {
  AdminField,
  AdminSection,
  adminControlClassName,
} from "@/components/admin/admin-ui";

import {
  bulkSetProductsRedeemable,
  type ProductActionState,
} from "./actions";

const initialState: ProductActionState = null;

export function BulkRedeemableForm() {
  const [state, action, pending] = useActionState(
    bulkSetProductsRedeemable,
    initialState,
  );

  return (
    <AdminSection
      title="Bulk redeemable"
      description="Turn on points redemption for every product at once."
    >
      <form action={action} className="flex flex-col gap-3 sm:flex-row sm:items-end">
        <AdminField
          label="Points to redeem"
          htmlFor="points_to_redeem"
          className="sm:max-w-xs"
        >
          <input
            id="points_to_redeem"
            name="points_to_redeem"
            type="number"
            min={1}
            step={1}
            defaultValue={250}
            className={adminControlClassName}
          />
        </AdminField>
        <Button type="submit" disabled={pending} className="rounded-lg">
          {pending ? "Updating…" : "Apply to all products"}
        </Button>
      </form>
      {state?.error ? (
        <p role="alert" className="mt-3 text-sm text-red-600">
          {state.error}
        </p>
      ) : null}
      {state?.success ? (
        <p className="mt-3 text-sm text-emerald-700">{state.success}</p>
      ) : null}
    </AdminSection>
  );
}
