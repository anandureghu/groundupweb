import type { Metadata } from "next";

import { AdminPageHeader } from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { BulkRedeemableForm } from "./bulk-redeemable-form";
import { ProductList, type AdminProductRow } from "./product-list";

export const metadata: Metadata = {
  title: "Products",
};

type ProductRow = {
  id: string;
  name: string;
  slug: string;
  price_cents: number | null;
  is_active: boolean | null;
  is_redeemable: boolean | null;
  points_to_redeem: number | null;
  categories: { name: string | null } | { name: string | null }[] | null;
};

export default async function AdminProductsPage() {
  await requireAdmin();
  const supabase = await createServerSupabaseClient();

  const { data, error } = await supabase
    .from("products")
    .select(
      "id, name, slug, price_cents, is_active, is_redeemable, points_to_redeem, categories(name)",
    )
    .order("name", { ascending: true });

  if (error) {
    console.error("list products failed", error);
  }

  const products: AdminProductRow[] = ((data as ProductRow[] | null) ?? []).map(
    (row) => {
      const category = Array.isArray(row.categories)
        ? row.categories[0]
        : row.categories;
      return {
        id: row.id,
        name: row.name,
        slug: row.slug,
        categoryName: category?.name ?? "—",
        priceCents: row.price_cents ?? 0,
        isActive: row.is_active ?? true,
        isRedeemable: row.is_redeemable ?? false,
        pointsToRedeem: row.points_to_redeem ?? 0,
      };
    },
  );

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Products"
        description="Edit menu items, pricing, visibility, and points redemption."
      />

      <BulkRedeemableForm />

      <ProductList products={products} />
    </div>
  );
}
