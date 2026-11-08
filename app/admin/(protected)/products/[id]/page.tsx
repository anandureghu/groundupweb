import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { AdminPageHeader, AdminStatusPill } from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import {
  ProductEditForm,
  type ProductCategoryOption,
  type ProductVariantEditValue,
} from "./product-edit-form";

export const metadata: Metadata = {
  title: "Edit product",
};

type ProductRow = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  category_id: string;
  price_cents: number | null;
  image_url: string | null;
  badge: string | null;
  is_active: boolean | null;
  is_featured: boolean | null;
  is_seasonal: boolean | null;
  points_earned: number | null;
  points_earned_override: number | null;
  is_redeemable: boolean | null;
  points_to_redeem: number | null;
  redeem_title: string | null;
  redeem_description: string | null;
};

type CategoryRow = {
  id: string;
  name: string;
};

type VariantRow = {
  id: string;
  name: string;
  price_cents: number;
  sort_order: number;
  is_active: boolean;
};

function formatGbp(cents: number): string {
  return (cents / 100).toLocaleString("en-GB", {
    style: "currency",
    currency: "GBP",
  });
}

function centsToGbpInput(cents: number): string {
  return (cents / 100).toFixed(2);
}

export default async function AdminProductDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  await requireAdmin();
  const supabase = await createServerSupabaseClient();

  const [productResult, categoriesResult, variantsResult] = await Promise.all([
    supabase
      .from("products")
      .select(
        "id, name, slug, description, category_id, price_cents, image_url, badge, is_active, is_featured, is_seasonal, points_earned, points_earned_override, is_redeemable, points_to_redeem, redeem_title, redeem_description",
      )
      .eq("id", id)
      .maybeSingle<ProductRow>(),
    supabase
      .from("categories")
      .select("id, name")
      .order("sort_order", { ascending: true })
      .order("name", { ascending: true }),
    supabase
      .from("product_variants")
      .select("id, name, price_cents, sort_order, is_active")
      .eq("product_id", id)
      .order("sort_order", { ascending: true })
      .order("name", { ascending: true }),
  ]);

  if (productResult.error) {
    console.error("fetch product failed", productResult.error);
  }
  if (categoriesResult.error) {
    console.error("fetch categories failed", categoriesResult.error);
  }
  if (variantsResult.error) {
    console.error("fetch variants failed", variantsResult.error);
  }

  const data = productResult.data;
  if (!data) {
    notFound();
  }

  const categories: ProductCategoryOption[] = (
    (categoriesResult.data as CategoryRow[] | null) ?? []
  ).map((row) => ({ id: row.id, name: row.name }));

  const variants: ProductVariantEditValue[] = (
    (variantsResult.data as VariantRow[] | null) ?? []
  ).map((row) => ({
    id: row.id,
    key: row.id,
    name: row.name,
    priceGbp: centsToGbpInput(row.price_cents),
    sortOrder: row.sort_order,
    isActive: row.is_active,
  }));

  const priceCents = data.price_cents ?? 0;

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        breadcrumb={{ href: "/admin/products", label: "Products" }}
        title={data.name}
        description={`${formatGbp(priceCents)} · ${data.slug}`}
        actions={
          <AdminStatusPill active={data.is_active ?? true} />
        }
      />

      <ProductEditForm
        categories={categories}
        product={{
          id: data.id,
          name: data.name,
          slug: data.slug,
          description: data.description ?? "",
          categoryId: data.category_id,
          priceGbp: centsToGbpInput(priceCents),
          imageUrl: data.image_url ?? "",
          badge: data.badge ?? "",
          isActive: data.is_active ?? true,
          isFeatured: data.is_featured ?? false,
          isSeasonal: data.is_seasonal ?? false,
          pointsEarned: data.points_earned ?? 0,
          pointsEarnedOverride:
            data.points_earned_override == null
              ? ""
              : String(data.points_earned_override),
          isRedeemable: data.is_redeemable ?? false,
          pointsToRedeem: data.points_to_redeem ?? 250,
          redeemTitle: data.redeem_title ?? "",
          redeemDescription: data.redeem_description ?? "",
          variants,
        }}
      />
    </div>
  );
}
