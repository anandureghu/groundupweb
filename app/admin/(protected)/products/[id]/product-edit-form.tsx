"use client";

import { useActionState, useState } from "react";

import { Button } from "@/components/ui/button";
import {
  AdminCheckbox,
  AdminField,
  AdminSection,
  adminControlClassName,
  adminSelectClassName,
  adminTextareaClassName,
} from "@/components/admin/admin-ui";
import { cn } from "@/lib/utils";

import { updateProduct, type ProductActionState } from "../actions";

export type ProductCategoryOption = {
  id: string;
  name: string;
};

export type ProductVariantEditValue = {
  id: string | null;
  key: string;
  name: string;
  priceGbp: string;
  sortOrder: number;
  isActive: boolean;
};

export type ProductEditValues = {
  id: string;
  name: string;
  slug: string;
  description: string;
  categoryId: string;
  priceGbp: string;
  imageUrl: string;
  badge: string;
  isActive: boolean;
  isFeatured: boolean;
  isSeasonal: boolean;
  pointsEarned: number;
  pointsEarnedOverride: string;
  isRedeemable: boolean;
  pointsToRedeem: number;
  redeemTitle: string;
  redeemDescription: string;
  variants: ProductVariantEditValue[];
};

const initialState: ProductActionState = null;

export function ProductEditForm({
  product,
  categories,
}: {
  product: ProductEditValues;
  categories: ProductCategoryOption[];
}) {
  const [state, action, pending] = useActionState(updateProduct, initialState);
  const [variants, setVariants] = useState(product.variants);

  function addVariant() {
    setVariants((current) => [
      ...current,
      {
        id: null,
        key: `new-${crypto.randomUUID()}`,
        name: "",
        priceGbp: product.priceGbp,
        sortOrder: current.length,
        isActive: true,
      },
    ]);
  }

  function updateVariant(
    key: string,
    patch: Partial<Omit<ProductVariantEditValue, "key">>,
  ) {
    setVariants((current) =>
      current.map((variant) =>
        variant.key === key ? { ...variant, ...patch } : variant,
      ),
    );
  }

  function removeVariant(key: string) {
    setVariants((current) => current.filter((variant) => variant.key !== key));
  }

  return (
    <form action={action} className="flex flex-col gap-5">
      <input type="hidden" name="id" value={product.id} />

      <AdminSection
        title="Basics"
        description="How this product appears in the menu."
      >
        <div className="grid gap-4 md:grid-cols-2">
          <AdminField label="Name" htmlFor="name">
            <input
              id="name"
              name="name"
              defaultValue={product.name}
              required
              className={adminControlClassName}
            />
          </AdminField>
          <AdminField
            label="Slug"
            htmlFor="slug"
            hint="URL-safe identifier used by the app."
          >
            <input
              id="slug"
              name="slug"
              defaultValue={product.slug}
              required
              className={adminControlClassName}
            />
          </AdminField>
          <AdminField label="Category" htmlFor="category_id">
            <select
              id="category_id"
              name="category_id"
              defaultValue={product.categoryId}
              required
              className={adminSelectClassName}
            >
              {categories.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.name}
                </option>
              ))}
            </select>
          </AdminField>
          <AdminField
            label="Badge"
            htmlFor="badge"
            hint="Optional short label on the product card."
          >
            <input
              id="badge"
              name="badge"
              defaultValue={product.badge}
              placeholder="e.g. New, Seasonal"
              className={adminControlClassName}
            />
          </AdminField>
          <AdminField
            label="Description"
            htmlFor="description"
            className="md:col-span-2"
          >
            <textarea
              id="description"
              name="description"
              defaultValue={product.description}
              className={adminTextareaClassName}
            />
          </AdminField>
          <AdminField
            label="Image URL"
            htmlFor="image_url"
            hint="Direct image link shown in the app."
            className="md:col-span-2"
          >
            <input
              id="image_url"
              name="image_url"
              defaultValue={product.imageUrl}
              placeholder="https://"
              className={adminControlClassName}
            />
          </AdminField>
        </div>
      </AdminSection>

      <AdminSection
        title="Pricing"
        description="Base price used when a product has no sizes, or as the fallback."
      >
        <div className="grid gap-4 md:grid-cols-2">
          <AdminField label="Base price (GBP)" htmlFor="price_gbp">
            <input
              id="price_gbp"
              name="price_gbp"
              type="number"
              min={0}
              step="0.01"
              defaultValue={product.priceGbp}
              required
              className={adminControlClassName}
            />
          </AdminField>
        </div>
      </AdminSection>

      <AdminSection
        title="Visibility"
        description="Controls whether the product shows in the app and how it is highlighted."
      >
        <div className="grid gap-3 md:grid-cols-3">
          <AdminCheckbox
            name="is_active"
            defaultChecked={product.isActive}
            label="Active"
            hint="Inactive products are hidden from customers."
          />
          <AdminCheckbox
            name="is_featured"
            defaultChecked={product.isFeatured}
            label="Featured"
            hint="Show in featured / highlighted areas."
          />
          <AdminCheckbox
            name="is_seasonal"
            defaultChecked={product.isSeasonal}
            label="Seasonal"
            hint="Mark as a seasonal menu item."
          />
        </div>
      </AdminSection>

      <AdminSection
        title="Earn points"
        description="How many points a customer earns when this product is purchased."
      >
        <div className="grid gap-4 md:grid-cols-2">
          <AdminField
            label="Points earned override"
            htmlFor="points_earned_override"
            hint="Leave blank to use the default £1 = points rate. Set a number to award a fixed amount per unit."
          >
            <input
              id="points_earned_override"
              name="points_earned_override"
              type="number"
              min={0}
              step={1}
              defaultValue={product.pointsEarnedOverride}
              placeholder="Auto from price"
              className={adminControlClassName}
            />
          </AdminField>
          <AdminField
            label="Legacy points earned"
            htmlFor="points_earned"
            hint="Older flat field kept for compatibility. Prefer the override above."
          >
            <input
              id="points_earned"
              name="points_earned"
              type="number"
              min={0}
              step={1}
              defaultValue={product.pointsEarned}
              className={adminControlClassName}
            />
          </AdminField>
        </div>
      </AdminSection>

      <AdminSection
        title="Redeem with points"
        description="Lets staff claim this product against a customer’s points balance."
      >
        <div className="grid gap-4">
          <AdminCheckbox
            name="is_redeemable"
            defaultChecked={product.isRedeemable}
            label="Redeemable with points"
            hint="When enabled, this product appears in the claim / redeem flow."
          />
          <div className="grid gap-4 md:grid-cols-2">
            <AdminField label="Points to redeem" htmlFor="points_to_redeem">
              <input
                id="points_to_redeem"
                name="points_to_redeem"
                type="number"
                min={0}
                step={1}
                defaultValue={product.pointsToRedeem}
                className={adminControlClassName}
              />
            </AdminField>
            <AdminField label="Redeem title" htmlFor="redeem_title">
              <input
                id="redeem_title"
                name="redeem_title"
                defaultValue={product.redeemTitle}
                placeholder="Optional override title"
                className={adminControlClassName}
              />
            </AdminField>
            <AdminField
              label="Redeem description"
              htmlFor="redeem_description"
              className="md:col-span-2"
            >
              <textarea
                id="redeem_description"
                name="redeem_description"
                defaultValue={product.redeemDescription}
                className={cn(adminTextareaClassName, "min-h-20")}
              />
            </AdminField>
          </div>
        </div>
      </AdminSection>

      <AdminSection
        title="Sizes / variants"
        description="Optional size options with their own prices. Leave empty if the product has a single price."
      >
        <div className="flex flex-col gap-3">
          {variants.length === 0 ? (
            <p className="text-sm text-zinc-500">
              No sizes yet. Add one if this product has Small / Large style options.
            </p>
          ) : (
            <div className="overflow-x-auto rounded-lg border border-zinc-200">
              <table className="w-full min-w-[640px] text-left text-sm">
                <thead className="border-b border-zinc-200 bg-zinc-50 text-xs font-semibold uppercase tracking-wide text-zinc-500">
                  <tr>
                    <th className="px-3 py-2">Name</th>
                    <th className="px-3 py-2">Price (GBP)</th>
                    <th className="px-3 py-2">Sort</th>
                    <th className="px-3 py-2">Active</th>
                    <th className="px-3 py-2" />
                  </tr>
                </thead>
                <tbody>
                  {variants.map((variant) => {
                    const activeValue = variant.id ?? variant.key;
                    return (
                      <tr
                        key={variant.key}
                        className="border-b border-zinc-100 last:border-b-0"
                      >
                        <td className="px-3 py-2">
                          <input type="hidden" name="variant_id" value={variant.id ?? ""} />
                          <input
                            name="variant_name"
                            value={variant.name}
                            onChange={(event) =>
                              updateVariant(variant.key, {
                                name: event.target.value,
                              })
                            }
                            placeholder="e.g. Regular"
                            className={adminControlClassName}
                          />
                        </td>
                        <td className="px-3 py-2">
                          <input
                            name="variant_price_gbp"
                            type="number"
                            min={0}
                            step="0.01"
                            value={variant.priceGbp}
                            onChange={(event) =>
                              updateVariant(variant.key, {
                                priceGbp: event.target.value,
                              })
                            }
                            className={adminControlClassName}
                          />
                        </td>
                        <td className="w-24 px-3 py-2">
                          <input
                            name="variant_sort_order"
                            type="number"
                            min={0}
                            step={1}
                            value={variant.sortOrder}
                            onChange={(event) =>
                              updateVariant(variant.key, {
                                sortOrder: Number(event.target.value) || 0,
                              })
                            }
                            className={adminControlClassName}
                          />
                        </td>
                        <td className="px-3 py-2">
                          <label className="inline-flex items-center gap-2 text-sm text-zinc-700">
                            <input
                              type="checkbox"
                              name="variant_active"
                              value={activeValue}
                              checked={variant.isActive}
                              onChange={(event) =>
                                updateVariant(variant.key, {
                                  isActive: event.target.checked,
                                })
                              }
                              className="size-4 rounded border-zinc-300"
                            />
                            On
                          </label>
                        </td>
                        <td className="px-3 py-2 text-right">
                          {!variant.id ? (
                            <button
                              type="button"
                              onClick={() => removeVariant(variant.key)}
                              className="text-sm font-medium text-zinc-500 underline-offset-2 hover:text-zinc-900 hover:underline"
                            >
                              Remove
                            </button>
                          ) : (
                            <span className="text-xs text-zinc-400">Saved</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}

          <div>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={addVariant}
              className="rounded-lg border-zinc-300"
            >
              Add size
            </Button>
          </div>
        </div>
      </AdminSection>

      <div className="sticky bottom-4 z-10 flex flex-wrap items-center gap-3 rounded-xl border border-zinc-200 bg-white/95 px-4 py-3 shadow-lg backdrop-blur">
        <Button type="submit" disabled={pending} className="rounded-lg">
          {pending ? "Saving…" : "Save product"}
        </Button>
        {state?.error ? (
          <p role="alert" className="text-sm text-red-600">
            {state.error}
          </p>
        ) : null}
        {state?.success ? (
          <p className="text-sm text-emerald-700">{state.success}</p>
        ) : null}
      </div>
    </form>
  );
}
